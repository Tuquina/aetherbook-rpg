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

## 11. Fase actual: Fase 1 — MVP jugable (en curso)

La Fase 0 (prueba de concepto) está completa y superada. Hoy la app tiene, además del loop mínimo original:

- [x] Proyecto Flutter (iOS/Android/web) con estructura ports-and-adapters.
- [x] `core/engine` con `ResolvePlayerAction` (atributo + d20 vs dificultad, tres bandas, ventaja/desventaja) + tests.
- [x] `NarratorPort` conectado de punta a punta: `HttpNarratorAdapter` (Gemini → Groq de fallback vía `FallbackNarratorAdapter`, desplegado como Edge Function) es el adaptador real que usa el cliente (`lib/main.dart`) — `FakeNarratorAdapter` sigue existiendo solo para tests, nunca gasta cuota ahí.
- [x] Persistencia real en Supabase (Auth anónimo + RLS por sesión), con degradación a memoria si falla.
- [x] Memoria de tres niveles: corto plazo literal, diario resumido cada ~5 turnos vía Groq (Edge Function `memory-digest`, conectada al cliente con `HttpMemoryDigestAdapter`), estado largo plazo en Postgres.
- [x] Posición dentro del grafo (nodo actual, turnos de corredor, progreso de conflicto extendido) persistida en Supabase (`game_sessions.current_node_id`/`corridor_turns_used`/`extended_conflict_progress`) — una campaña curada u híbrida sobrevive un refresh o cerrar la app.
- [x] `core/narrative` con los 4 tipos de nodo de una campaña híbrida real (`fixed_anchor`, `bounded_corridor`, `state_hub`, `resolution`), gates, conflictos extendidos y combate por `guard`.
- [x] Chargen estructurado (`CreateCharacter`: origen, punto libre, juramento, objeto personal) y progresión por rango con hitos (`RankProgression`), no solo EXP lineal.
- [x] Contrato del narrador v2 (choices con intención/chequeo esperado, deltas con motivo). `ClassifyFreeAction` reemplaza a `InferActionAttribute` en `GameController.choose()`: decide el atributo del chequeo igual que antes (mismo voto por keyword), y además rechaza en el motor — antes de narrar — un intento de autootorgarse algo (`canonCompatibility == invalid`) en vez de dejar que la IA lo interprete.
- [x] Una campaña híbrida real cargada como contenido declarativo: **"Los nombres que devora el cielo"** (`assets/worlds/xianxia_lianshu.json`, 19 nodos, reparto, técnicas, 7 finales). Su vertical slice recomendado (apertura curada → corredor → hub → hito con conflicto extendido) es jugable de punta a punta, verificado con test automatizado contra el contenido real y con una sesión manual en navegador. Ahora se narra con el modelo real, no con JSON fijo.
- [x] Una historia curada 100% sin IA cargada como segundo mundo: **"El último tren no espera a los vivos"** (`assets/worlds/curated_zombie_01_ultimo_tren.json`, ~103 nodos, prólogo + 10 capítulos, 6 finales + 2 fracasos + epílogo modular). `ai_runtime_required: false` y `free_text_actions: false`: el narrador nunca se invoca para esta campaña, cero llamadas de red en partida.
- [x] Menú inicial para elegir historia (`WorldSelectScreen`), agrupado en 3 módulos (historias completas / pre-armadas / narrador por IA — este último deshabilitado hasta que haya contenido freeform real), y navegación de vuelta al menú desde dentro de una partida, sin perder la sesión en memoria. Incluye "reiniciar historia" (abandona la sesión persistida y empieza una limpia).
- [x] Inventario real: `ItemDefinition` declarativo por mundo (`World.items`, id/nombre/descripción/categoría), `World.findItem` no-throwing para degradar con gracia un id sin describir, y `InventoryScreen` (accesible desde el ícono en `StatusBar`, con contador) que le pone nombre y descripción a lo que antes eran solo ids sueltos en `character.lists['inventory']`. Los 16 ítems de "El último tren..." están descriptos; test de contenido asegura que todo id otorgado por un `list_add` tenga descripción.

Lo que falta para cerrar la Fase 1 (todo lo demás del roadmap del GDD sigue siendo Fase 2+):

- Cablear el resto de los 19 nodos de la campaña híbrida (finales, epílogo, elección de técnica al subir de rango) — el contenido ya existe (pasa la validación estática completa: sin referencias colgantes, los 5 finales y el epílogo cubiertos), falta jugarlo con la UI real más allá del vertical slice recomendado para encontrar bugs de runtime que un test estático no ve.
- Los otros 4 mundos del GDD (Isekai, Superhéroes, Cyberpunk, Post-apocalíptico genérico de fase 2) todavía no tienen contenido — eso es explícitamente Fase 2. (El post-apocalíptico zombi de "El último tren..." es una historia curada completa, no el mundo freeform/híbrido de Fase 2.)

---

## 12. Definition of done (para cada cambio)

- Cumple las reglas de oro (§2).
- El dominio afectado tiene tests que pasan.
- No hay keys ni secrets en el código.
- No se agregaron dependencias de infra a `core/`.
- Si tocaste el contrato del narrador o el modelo de datos, actualizaste el GDD.
