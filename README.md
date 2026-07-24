# Aetherbook

> RPG de narrativa interactiva impulsado por IA — la historia se escribe en tiempo real según tus decisiones.

Aetherbook es un "elige tu propia aventura" evolucionado: un *Game Master* de IA narra sobre un estado de juego que el motor controla de forma **determinista**. La IA nunca decide mecánicas ni inventa stats — solo narra sobre resultados que el código ya resolvió.

📄 El diseño completo está en [`GDD-RPG-Narrativo-IA.md`](GDD-RPG-Narrativo-IA.md). Las reglas operativas para desarrollar con Claude Code están en [`CLAUDE.md`](CLAUDE.md).

---

## Cómo correrlo y probarlo en local

Todo el toolchain (Flutter y Deno) corre **dentro de Docker** — no hace falta instalar el SDK de Flutter ni de Deno en tu máquina. Único requisito: **Docker Desktop corriendo**.

### Jugarlo (web)

```powershell
.\tool\run-web.ps1        # PowerShell
```
```bash
./tool/run-web.sh         # Git Bash / Linux / macOS
```

La primera vez descarga la imagen de Flutter (~2 GB, una sola vez). Después abrí **http://localhost:8080** en el navegador.

**Para probarlo en el celular** (el juego es móvil-first): buscá la IP de tu PC en la red local (`ipconfig` → IPv4, algo como `192.168.1.40`) y entrá desde el navegador del teléfono a `http://<esa-ip>:8080`. En iPhone, Safari → *Compartir → Agregar a inicio* para que se sienta como una app.

Al abrir la app vas a ver un **menú para elegir historia**: hoy hay tres — **"El último tren no espera a los vivos"** (historia completa curada, **sin IA**: 100% preescrita, cero llamadas de red durante la partida, jugable sin conexión una vez cargada), "Los nombres que devora el cielo" (campaña híbrida curada, con creación de personaje) y "El Sendero del Qi" (modo libre, sin chargen). Dentro de una partida, la flecha arriba a la izquierda vuelve al menú sin perder el progreso (la misma sesión sigue en memoria; volver a entrar a la misma historia la retoma donde quedó).

Por defecto usa el **`FakeNarratorAdapter`** ([lib/main.dart](lib/main.dart)): JSON fijo, sin red, sin costo. El narrador real (Gemini → Groq) ya existe como Edge Function desplegada y funcionando, pero todavía no está conectado al cliente — eso es un paso deliberado, para no gastar cuota mientras iteramos la UI/UX. "El último tren..." ni siquiera usa este adaptador: su motor nunca invoca al narrador (`ai_runtime_required: false`).

### Correr los tests

```powershell
# Dominio + UI (Dart/Flutter)
.\tool\flutter.ps1 test
.\tool\flutter.ps1 analyze

# Edge Function del narrador (Deno/TypeScript)
.\tool\deno.ps1 test --allow-net --allow-env supabase/functions/narrator/
.\tool\deno.ps1 lint supabase/functions/narrator/
```

En Git Bash / Linux / macOS, usá los equivalentes `.sh`: `./tool/flutter.sh test`, `./tool/deno.sh test --allow-net --allow-env supabase/functions/narrator/`.

Ningún test toca red real ni gasta cuota de IA: todo corre contra fakes/mocks (`FakeNarratorAdapter` en Dart, `fetch` mockeado en los tests de Deno).

---

## Qué lo hace distinto

La mayoría de los "juegos con IA" son un chat sin memoria ni reglas. Acá el motor separa claramente:

- **Estado del juego** (determinista, en Postgres): stats, inventario, flags de trama, relaciones, ubicación.
- **Narración** (IA): recibe el estado y el resultado mecánico ya calculado, y solo lo narra con estilo.

Eso elimina el problema clásico de que "el modelo se olvida", inventa ítems o rompe las reglas.

## Tres modos, un solo motor

1. **Aventura libre** — la IA genera la historia turno a turno.
2. **Historia pre-armada** — campañas escritas a mano, con ramas fijas y calidad garantizada.
3. **Híbrido** *(modo por defecto)* — un esqueleto de hitos pre-escritos + relleno generativo dinámico entre ellos. Coherencia de una historia curada, libertad de una generada.

El modo 2 (historia pre-armada) ya tiene una instancia real y completa: **"El último tren no espera a los vivos"** (`assets/worlds/curated_zombie_01_ultimo_tren.json`), post-apocalíptico zombi. 103 nodos, prólogo + 10 capítulos, 6 finales + 2 cierres de fracaso + epílogo modular, ~14.700 palabras de prosa autorada. Cero IA en runtime: cada elección, tirada y consecuencia está preescrita, así que el narrador nunca se invoca y la partida funciona sin conexión.

El modo 3 (híbrido) tiene **"Los nombres que devora el cielo"** (`assets/worlds/xianxia_lianshu.json`), con creación de personaje estructurada, un grafo de 19 nodos (hitos fijos, corredores acotados, hubs de actividades y resoluciones), conflictos extendidos y progresión por rango con hitos. Su vertical slice recomendado (apertura → corredor → hub → hito con conflicto) es jugable de punta a punta. El resto del grafo ya está cargado como contenido pero todavía no fue ejercitado turno a turno en la UI.

**Mundos iniciales (5, según el GDD):** Isekai, Xianxia (cultivo), Superhéroes, Cyberpunk, Post-apocalíptico. Isekai y Xianxia son mundos distintos — comparten la premisa de "otro mundo" pero no el género. Por ahora solo Xianxia tiene contenido: un mundo freeform simple (`xianxia.json`, el de la prueba de concepto original) y la campaña híbrida de arriba. Los otros 4 mundos siguen siendo diseño, no código.

## Pilares de diseño

1. **Agencia real** — las decisiones cambian el estado del mundo de forma persistente y verificable.
2. **Coherencia sobre espectáculo** — el estado manda; nada de prosa brillante que se contradice.
3. **Costo cero de operación (al inicio)** — jugable con tiers gratuitos de IA.
4. **Presentación que enamora** — tipografía, ritmo, transiciones y ambientación son parte del gameplay.
5. **Motor agnóstico al proveedor de IA** — cambiar de Gemini a Groq no debe tocar la lógica del juego.

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| Cliente | **Flutter** (iOS / Android / web) | Una sola base de código, sensación de app nativa premium, animaciones y theming por mundo de alta calidad. |
| Backend | **Supabase** (Postgres, Auth, Storage, RLS) | Estado relacional + log de turnos inmutable (event-sourced light), tier gratuito, mínima operación. |
| Broker de IA | **Supabase Edge Functions** (Deno/TypeScript) | Guarda las API keys fuera del cliente y orquesta el fallback entre proveedores. |
| Narración | Gemini Flash (principal) → Groq → Cerebras/OpenRouter (fallback) | Structured output nativo, velocidad y cuotas gratuitas complementarias. |
| Imágenes | Pollinations / Cloudflare Workers AI | Generación async de escenas, cacheada en Storage. |

## Arquitectura

Ports & adapters, con el dominio del juego como **código puro Dart** sin dependencias de red ni de proveedor:

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
  narrator/      GeminiNarratorAdapter, GroqNarratorAdapter, FallbackNarratorAdapter
  image/         PollinationsAdapter, CloudflareWorkersAIAdapter
  persistence/   SupabaseGameStateAdapter
  fakes/         FakeNarratorAdapter (tests, sin gastar cuota de IA)
```

Regla de dependencias: **hacia adentro** (`adapters` → `ports` → `core`). El cliente Flutter depende de los puertos, nunca de un adaptador concreto.

## Roadmap

- **Fase 0 — Prueba de concepto** *(completa)*: un mundo (Xianxia), modo freeform, loop mínimo acción → resolución → narración JSON → render, `FakeNarratorAdapter`. Sin auth, sin imágenes.
- **Fase 1 — MVP jugable** *(en curso)*: ✅ narrador real desplegado (`GeminiNarratorAdapter` + `GroqNarratorAdapter` de fallback vía `FallbackNarratorAdapter`, cliente sigue en `FakeNarratorAdapter` por costo mientras se itera UI/UX), ✅ persistencia real en Supabase + Auth anónimo (RLS por sesión), ✅ memoria de tres niveles (diario resumido vía Groq, Edge Function `memory-digest`), ✅ motor del modo híbrido completo (`core/narrative`: hitos fijos, corredores acotados, hubs de actividades, resoluciones; conflictos extendidos; combate por guard; chargen estructurado; progresión por rango con hitos), ✅ una campaña híbrida real cargada (`xianxia_lianshu.json`, "Los nombres que devora el cielo") con su vertical slice jugable de punta a punta, ✅ menú inicial para elegir historia y navegación de vuelta dentro de una partida. Falta: cablear el resto del grafo de esa campaña (finales, epílogo, técnicas por rango), reemplazar el inferidor de atributo por keyword por el clasificador de acción libre ya construido (`ClassifyFreeAction`), persistir la posición dentro del grafo (hoy solo vive en memoria), inventario real.
- **Fase 2 — Contenido y mundos**: los otros 4 mundos (Isekai, Superhéroes, Cyberpunk, Post-apocalíptico) con theming propio, más campañas, generación de imágenes.
- **Fase 3 — Pulido y profundidad**: consistencia de personaje en imágenes, NPCs con memoria, rebobinar partidas, observabilidad.
- **Fase 4 — Distribución**: App Store / Play Store + build web, compartir historias generadas.

Detalle completo de cada fase en el [GDD, §11](GDD-RPG-Narrativo-IA.md#11-roadmap-por-fases).

## Reglas de oro del proyecto

1. El estado manda; la IA solo narra.
2. Las mecánicas se resuelven en código, no en el prompt.
3. Los `state_deltas` que sugiere la IA son propuestas que el motor valida antes de aplicar.
4. Las API keys nunca tocan el cliente.
5. El dominio (`core/`) no depende de infra.
6. Agnóstico al proveedor de IA.
7. Los tiers gratuitos son una restricción de diseño, no un SLA.

Detalle completo en [`CLAUDE.md`](CLAUDE.md).

## Estado del proyecto

🚧 Fase 1 en curso — motor híbrido completo, una historia curada 100% sin IA jugable de punta a punta ("El último tren no espera a los vivos") y una campaña híbrida real jugable en su vertical slice; narrador real desplegado pero el cliente aún juega con `FakeNarratorAdapter`. Proyecto personal, desarrollado con [Claude Code](https://claude.com/claude-code).

## Licencia

Sin licencia definida todavía — todos los derechos reservados por el autor mientras tanto.
