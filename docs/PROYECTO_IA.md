# PROYECTO_IA.md — Contexto fijo y esquema de trabajo

Pegar como contexto fijo (o equivalente) en cada sesión de IA que trabaje en este repo.

## Qué es

Plataforma multiempresa de comida rápida. El cliente (gratis) ve locales abiertos y cercanos, consulta precios, pide delivery o deja pedido pendiente con ETA, chatea, reserva y califica. La empresa (plan de pago) gestiona locales, menú, pedidos, chat, publicaciones, reservas, reputación y WhatsApp.

## Stack

- API: NestJS + TypeScript — Web empresa: Next.js (App Router) — App cliente: Flutter
- BD: PostgreSQL en **Supabase** + PostGIS. Migraciones versionadas en `/db/migrations`.
- Imágenes: S3/R2/Storage — Tiempo real: WebSockets — Colas: BullMQ/Redis
- ORM: **Prisma** (schema generado con `prisma db pull` contra Supabase; las migraciones SQL de `/db/migrations` son la fuente de verdad, no `prisma migrate`).

## Fuentes de verdad

- BD: `/db/schema.sql` — **no inventar tablas ni columnas**; si falta algo, proponerlo.
- API: `/packages/contracts/openapi.yaml`
- Specs por módulo: `/docs/modulos/*.md`
- Si docs y código chocan, manda el código/config ejecutable.

## Reglas de negocio clave

- Multi-tenant: toda consulta de empresa filtra por `business_id` del JWT; nunca confiar en `business_id`/`user_id` del body.
- `orders.status` (pending→confirmed→preparing→ready→sent→delivered|cancelled) y `payment_status` (unpaid→proof_uploaded→paid|rejected|refunded) son **independientes**.
- Todo cambio de estado/pago escribe `order_status_history` y usa transacción.
- Precios y nombres se congelan en `order_items` al pedir (`*_snapshot`); los totales se calculan en servidor.
- Reseña solo si el pedido está `delivered`; 1 por pedido (`reviews.order_id UNIQUE`).
- Cliente siempre gratis; límites por `plans.limits` aplican al lado empresa.
- Monedas: montos siempre en USD en BD; conversión a Bs (VES) con `exchange_rates` en runtime.

## Reglas de trabajo para la IA

1. Trabaja SOLO el módulo/fase indicado. No toques otros archivos.
2. Si falta información, máx. 3 preguntas antes de escribir código.
3. Responde con código + lista breve de archivos tocados. Sin explicaciones largas.
4. No inventes paquetes, APIs ni versiones: si dudas, dilo.
5. Valida entrada (DTOs), errores con códigos HTTP correctos, precios siempre en servidor.
6. Incluye tests del service para la lógica de negocio (caso feliz + 2 errores).
7. Al terminar: lista "Supuestos hechos" y "Pendiente".

## Ciclo por módulo (siempre el mismo orden)

1. Spec en `docs/modulos/<modulo>.md` (5-10 líneas).
2. Migración del módulo (solo sus tablas) en `/db/migrations`.
3. Contrato en OpenAPI (request/response/errores).
4. Backend NestJS (controller, service, DTOs, guards) + tests.
5. Cliente (Next.js o Flutter) que consume el contrato.
6. Checklist de revisión (abajo) y commit pequeño.

## Checklist de revisión

- [ ] ¿Toda consulta filtra por `business_id` del JWT?
- [ ] ¿Transiciones de estado inválidas rechazadas?
- [ ] ¿Transacción donde se escriben varias tablas?
- [ ] ¿DTOs validan tipos, rangos, longitudes?
- [ ] ¿SQL parametrizado (sin concatenación)?
- [ ] ¿Precios calculados en servidor, no aceptados del cliente?
- [ ] ¿Índices para las consultas nuevas?
- [ ] ¿Tests: caso feliz + 2 de error?

## Fases

0. Base: monorepo, Supabase (schema + RLS), CI, auth JWT.
1. Empresas y locales. 2. Catálogo y precios. 3. Descubrimiento (mapa/lista).
4. Pedidos + pagos manuales. 5. Imágenes. 6. Pedido pendiente + sala de espera.
7. Chat + push. 8. Reseñas/reputación. 9. Publicaciones. 10. Reservas.
11. WhatsApp. 12. Planes, suscripciones, destacados.

## Deuda técnica conocida del schema (resolver en Fase 0)

- RLS implementado (`db/migrations/0001_rls.sql`): API NestJS con `service_role` (bypasea RLS), clientes Flutter/Next.js con anon key limitados por políticas (lectura pública de catálogo/locales, cada usuario sus pedidos/reseñas/chat).
- Las filas de `users` deben tener el mismo `id` que su fila en `auth.users` de Supabase Auth, o `auth.uid()` no las enlaza.
- Resuelto en schema.sql: `conversations` usa `UNIQUE NULLS NOT DISTINCT` (PG15+); `rating_avg`/`rating_count` se recalculan con trigger; `updated_at` vía trigger.

## Ahorro de tokens

- Contexto fijo aquí; por tarea usar solo la plantilla:
  `MÓDULO / FASE / OBJETIVO / REGLAS / TABLAS (nombres, no pegar schema) / ENTREGABLE / NO HAGAS`.
- Un módulo por conversación; al cerrar, prompt de traspaso (máx. 15 líneas: hecho, decisiones, supuestos, pendiente, siguiente paso) y guardarlo en `docs/modulos/<modulo>.md`.
- Errores: pegar mensaje + 20-30 líneas relevantes, no el archivo entero.
- Modelo rápido para CRUD/DTOs/tests; potente para arquitectura, estados, seguridad, revisión.
