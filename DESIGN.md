# DESIGN.md — Dirección visual del producto

Aplica a: landing web, panel de empresa (Next.js) y app cliente (Flutter).
Skill que gobierna el proceso: `refero-design` (`.agents/skills/refero-design`).

## Brief

Producto: plataforma multiempresa de comida rápida. Usuario final en la calle buscando algo abierto y cerca, ya.
Goal: encontrar y elegir un local abierto cerca en <30s.
Tone: directo, apetitoso, confianza callejera — no "AI clean startup".
Research: Refero MCP aún no configurado → dirección derivada del craft bundled + modelo de datos.

## Reference lock (tokens de diseño)

- Canvas: claro neutro (`--bg #fafafa`, `--surface #ffffff`, `--ink #16181d`, `--muted #6b7280`, `--border #e5e7eb`).
- Un solo acento semántico: verde intenso (`--open #0f9d58`) = abierto; gris (`--closed #9ca3af`) = cerrado. Sin degradés decorativos.
- Tipografía: grotesca compacta (system-ui por ahora), 2 pesos; precios en tabular numbers.
- Radius: cards/inputs 12–14px; pills 999px.
- Espaciado base 8px.

## Reglas de componentes

- Cards: nombre, distancia, rating, rango $/$$, badge "Abierto · cierra 10pm" o "Cierra pronto".
- Badge "Promocionado" (ad_boosts): discreto, nunca domina el rating.
- Pins de mapa: pill con rating y "desde $X", no pin genérico.
- Precios: USD anclado en toda la UI; equivalente Bs solo en detalle; tasa "$1 = X Bs" visible una vez por pantalla.

## Pantalla de descubrimiento

- Mapa como superficie principal + bottom sheet (peek/medio/full).
- Estados: skeleton de lista + mapa (carga); "Nada abierto cerca" + ampliar radio + "Avísame cuando abran" (vacío); explicación + búsqueda manual (sin permiso de ubicación); clusters + filtros por abierto/categoría/precio (muchos resultados).

## Decision ledger

| Decisión | Fuente | Por qué |
|---|---|---|
| Mapa + bottom sheet | craft bundled | patrón probado en descubrimiento callejero |
| Verde abierto / gris cerrado | constraint de negocio | "abierto ahora" es la decisión #1 del usuario |
| Pin pill con precio | craft bundled | precio visible antes de abrir detalle |
| USD anclado, Bs secundario | constraint de negocio | evita ruido en cada card |

## Pendiente de marca

- Logo y nombre final (hoy "AppFrita" provisional).
- Fuente definitiva y escala tipográfica.
- Paleta definitiva tras investigación Refero MCP (estilos).

## Sistema de diseño vigente (Stitch — AppFrita Street Flavor)

Fuente de verdad: `diseño grafico/stitch_local_street_food_delivery_platform/appfrita_street_flavor/DESIGN.md`.
Colores clave: primario flame `#AD2C00`, amarillo cheddar `#FFB703` (ratings/promos), verde guacamole `#2A9D8F` (abierto/éxito), canvas crema `#FCF9F8`, tinta `#1C1B1B`.
Tipografía: Epilogue (headlines, pesos 700-800) + Plus Jakarta Sans (body/labels). Esquinas tipo pill, cards de 32px. Implementado en Flutter en `apps/mobile/lib/theme.dart` (`AppTheme.light`).
