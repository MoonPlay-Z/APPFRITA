# Módulo 0 — Base

Qué hace: monorepo funcional, Supabase conectada, auth JWT con registro/login, migraciones corriendo.
Reglas:
- API NestJS conecta como `service_role` (bypasea RLS); guards propios por `business_members`.
- `users.id` = `auth.users.id` (Supabase Auth) para que `auth.uid()` en RLS enlace.
- Migraciones en `/db/migrations`, ordenados; `schema.sql` es la referencia total.
Casos borde: refresh token revocado, usuario inactivo, email duplicado (CITEXT), login sin email (solo teléfono).
Tablas: users, oauth_identities, refresh_tokens, device_tokens, business_members, businesses.
Contrato: POST /auth/register, POST /auth/login, POST /auth/refresh, POST /auth/logout.
Estado: esqueleto de repo y migraciones RLS/exchange_rates creados; falta NestJS + Supabase Auth.
