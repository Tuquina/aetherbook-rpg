# CLAUDE.md — Aetherbook (RPG narrativo con IA)

Este archivo es el contexto persistente para Claude Code. Leelo entero antes de tocar código. Si algo que te pido contradice estas reglas, avisá antes de proceder.

---

## 1. Qué es este proyecto

Un RPG de narrativa interactiva ("elige tu propia aventura" evolucionado) donde la historia se escribe en tiempo real según las decisiones del jugador, impulsada por modelos de IA gratuitos. Un *Game Master* de IA narra sobre un estado de juego que el motor controla de forma determinista.

Tres modos sobre el mismo motor: **freeform** (IA genera todo), **curada** (campañas escritas a mano) e **híbrida** (esqueleto fijo + relleno generativo, es el modo por defecto). Mundos iniciales: Isekai, Xianxia, Superhéroes, Cyberpunk, Post-apocalíptico (son 5 mundos distintos — Isekai y Xianxia NO son el mismo, aunque compartan la premisa de "otro mundo").

El documento de diseño completo es `GDD-RPG-Narrativo-IA.md`. Este archivo es la versión operativa para desarrollar.

---

## 2. Reglas de oro (no negociables)

1. **El estado manda; la IA solo narra.** La fuente de verdad de stats, inventario, flags y trama es Postgres. La IA nunca calcula ni decide mecánicas: recibe resultados ya resueltos y los narra. Si te pido "que la IA decida el daño", frená y proponé resolverlo en el motor.
2. **Las mecánicas se resuelven en código, no en el prompt.** Tiradas, chequeos, EXP y costos son funciones deterministas y testeadas.
3. **Los `state_deltas` que sugiere la IA son propuestas que el motor valida** antes de aplicar. Nunca se aplican a ciegas.
4. **Las API keys nunca tocan el cliente.** Toda llamada a proveedores de IA pasa por Edge Functions en el servidor.
5. **El dominio no depende de infra.** `core/` es Dart puro: sin HTTP, sin Supabase, sin nombres de proveedores. Todo lo externo entra por un puerto.
6. **Agnóstico al proveedor de IA.** Cambiar de Gemini a Groq no debe tocar la lógica de juego, solo el adaptador inyectado.
7. **Los tiers gratuitos son una restricción de diseño.** Asumí rate limits estrictos y cachea todo lo posible.

---

## 3. Stack

- **Cliente:** Flutter (iOS / Android / web, una sola base de código). Dart.
- **Backend:** Supabase — Postgres (estado + event log), Auth, Storage (imágenes cacheadas), RLS.
- **Broker de IA:** Supabase Edge Functions (Deno / TypeScript). Guardan las keys y orquestan el fallback.
- **Narración:** Gemini Flash (principal, structured output) → Groq → Cerebras/OpenRouter (fallback).
- **Imágenes:** Pollinations / Cloudflare Workers AI, cacheadas en Storage.

> Los límites de los tiers gratuitos cambian casi todos los meses. No hardcodees supuestos sobre cuotas; hacelos configurables.

---

## 4. Arquitectura — Ports & Adapters

Regla de dependencias: **hacia adentro.** `adapters` → `ports` → `core`. `core` no conoce a nadie de afuera.

```
core/            Dart puro, sin infra
  engine/        ResolvePlayerAction, EXP, chequeos, costos
  narrative/     grafo de nodos, evaluación de gates
  state/         agregados: character, world, session

ports/           interfaces (contratos)
  NarratorPort
  ImageGeneratorPort
  GameStateRepositoryPort
  ContentRepositoryPort

adapters/
  narrator/      (implementados como Edge Functions TS)
    GeminiNarratorAdapter (structured output)
    GroqNarratorAdapter
    FallbackNarratorAdapter   <- orquesta la cadena + reintentos
  image/
    PollinationsAdapter
    CloudflareWorkersAIAdapter
  persistence/
    SupabaseGameStateAdapter
  fakes/
    FakeNarratorAdapter       <- para tests, devuelve JSON fijo
```

El cliente Flutter depende de los **puertos**, nunca de un adaptador concreto. La orquestación de IA vive en Edge Functions.

---

## 5. Contrato del narrador (structured output)

El narrador devuelve **solo JSON válido**, sin markdown, sin backticks, sin preámbulo:

```json
{
  "narration": "Texto en segunda persona…",
  "suggested_choices": ["Opción A", "Opción B", "Opción C"],
  "state_deltas": [
    { "type": "flag", "key": "conocio_al_anciano", "value": true }
  ],
  "image_prompt": "descripción visual de la escena",
  "tone": "tenso"
}
```

- Usá el structured output nativo de Gemini para forzar el schema.
- Siempre implementá parseo tolerante: limpiar fences, y un retry de reparación ("devolvé JSON válido") si viene roto.
- `state_deltas` se validan contra reglas del mundo antes de aplicarse.

---

## 6. Memoria (tres niveles)

1. **Corto plazo:** últimos 2-3 turnos, literales, en el prompt.
2. **Mediano plazo:** un "diario" resumido que se regenera cada ~5 turnos (usá Groq por velocidad). ~150 palabras. Viaja en cada prompt.
3. **Largo plazo:** el estado en Postgres. Lo que no puede perderse va en tablas, nunca en prosa.

Nunca mandes el historial completo al modelo.

---

## 7. Modelo de datos (referencia)

`worlds`, `campaigns`, `game_sessions`, `characters`, `inventory_items`, `story_flags`, `relationships`, `turns` (log inmutable), `memory_digests`. Detalle de columnas en el GDD §8. Diseño *event-sourced light*: `turns` es la fuente de eventos; el estado actual es su proyección. RLS: cada usuario ve solo sus sesiones.

---

## 8. Convenciones de código

- **Dart:** null-safety estricto. Dominio en clases inmutables. Nombres de casos de uso en verbo+sustantivo (`ResolvePlayerAction`). Efectos secundarios solo detrás de puertos.
- **TS (Edge Functions):** tipado estricto, sin `any`. Un adaptador por archivo. Manejo de errores explícito con reintentos y timeouts.
- **Contenido declarativo:** mundos y campañas se cargan desde archivos de datos (JSON), nunca hardcodeados en el motor. Agregar un mundo = agregar un paquete.
- **Sin keys en el repo.** Todo por variables de entorno / secrets de Supabase. Nunca commitees `.env`.
- **Idioma:** narración y UI en español; código, tipos y comentarios técnicos en inglés.

---

## 9. Testing

- El dominio (`core/`) es determinista → **cobertura alta y obligatoria**. Testeá EXP, chequeos, bandas de resultado y evaluación de gates sin mocks de IA.
- Para todo lo que toque IA, usá `FakeNarratorAdapter` (JSON fijo). El juego entero debe ser testeable **sin gastar cuota**.
- Cada adaptador nuevo viene con su test (incluido el caso de JSON roto y el de rate limit → fallback).

---

## 10. Proceso de trabajo (cómo quiero que avances)

1. **Puertos y tests primero**, antes que cualquier adaptador. Diseño por contratos.
2. **Un adaptador a la vez**, chico y testeable.
3. **No introduzcas dependencias de infra en `core/`.** Si hace falta algo externo, es un puerto nuevo.
4. **Cambios chicos y revisables.** Si una tarea es grande, proponé el plan y esperá visto bueno antes de escribir mucho código.
5. Ante ambigüedad de diseño, consultá el GDD; si no está resuelto, preguntá en vez de asumir.

---

## 11. Fase actual: Fase 0 — Prueba de concepto

Objetivo: validar que el loop es divertido y el JSON estructurado funciona.

- [ ] Proyecto Flutter (iOS/Android/web) con estructura ports-and-adapters.
- [ ] `core/engine` con `ResolvePlayerAction` (atributo + d20 vs dificultad, tres bandas) + tests.
- [ ] `NarratorPort` + `FakeNarratorAdapter`.
- [ ] Una Edge Function mínima que llame a Gemini Flash cumpliendo `NarratorPort`.
- [ ] Un mundo (Xianxia) freeform, loop mínimo: acción → resolución → narración JSON → render.
- [ ] Sin auth, sin imágenes; estado en memoria/local.

Lo que **no** hacemos todavía: persistencia real, auth, imágenes, múltiples mundos, campañas curadas. Eso es Fase 1+.

---

## 12. Definition of done (para cada cambio)

- Cumple las reglas de oro (§2).
- El dominio afectado tiene tests que pasan.
- No hay keys ni secrets en el código.
- No se agregaron dependencias de infra a `core/`.
- Si tocaste el contrato del narrador o el modelo de datos, actualizaste el GDD.
