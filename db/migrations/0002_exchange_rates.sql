-- 0002_exchange_rates.sql — Tasa USD→VES (Bs)
-- Los precios viven anclados a USD; esta tabla permite mostrar/cobrar en Bs.
CREATE TABLE IF NOT EXISTS exchange_rates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_ccy    CHAR(3) NOT NULL DEFAULT 'USD',
  quote_ccy   CHAR(3) NOT NULL DEFAULT 'VES',
  rate        NUMERIC(14,6) NOT NULL CHECK (rate > 0),
  source      TEXT NOT NULL DEFAULT 'manual',
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (base_ccy, quote_ccy, valid_from)
);
CREATE INDEX IF NOT EXISTS idx_rates_latest ON exchange_rates (base_ccy, quote_ccy, valid_from DESC);

ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rates_public_read ON exchange_rates;
CREATE POLICY rates_public_read ON exchange_rates FOR SELECT USING (true);
GRANT SELECT ON exchange_rates TO anon, authenticated;
