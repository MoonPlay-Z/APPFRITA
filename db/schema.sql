-- Plataforma multiempresa de comida rápida - Esquema PostgreSQL 15+
-- Extensiones: PostGIS (geolocalización), pgcrypto (UUID), citext
-- Fuente de verdad del esquema. Cambios solo vía /db/migrations.
-- Requiere: PostgreSQL 15+ (usa UNIQUE NULLS NOT DISTINCT), PostGIS 3+.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------- MONEDAS Y TASA DE CAMBIO ----------
-- Todos los precios se almacenan ANCLADOS A USD.
-- La tarifa USD→VES se aplica en runtime para mostrar/cobrar en bolívares.
CREATE TABLE exchange_rates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_ccy    CHAR(3) NOT NULL DEFAULT 'USD',
  quote_ccy   CHAR(3) NOT NULL DEFAULT 'VES',   -- bolívar
  rate        NUMERIC(14,6) NOT NULL CHECK (rate > 0),  -- 1 USD = rate VES
  source      TEXT NOT NULL DEFAULT 'manual',   -- manual, bcv, paralelo
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (base_ccy, quote_ccy, valid_from)
);
CREATE INDEX idx_rates_latest ON exchange_rates (base_ccy, quote_ccy, valid_from DESC);

-- "Tasa vigente" más reciente:
-- SELECT rate FROM exchange_rates WHERE base_ccy='USD' AND quote_ccy='VES'
-- ORDER BY valid_from DESC LIMIT 1;

-- ---------- ENUMS ----------
CREATE TYPE user_role          AS ENUM ('customer','business_owner','business_staff','admin');
CREATE TYPE member_role        AS ENUM ('owner','manager','cashier','courier');
CREATE TYPE order_type         AS ENUM ('delivery','pickup','dine_in');
CREATE TYPE fulfillment_status AS ENUM ('pending','confirmed','preparing','ready','sent','delivered','cancelled');
CREATE TYPE payment_status     AS ENUM ('unpaid','proof_uploaded','paid','rejected','refunded');
CREATE TYPE payment_method     AS ENUM ('cash','transfer','mobile_payment','card_pos','other');
CREATE TYPE reservation_status AS ENUM ('requested','confirmed','rejected','cancelled','completed','no_show');
CREATE TYPE waiting_status     AS ENUM ('waiting','called','seated','expired','cancelled');
CREATE TYPE sub_status         AS ENUM ('trialing','active','past_due','cancelled');
CREATE TYPE msg_direction      AS ENUM ('inbound','outbound');
CREATE TYPE report_status      AS ENUM ('open','reviewed','dismissed','actioned');

-- ---------- HELPERS ----------
-- Mantiene updated_at al día sin depender de la app
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recalcula rating_avg/rating_count del negocio a partir de reviews
CREATE OR REPLACE FUNCTION refresh_business_rating() RETURNS trigger AS $$
DECLARE
  target UUID := COALESCE(NEW.business_id, OLD.business_id);
BEGIN
  UPDATE businesses b SET
    rating_avg   = COALESCE(s.avg_rating, 0),
    rating_count = COALESCE(s.cnt, 0)
  FROM (
    SELECT ROUND(AVG(rating)::numeric, 2) AS avg_rating, COUNT(*) AS cnt
    FROM reviews WHERE business_id = target
  ) s
  WHERE b.id = target;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Marca cuándo cambió is_open_now (para "trabajando desde hace X")
CREATE OR REPLACE FUNCTION touch_open_status() RETURNS trigger AS $$
BEGIN
  IF NEW.is_open_now IS DISTINCT FROM OLD.is_open_now THEN
    NEW.open_updated_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------- USUARIOS Y AUTH ----------
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT UNIQUE,
  phone         TEXT UNIQUE,
  password_hash TEXT,                        -- null si usa OAuth o Supabase Auth
  full_name     TEXT NOT NULL,
  avatar_id     UUID,                        -- FK a media_assets (se agrega abajo)
  role          user_role NOT NULL DEFAULT 'customer',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  email_verified_at TIMESTAMPTZ,
  phone_verified_at TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email IS NOT NULL OR phone IS NOT NULL)
);
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE oauth_identities (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider    TEXT NOT NULL,                 -- google, apple
  provider_uid TEXT NOT NULL,
  UNIQUE (provider, provider_uid)
);
CREATE INDEX idx_oauth_user ON oauth_identities (user_id);

CREATE TABLE refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_user ON refresh_tokens (user_id) WHERE revoked_at IS NULL;

CREATE TABLE device_tokens (               -- push (FCM)
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token     TEXT NOT NULL UNIQUE,
  platform  TEXT NOT NULL,                   -- android, ios
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE customer_addresses (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label     TEXT,                            -- Casa, Trabajo
  address   TEXT NOT NULL,
  reference TEXT,
  geo       GEOGRAPHY(Point,4326),
  is_default BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_addresses_user ON customer_addresses (user_id);
CREATE UNIQUE INDEX idx_addresses_one_default ON customer_addresses (user_id) WHERE is_default;

-- ---------- MEDIOS (imágenes) ----------
CREATE TABLE media_assets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  business_id UUID,                          -- FK abajo
  storage_key TEXT NOT NULL,                 -- ruta en S3/R2/Cloudinary
  url         TEXT NOT NULL,
  thumb_url   TEXT,
  mime_type   TEXT NOT NULL,
  size_bytes  INT NOT NULL CHECK (size_bytes > 0),
  width       INT CHECK (width IS NULL OR width > 0),
  height      INT CHECK (height IS NULL OR height > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE users ADD CONSTRAINT fk_users_avatar FOREIGN KEY (avatar_id) REFERENCES media_assets(id) ON DELETE SET NULL;

-- ---------- EMPRESAS (multi-tenant) ----------
CREATE TABLE businesses (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID NOT NULL REFERENCES users(id),
  name          TEXT NOT NULL,
  slug          CITEXT NOT NULL UNIQUE,
  description   TEXT,
  logo_id       UUID REFERENCES media_assets(id) ON DELETE SET NULL,
  cover_id      UUID REFERENCES media_assets(id) ON DELETE SET NULL,
  category      TEXT,                        -- hamburguesas, pizza, arepas...
  phone         TEXT,
  whatsapp_number TEXT,
  currency      CHAR(3) NOT NULL DEFAULT 'USD',  -- siempre USD; VES se deriva con exchange_rates
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  rating_avg    NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating_avg BETWEEN 0 AND 5),
  rating_count  INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE media_assets ADD CONSTRAINT fk_media_business FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
CREATE INDEX idx_businesses_owner ON businesses (owner_id);
CREATE TRIGGER trg_businesses_updated_at BEFORE UPDATE ON businesses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE business_members (
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        member_role NOT NULL,
  PRIMARY KEY (business_id, user_id)
);
CREATE INDEX idx_members_user ON business_members (user_id);

-- Sucursales / puestos (lo que el cliente ve en el mapa)
CREATE TABLE locations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  address      TEXT NOT NULL,
  geo          GEOGRAPHY(Point,4326) NOT NULL,
  is_mobile_stall BOOLEAN NOT NULL DEFAULT FALSE,   -- puesto móvil
  is_open_now  BOOLEAN NOT NULL DEFAULT FALSE,      -- "trabajando" (toggle manual)
  open_updated_at TIMESTAMPTZ,
  accepts_delivery BOOLEAN NOT NULL DEFAULT TRUE,
  accepts_pickup   BOOLEAN NOT NULL DEFAULT TRUE,
  accepts_reservations BOOLEAN NOT NULL DEFAULT FALSE,
  delivery_radius_m INT CHECK (delivery_radius_m IS NULL OR delivery_radius_m > 0),
  delivery_fee  NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
  min_order     NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (min_order >= 0),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_locations_geo  ON locations USING GIST (geo);
CREATE INDEX idx_locations_open ON locations (is_open_now) WHERE is_active;
CREATE INDEX idx_locations_business ON locations (business_id);
CREATE TRIGGER trg_locations_open_touch BEFORE UPDATE ON locations
  FOR EACH ROW EXECUTE FUNCTION touch_open_status();

CREATE TABLE location_hours (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  weekday     SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  opens_at    TIME NOT NULL,
  closes_at   TIME NOT NULL,
  UNIQUE (location_id, weekday, opens_at)
);

CREATE TABLE payment_accounts (            -- datos para transferencia/pago móvil
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  method      payment_method NOT NULL,
  label       TEXT NOT NULL,
  details     JSONB NOT NULL,               -- banco, cuenta, teléfono, cédula
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_payment_accounts_business ON payment_accounts (business_id) WHERE is_active;

-- ---------- CATÁLOGO Y LISTA DE PRECIOS ----------
CREATE TABLE product_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  sort_order  INT NOT NULL DEFAULT 0
);
CREATE INDEX idx_categories_business ON product_categories (business_id);

CREATE TABLE products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
  name        TEXT NOT NULL,
  description TEXT,
  price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  image_id    UUID REFERENCES media_assets(id) ON DELETE SET NULL,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_business ON products (business_id) WHERE is_available;
CREATE INDEX idx_products_category ON products (category_id);
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE product_option_groups (       -- "Tamaño", "Extras", "Salsas"
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  min_select  SMALLINT NOT NULL DEFAULT 0 CHECK (min_select >= 0),
  max_select  SMALLINT NOT NULL DEFAULT 1 CHECK (max_select >= min_select)
);
CREATE INDEX idx_option_groups_product ON product_option_groups (product_id);

CREATE TABLE product_options (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID NOT NULL REFERENCES product_option_groups(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  extra_price NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (extra_price >= 0),
  is_available BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_options_group ON product_options (group_id);

-- ---------- PEDIDOS ----------
CREATE TABLE orders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT NOT NULL UNIQUE,        -- código corto legible (#A1B2)
  business_id   UUID NOT NULL REFERENCES businesses(id),
  location_id   UUID NOT NULL REFERENCES locations(id),
  customer_id   UUID NOT NULL REFERENCES users(id),
  type          order_type NOT NULL,
  status        fulfillment_status NOT NULL DEFAULT 'pending',
  payment_status payment_status NOT NULL DEFAULT 'unpaid',
  payment_method payment_method,
  subtotal      NUMERIC(10,2) NOT NULL CHECK (subtotal >= 0),
  delivery_fee  NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
  total         NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  delivery_address TEXT,
  delivery_geo  GEOGRAPHY(Point,4326),
  eta_arrival_at TIMESTAMPTZ,                -- "dejar pedido pendiente mientras llego"
  customer_note TEXT,
  confirmed_by  UUID REFERENCES users(id),   -- confirmación manual
  paid_confirmed_by UUID REFERENCES users(id),
  paid_at       TIMESTAMPTZ,
  sent_at       TIMESTAMPTZ,
  delivered_at  TIMESTAMPTZ,
  cancelled_reason TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (total = subtotal + delivery_fee)
);
CREATE INDEX idx_orders_business_status ON orders (business_id, status, created_at DESC);
CREATE INDEX idx_orders_customer ON orders (customer_id, created_at DESC);
CREATE INDEX idx_orders_location ON orders (location_id, created_at DESC);
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE order_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id  UUID REFERENCES products(id) ON DELETE SET NULL,
  name_snapshot  TEXT NOT NULL,              -- congelar nombre/precio al pedir
  unit_price_snapshot NUMERIC(10,2) NOT NULL CHECK (unit_price_snapshot >= 0),
  quantity    INT NOT NULL CHECK (quantity > 0),
  options_snapshot JSONB,
  line_total  NUMERIC(10,2) NOT NULL CHECK (line_total >= 0),
  note        TEXT
);
CREATE INDEX idx_order_items_order ON order_items (order_id);

CREATE TABLE order_status_history (
  id          BIGSERIAL PRIMARY KEY,
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status fulfillment_status,
  to_status   fulfillment_status,
  from_payment payment_status,
  to_payment   payment_status,
  changed_by  UUID REFERENCES users(id),
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (to_status IS NOT NULL OR to_payment IS NOT NULL)
);
CREATE INDEX idx_order_history_order ON order_status_history (order_id, id);

CREATE TABLE payment_proofs (              -- comprobante subido por el cliente
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  media_id    UUID NOT NULL REFERENCES media_assets(id),
  reference_code TEXT,
  amount      NUMERIC(10,2) CHECK (amount IS NULL OR amount >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_payment_proofs_order ON payment_proofs (order_id);

-- ---------- SALA DE ESPERA Y RESERVAS ----------
CREATE TABLE waiting_room_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES users(id),
  order_id    UUID REFERENCES orders(id) ON DELETE SET NULL,
  party_size  SMALLINT NOT NULL DEFAULT 1 CHECK (party_size > 0),
  status      waiting_status NOT NULL DEFAULT 'waiting',
  estimated_arrival_at TIMESTAMPTZ,
  called_at   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_waiting_location ON waiting_room_entries (location_id, status, created_at);
CREATE INDEX idx_waiting_customer ON waiting_room_entries (customer_id, status);

CREATE TABLE reservations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES users(id),
  party_size  SMALLINT NOT NULL CHECK (party_size > 0),
  reserved_for TIMESTAMPTZ NOT NULL,
  status      reservation_status NOT NULL DEFAULT 'requested',
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reservations_loc_time ON reservations (location_id, reserved_for);
CREATE INDEX idx_reservations_customer ON reservations (customer_id, created_at DESC);

-- ---------- PUBLICACIONES ----------
CREATE TABLE posts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES users(id),
  body        TEXT NOT NULL,
  is_promo    BOOLEAN NOT NULL DEFAULT FALSE,
  is_boosted  BOOLEAN NOT NULL DEFAULT FALSE,   -- monetización: destacar
  boosted_until TIMESTAMPTZ,
  expires_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_posts_feed ON posts (created_at DESC);
CREATE INDEX idx_posts_business ON posts (business_id, created_at DESC);

CREATE TABLE post_media (
  post_id   UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  media_id  UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (post_id, media_id)
);

CREATE TABLE post_likes (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX idx_likes_user ON post_likes (user_id);

CREATE TABLE favorites (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, business_id)
);

-- ---------- CHAT ----------
CREATE TABLE conversations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id    UUID REFERENCES orders(id) ON DELETE SET NULL,
  last_message_at TIMESTAMPTZ,
  -- PG15: NULLS NOT DISTINCT sí deduplica filas con order_id NULL
  UNIQUE NULLS NOT DISTINCT (business_id, customer_id, order_id)
);
CREATE INDEX idx_conversations_customer ON conversations (customer_id, last_message_at DESC);
CREATE INDEX idx_conversations_business ON conversations (business_id, last_message_at DESC);

CREATE TABLE messages (
  id          BIGSERIAL PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id   UUID NOT NULL REFERENCES users(id),
  body        TEXT,
  media_id    UUID REFERENCES media_assets(id) ON DELETE SET NULL,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (body IS NOT NULL OR media_id IS NOT NULL)
);
CREATE INDEX idx_messages_conv ON messages (conversation_id, id DESC);

-- ---------- REPUTACIÓN ----------
CREATE TABLE reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,  -- solo con pedido delivered (regla de app)
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES users(id),
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  business_reply TEXT,
  replied_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reviews_business ON reviews (business_id, created_at DESC);
CREATE TRIGGER trg_reviews_refresh_rating
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW EXECUTE FUNCTION refresh_business_rating();

CREATE TABLE customer_reputation (          -- reputación del cliente (pedidos no recogidos, etc.)
  customer_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  completed_orders INT NOT NULL DEFAULT 0 CHECK (completed_orders >= 0),
  cancelled_orders INT NOT NULL DEFAULT 0 CHECK (cancelled_orders >= 0),
  no_shows    INT NOT NULL DEFAULT 0 CHECK (no_shows >= 0),
  score       NUMERIC(5,2) NOT NULL DEFAULT 100 CHECK (score BETWEEN 0 AND 100)
);

CREATE TABLE reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('business','review','post','user')),
  target_id   UUID NOT NULL,
  reason      TEXT NOT NULL,
  status      report_status NOT NULL DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reports_status ON reports (status, created_at);

-- ---------- WHATSAPP ----------
CREATE TABLE whatsapp_accounts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL UNIQUE REFERENCES businesses(id) ON DELETE CASCADE,
  phone_number_id TEXT NOT NULL,             -- WhatsApp Cloud API
  waba_id     TEXT,
  access_token_enc TEXT NOT NULL,            -- cifrado en reposo
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE whatsapp_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  event       TEXT NOT NULL,                 -- order_confirmed, order_sent, order_delivered, payment_received
  template_name TEXT NOT NULL,
  language    TEXT NOT NULL DEFAULT 'es',
  is_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (business_id, event)
);

CREATE TABLE whatsapp_messages (
  id          BIGSERIAL PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  order_id    UUID REFERENCES orders(id) ON DELETE SET NULL,
  direction   msg_direction NOT NULL,
  wa_message_id TEXT,
  to_from_phone TEXT NOT NULL,
  body        TEXT,
  status      TEXT,                          -- queued, sent, delivered, read, failed
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_wa_messages_business ON whatsapp_messages (business_id, created_at DESC);
CREATE INDEX idx_wa_messages_order ON whatsapp_messages (order_id);

-- ---------- MONETIZACIÓN (lado empresa) ----------
CREATE TABLE plans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL UNIQUE,          -- free, pro, business
  name        TEXT NOT NULL,
  price_monthly NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (price_monthly >= 0),
  limits      JSONB NOT NULL,                -- {"products":30,"locations":1,"whatsapp":false,"posts_month":4}
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  plan_id     UUID NOT NULL REFERENCES plans(id),
  status      sub_status NOT NULL DEFAULT 'trialing',
  current_period_start TIMESTAMPTZ NOT NULL,
  current_period_end   TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (current_period_end > current_period_start)
);
CREATE INDEX idx_subscriptions_business ON subscriptions (business_id, status);

CREATE TABLE ad_boosts (                    -- destacar local en el mapa/lista
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('featured_listing','promoted_post')),
  starts_at   TIMESTAMPTZ NOT NULL,
  ends_at     TIMESTAMPTZ NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL CHECK (amount_paid >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);
CREATE INDEX idx_boosts_location ON ad_boosts (location_id, starts_at, ends_at);

CREATE TABLE platform_invoices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  concept     TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','void')),
  paid_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_invoices_business ON platform_invoices (business_id, created_at DESC);

-- ---------- NOTIFICACIONES ----------
CREATE TABLE notifications (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  title       TEXT NOT NULL,
  body        TEXT,
  data        JSONB,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);

-- ---------- CONSULTA CLAVE: locales abiertos cerca del cliente ----------
-- SELECT l.id, l.name, b.name AS business, b.rating_avg,
--        ST_Distance(l.geo, ST_MakePoint(:lng,:lat)::geography) AS dist_m
-- FROM locations l JOIN businesses b ON b.id = l.business_id
-- WHERE l.is_active AND l.is_open_now AND b.is_active
--   AND ST_DWithin(l.geo, ST_MakePoint(:lng,:lat)::geography, :radius_m)
-- ORDER BY (SELECT COUNT(*) FROM ad_boosts a WHERE a.location_id=l.id AND now() BETWEEN a.starts_at AND a.ends_at) DESC,
--          dist_m ASC
-- LIMIT 30;
