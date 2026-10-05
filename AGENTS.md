# AGENTS.md

## Qué es

Plataforma multiempresa de comida rápida (monorepo, en construcción). Las reglas completas están en `docs/PROYECTO_IA.md` — léelo al empezar.

## Estructura

- `/db/schema.sql` — esquema completo; cambios solo vía `/db/migrations`. No inventar tablas/columnas.
- `/packages/contracts/openapi.yaml` — contrato de API (fuente de verdad una vez creado).
- `/docs/modulos/*.md` — spec por módulo.
- Planeado: `/apps/api` (NestJS), `/apps/web` (Next.js App Router), `/apps/mobile` (Flutter).
- `DESIGN.md` — dirección visual (reference lock, tokens, reglas de componentes).

## Stack y decisiones

- BD: PostgreSQL en **Supabase** + PostGIS. Conectar por pooler `:6543` (`?pgbouncer=true&connection_limit=1`); la directa `:5432` no responde en redes sin IPv6.
- ORM/cliente: **Prisma** (`apps/api/prisma/schema.prisma`, regenerado con `prisma db pull`). Tras cada migración SQL: `cd apps/api && npx prisma db pull && npx prisma generate`. Los SQL de `/db/migrations` son la fuente de verdad; no usar `prisma migrate` para cambiar la BD. Cliente generado en `apps/api/generated/prisma` (no commitear). State management de Flutter: pendiente.
- NestJS corre con **tsx** (`npm run start:dev -w apps/api`) porque tsx/esbuild NO emite decorator metadata: usar `@Inject(X)` explícito en constructor params. Prisma 7 requiere driver adapter `@prisma/adapter-pg` (`PrismaPg`).

## Reglas de negocio no negociables

- Multi-tenant: todo query de empresa filtra por `business_id` del JWT (nunca del body del cliente).
- `orders.status` y `orders.payment_status` son independientes; cada cambio escribe `order_status_history` y va en transacción.
- Los totales se calculan en servidor; nombre/precio/opciones se congelan en `order_items` (`*_snapshot`).
- Reseña solo con pedido `delivered`, 1 por pedido.
- Monedas: todos los precios se almacenan en USD (anclados). VES/Bs se calcula en runtime con `exchange_rates` (USD→VES, vigente por fecha). No guardar montos en Bs en tablas de precios/pedidos.

## Deuda técnica del schema (Fase 0)

- ~~RLS~~: decidido e implementado en `db/migrations/0001_rls.sql`. La API NestJS usa `service_role` (bypasea RLS); las políticas gobiernan el acceso directo de clientes con anon key.
- ~~unicidad conversations~~ resuelto con `UNIQUE NULLS NOT DISTINCT` (PG15+).
- ~~rating_avg~~ resuelto con trigger `refresh_business_rating`.

## Ciclo por módulo

Spec → migración → contrato OpenAPI → backend (controller/service/DTOs/tests) → cliente → checklist de `docs/PROYECTO_IA.md` → commit.
