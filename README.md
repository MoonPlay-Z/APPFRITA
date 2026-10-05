# AppFrita

Plataforma multiempresa de comida rápida. Cliente (app) encuentra locales abiertos y cerca; negocios gestionan pedidos, menú y chat.

## Empezar

```bash
cp .env.example .env        # rellenar credenciales de Supabase
npm install
npm run dev:api             # NestJS (cuando se implemente el código)
npm run dev:web             # Next.js
```

## Estructura

- `db/schema.sql` — esquema completo (Supabase + PostGIS)
- `db/migrations/` — migraciones versionadas (0001 RLS, 0002 tasas)
- `docs/PROYECTO_IA.md` — convenciones y ciclo por módulo
- `docs/modulos/` — spec por módulo (00–12)
- `DESIGN.md` — dirección visual
- `apps/api|web|mobile`, `packages/contracts`

## Reglas

Ver `AGENTS.md` y `docs/PROYECTO_IA.md`. Montos siempre en USD; Bs vía `exchange_rates`.
