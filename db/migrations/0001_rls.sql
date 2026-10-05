-- 0001_rls.sql — Row Level Security (Supabase)
-- Contexto: la API NestJS conecta con service_role y BYPASSEA RLS.
-- Estas políticas gobiernan el acceso directo desde clientes (anon/authenticated)
-- con la anon key (app Flutter, panel Next.js).
-- auth.uid() devuelve el user_id del JWT de Supabase Auth.
-- NOTA: las filas de `users` deben mapear 1:1 con auth.users (mismo id).

-- ===================== Helper =====================
CREATE OR REPLACE FUNCTION is_business_member(b_id UUID) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM business_members bm
    WHERE bm.business_id = b_id AND bm.user_id = auth.uid()
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ===================== Habilitar RLS =====================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_option_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE waiting_room_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_reputation ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ===================== Lectura PÚBLICA (anon puede buscar) =====================
-- Catálogo y descubrimiento: cualquiera, incluso sin login.
CREATE POLICY businesses_public_read ON businesses
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY locations_public_read ON locations
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY location_hours_public_read ON location_hours
  FOR SELECT USING (TRUE);

CREATE POLICY categories_public_read ON product_categories
  FOR SELECT USING (TRUE);

CREATE POLICY products_public_read ON products
  FOR SELECT USING (is_available = TRUE);

CREATE POLICY option_groups_public_read ON product_option_groups
  FOR SELECT USING (TRUE);

CREATE POLICY options_public_read ON product_options
  FOR SELECT USING (is_available = TRUE);

CREATE POLICY posts_public_read ON posts
  FOR SELECT USING (expires_at IS NULL OR expires_at > now());

CREATE POLICY post_media_public_read ON post_media
  FOR SELECT USING (TRUE);

CREATE POLICY media_public_read ON media_assets
  FOR SELECT USING (TRUE);

CREATE POLICY plans_public_read ON plans
  FOR SELECT USING (is_active = TRUE);

-- ===================== users =====================
CREATE POLICY users_self_read ON users FOR SELECT USING (id = auth.uid());
CREATE POLICY users_self_update ON users FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY oauth_self ON oauth_identities FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY refresh_self ON refresh_tokens FOR SELECT USING (user_id = auth.uid());
CREATE POLICY device_tokens_self ON device_tokens FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY addresses_self ON customer_addresses FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ===================== Multi-tenant empresa =====================
CREATE POLICY business_members_read ON business_members FOR SELECT
  USING (user_id = auth.uid() OR is_business_member(business_id));

CREATE POLICY locations_tenant_all ON locations FOR ALL
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));
-- El toggle is_open_now se permite directo al cliente autenticado dueño/staff:
CREATE POLICY locations_member_toggle ON locations FOR UPDATE
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));

CREATE POLICY hours_tenant_all ON location_hours FOR ALL
  USING (is_business_member((SELECT business_id FROM locations WHERE id = location_id)))
  WITH CHECK (is_business_member((SELECT business_id FROM locations WHERE id = location_id)));

CREATE POLICY payment_accounts_tenant ON payment_accounts FOR SELECT
  USING (is_business_member(business_id));

CREATE POLICY categories_tenant_all ON product_categories FOR ALL
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));
CREATE POLICY products_tenant_all ON products FOR ALL
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));
CREATE POLICY option_groups_tenant_all ON product_option_groups FOR ALL
  USING (is_business_member((SELECT business_id FROM products WHERE id = product_id)))
  WITH CHECK (is_business_member((SELECT business_id FROM products WHERE id = product_id)));
CREATE POLICY options_tenant_all ON product_options FOR ALL
  USING (is_business_member((SELECT p.business_id FROM products p
        JOIN product_option_groups g ON g.product_id = p.id
        WHERE g.id = group_id)))
  WITH CHECK (is_business_member((SELECT p.business_id FROM products p
        JOIN product_option_groups g ON g.product_id = p.id
        WHERE g.id = group_id)));

-- ===================== Pedidos =====================
-- Cliente: ve y crea sus pedidos. Empresa: ve y gestiona los suyos.
CREATE POLICY orders_customer_read ON orders FOR SELECT USING (customer_id = auth.uid());
CREATE POLICY orders_customer_create ON orders FOR INSERT WITH CHECK (customer_id = auth.uid());
CREATE POLICY orders_tenant_read ON orders FOR SELECT USING (is_business_member(business_id));
CREATE POLICY orders_tenant_update ON orders FOR UPDATE
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));

CREATE POLICY order_items_customer_read ON order_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid()));
CREATE POLICY order_items_customer_create ON order_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid()));
CREATE POLICY order_items_tenant ON order_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND is_business_member(o.business_id)));

CREATE POLICY order_history_customer_read ON order_status_history FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid()));
CREATE POLICY order_history_tenant ON order_status_history FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND is_business_member(o.business_id)));

CREATE POLICY proofs_customer_create ON payment_proofs FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid()));
CREATE POLICY proofs_customer_read ON payment_proofs FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid()));
CREATE POLICY proofs_tenant ON payment_proofs FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND is_business_member(o.business_id)));

-- ===================== Sala de espera y reservas =====================
CREATE POLICY waiting_customer ON waiting_room_entries FOR ALL
  USING (customer_id = auth.uid()) WITH CHECK (customer_id = auth.uid());
CREATE POLICY waiting_tenant ON waiting_room_entries FOR SELECT
  USING (is_business_member((SELECT business_id FROM locations WHERE id = location_id)));

CREATE POLICY reservations_customer ON reservations FOR ALL
  USING (customer_id = auth.uid()) WITH CHECK (customer_id = auth.uid());
CREATE POLICY reservations_tenant ON reservations FOR SELECT
  USING (is_business_member((SELECT business_id FROM locations WHERE id = location_id)));

-- ===================== Publicaciones / social =====================
CREATE POLICY posts_tenant_all ON posts FOR ALL
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));
CREATE POLICY post_media_tenant ON post_media FOR ALL
  USING (EXISTS (SELECT 1 FROM posts p WHERE p.id = post_id AND is_business_member(p.business_id)));
CREATE POLICY likes_self ON post_likes FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY favorites_self ON favorites FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ===================== Chat =====================
CREATE POLICY conversations_customer ON conversations FOR SELECT USING (customer_id = auth.uid());
CREATE POLICY conversations_tenant ON conversations FOR SELECT USING (is_business_member(business_id));
CREATE POLICY messages_customer_read ON messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM conversations c WHERE c.id = conversation_id AND c.customer_id = auth.uid()));
CREATE POLICY messages_customer_send ON messages FOR INSERT
  WITH CHECK (sender_id = auth.uid() AND EXISTS (SELECT 1 FROM conversations c WHERE c.id = conversation_id AND c.customer_id = auth.uid()));
CREATE POLICY messages_tenant_read ON messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM conversations c WHERE c.id = conversation_id AND is_business_member(c.business_id)));
CREATE POLICY messages_tenant_send ON messages FOR INSERT
  WITH CHECK (sender_id = auth.uid() AND EXISTS (SELECT 1 FROM conversations c WHERE c.id = conversation_id AND is_business_member(c.business_id)));

-- ===================== Reputación =====================
CREATE POLICY reviews_customer_create ON reviews FOR INSERT
  WITH CHECK (customer_id = auth.uid() AND EXISTS (
    SELECT 1 FROM orders o WHERE o.id = order_id AND o.customer_id = auth.uid() AND o.status = 'delivered'));
CREATE POLICY reviews_customer_read ON reviews FOR SELECT USING (customer_id = auth.uid());
CREATE POLICY reviews_public_read ON reviews FOR SELECT USING (TRUE);
CREATE POLICY reviews_tenant_update ON reviews FOR UPDATE
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));

CREATE POLICY reputation_self ON customer_reputation FOR SELECT USING (customer_id = auth.uid());
CREATE POLICY reports_self ON reports FOR ALL USING (reporter_id = auth.uid()) WITH CHECK (reporter_id = auth.uid());

-- ===================== WhatsApp / monetización / internas =====================
CREATE POLICY wa_accounts_tenant ON whatsapp_accounts FOR SELECT USING (is_business_member(business_id));
CREATE POLICY wa_templates_tenant ON whatsapp_templates FOR ALL
  USING (is_business_member(business_id)) WITH CHECK (is_business_member(business_id));
CREATE POLICY wa_messages_tenant ON whatsapp_messages FOR SELECT USING (is_business_member(business_id));
CREATE POLICY subscriptions_tenant ON subscriptions FOR SELECT USING (is_business_member(business_id));
CREATE POLICY boosts_tenant ON ad_boosts FOR SELECT USING (is_business_member(business_id));
CREATE POLICY invoices_tenant ON platform_invoices FOR SELECT USING (is_business_member(business_id));

-- ===================== Notificaciones =====================
CREATE POLICY notifications_self ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY notifications_self_read_update ON notifications FOR UPDATE USING (user_id = auth.uid());

-- ===================== Grants =====================
-- Supabase: anon = sin login, authenticated = con JWT.
-- Lectura pública:
GRANT SELECT ON businesses, locations, location_hours, product_categories, products,
  product_option_groups, product_options, posts, post_media, media_assets, plans, reviews
TO anon;
-- Cliente logueado: sus recursos + lectura pública (las políticas filtran).
GRANT SELECT, INSERT, UPDATE ON users, oauth_identities, device_tokens, customer_addresses,
  orders, order_items, payment_proofs, waiting_room_entries, reservations, post_likes, favorites,
  conversations, messages, reviews, reports, notifications, customer_reputation, locations
TO authenticated;
-- Tablas internas: solo lectura del dueño vía authenticated; escrituras vía service_role.
GRANT SELECT ON business_members, payment_accounts, order_status_history, subscriptions,
  ad_boosts, platform_invoices, whatsapp_accounts, whatsapp_templates, whatsapp_messages
TO authenticated;
