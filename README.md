# Aetherbook

> RPG de narrativa interactiva impulsado por IA — la historia se escribe en tiempo real según tus decisiones.

Aetherbook es un "elige tu propia aventura" evolucionado: un *Game Master* de IA narra sobre un estado de juego que el motor controla de forma **determinista**. La IA nunca decide mecánicas ni inventa stats — solo narra sobre resultados que el código ya resolvió.

📄 El diseño completo está en [`GDD-RPG-Narrativo-IA.md`](GDD-RPG-Narrativo-IA.md). Las reglas operativas para desarrollar con Claude Code están en [`CLAUDE.md`](CLAUDE.md). Toda la narración (prompts y contenido escrito a mano) sigue [`NARRATIVE_VOICE.md`](NARRATIVE_VOICE.md): español neutro con tuteo, nunca voseo rioplatense.

🎮 **Jugalo ya, sin instalar nada:** [aetherbook-rpg.vercel.app](https://aetherbook-rpg.vercel.app) — deployado en Vercel (tier gratuito), redeploya solo con cada push a `master` (`vercel.json`).

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

**Para probarlo en el celular** (el juego es móvil-first), usá el build de release en vez del de arriba:

```powershell
.\tool\run-web-static.ps1
```
```bash
./tool/run-web-static.sh
```

Por qué uno distinto: `run-web.ps1`/`.sh` corren `flutter run -d web-server`, que levanta el servicio de debug de Flutter (DWDS/VM Service) — ese servicio solo acepta conexiones por `localhost`, así que en modo debug la app se queda esperando esa conexión para terminar de arrancar y el celular ve pantalla en blanco. `run-web-static` compila un build de release y lo sirve estático, sin ese servicio de por medio, así que funciona igual desde cualquier dispositivo de la red. La contra: no hay hot-reload, hay que repetir el comando después de cada cambio de código.

Buscá la IP de tu PC en la red local (`ipconfig` → IPv4, algo como `192.168.1.40`) y entrá desde el navegador del teléfono a `http://<esa-ip>:8080`. En iPhone, Safari → *Compartir → Agregar a inicio* para que se sienta como una app. Si aun así ves pantalla en blanco, revisá que el celular esté en la misma red WiFi que la PC (no una red de invitados con "aislamiento de clientes") y que el Firewall de Windows no esté bloqueando la conexión entrante al puerto 8080 de Docker.

Al abrir la app vas a ver un **menú para elegir historia**, agrupado en tres módulos — *historias completas* (sin IA), *historias pre-armadas* (híbridas, con narrador de IA) y **"Creá tu propia historia"** (freeform, ya desbloqueado). Hoy hay dos historias completas/pre-armadas: **"El último tren no espera a los vivos"** (historia completa curada, **sin IA**: 100% preescrita, cero llamadas de red durante la partida, jugable sin conexión una vez cargada) y "Los nombres que devora el cielo" (campaña híbrida, con creación de personaje, narrada por el modelo real). Dentro de una partida, la flecha arriba a la izquierda vuelve al menú sin perder el progreso (la misma sesión sigue en memoria y persistida en Supabase; volver a entrar a la misma historia la retoma donde quedó). El ícono de reiniciar en cada tarjeta abandona esa sesión y empieza una limpia.

**"Creá tu propia historia"** (Fase 2) es distinto a los otros dos módulos: no son historias con nombre propio, son **5 géneros** para elegir — Isekai, Xianxia, Superhéroes, Cyberpunk y Post-apocalíptico (`assets/worlds/{isekai,xianxia,superheroes,cyberpunk,postapoc}.json`). Elegís un género, armás tu personaje con el chargen propio de ese mundo (orígenes y juramento con su propio vocabulario de atributos por género — nunca el mismo formulario repetido), y desde ahí la IA narra en tiempo real, sin guion previo. A diferencia de los otros módulos, acá **podés tener varias historias guardadas a la vez** — el género es el template compartido, cada historia creada es tuya — y se ven/retoman desde la sección "Tus historias" dentro del mismo módulo, con opción de abandonar la que ya no quieras seguir.

El cliente usa el narrador real ([lib/main.dart](lib/main.dart)): `HttpNarratorAdapter` llama a la Edge Function desplegada (Gemini → Groq de fallback), y `HttpMemoryDigestAdapter` hace lo mismo para el diario resumido. Jugar "Los nombres que devora el cielo" gasta cuota real de esos proveedores (gratuita, pero real). "El último tren..." no — su motor nunca invoca al narrador (`ai_runtime_required: false`), así que esa historia sigue siendo 100% gratis y funciona sin conexión. Los tests nunca gastan cuota: corren contra `FakeNarratorAdapter`/`FakeMemoryDigestAdapter` (JSON fijo, sin red), nunca contra el narrador real.

### Cuentas: de anónimo a permanente

Al abrir la app por primera vez, Supabase te firma como usuario **anónimo** en silencio — nunca hace falta crear cuenta para jugar. Esa identidad vive en el `localStorage` del navegador, así que es *por origen*: `localhost:8080` y la IP de tu PC son dos usuarios distintos, y cada navegador/dispositivo que uses arranca con su propio progreso.

Para llevar el progreso entre dispositivos, "Guardar tu progreso con tu email" (botón en la pantalla de inicio, `lib/app/account_screen.dart`) **vincula** un email a la cuenta anónima actual sin cambiar su identidad (`AuthPort.continueWithEmail` → `SupabaseAuthAdapter`, usando `updateUser` de Supabase) — todo lo ya jugado se conserva. Si ese email ya estaba vinculado desde otro dispositivo, en cambio manda un enlace para entrar a esa cuenta existente. Ninguno de los dos casos cambia nada hasta que se abre el enlace del correo.

Configurado en [Authentication → URL Configuration](https://supabase.com/dashboard/project/hsgdldztcolteyodiscu/auth/url-configuration) del proyecto: Site URL `https://aetherbook-rpg.vercel.app` y `https://aetherbook-rpg.vercel.app/**` en Redirect URLs (ese campo sí admite wildcards; el de Site URL no). Para probar el flujo desde `localhost` en vez de producción, agregá también `http://localhost:8080/**` a Redirect URLs — sin la URL en esa allow-list, Supabase manda el correo igual pero el enlace no vuelve a la app.

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

El modo 3 (híbrido) tiene **"Los nombres que devora el cielo"** (`assets/worlds/xianxia_lianshu.json`), con creación de personaje estructurada, un grafo de 19 nodos (hitos fijos, corredores acotados, hubs de actividades y resoluciones), conflictos extendidos y progresión por rango con hitos. Se narra con el modelo real (Gemini/Groq), no con JSON fijo, y la posición en el grafo se guarda en Supabase, así que sobrevive cerrar la app. Es jugable de punta a punta: el clímax resuelve uno de sus 5 finales + fuga anticipada (chequeo contra la dificultad del final, con fallback de fracaso y técnica final otorgada) y desemboca en un epílogo que reacciona a lo que pasó en la partida.

**Mundos iniciales (5, según el GDD):** Isekai, Xianxia (cultivo), Superhéroes, Cyberpunk, Post-apocalíptico. Isekai y Xianxia son mundos distintos — comparten la premisa de "otro mundo" pero no el género. Los 5 ya tienen contenido (Fase 2, `assets/worlds/{isekai,xianxia,superheroes,cyberpunk,postapoc}.json`): cada uno es un mundo freeform con su propio chargen (orígenes + juramento, vocabulario de atributos propio) jugable desde "Creá tu propia historia" en el menú. `xianxia_lianshu.json` (la campaña híbrida) sigue siendo aparte — mismo género, contenido curado con grafo de nodos en vez de freeform.

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
| Narración | Gemini Flash (principal) → Groq (fallback real) | Structured output nativo, velocidad y cuotas gratuitas complementarias. Cerebras/OpenRouter quedan como fallback futuro, no implementados. |
| Imágenes | Pollinations.ai, vía Edge Function `generate-image` | Generación async de escenas, cacheada por SHA-256 del prompt en Storage. Cloudflare Workers AI queda como alternativa futura. |

## Arquitectura

Ports & adapters, con el dominio del juego como **código puro Dart** sin dependencias de red ni de proveedor:

```
core/            Dart puro, sin infra
  engine/        ResolvePlayerAction, EXP, chequeos, costos
  narrative/     grafo de nodos, evaluación de gates
  state/         agregados: character, world, session

ports/           interfaces (contratos), lib/ports/
  NarratorPort
  MemoryDigestPort
  ImageGeneratorPort
  GameStateRepositoryPort
  WorldRepositoryPort
  AuthPort

adapters/        lib/adapters/, salvo donde se aclara
  narrator/      HttpNarratorAdapter (cliente Dart, real) — llama a la Edge Function,
                 que por dentro orquesta GeminiNarratorAdapter -> GroqNarratorAdapter
                 (FallbackNarratorAdapter) en supabase/functions/narrator/ (Deno/TS)
  memory/        HttpMemoryDigestAdapter (cliente Dart, real) -> Edge Function memory-digest/
  image/         HttpImageGeneratorAdapter (cliente Dart, real) -> Edge Function
                 generate-image/ (Pollinations.ai, cachea en Storage por hash del prompt)
  content/       AssetWorldRepository — lee assets/worlds/*.json
  persistence/   SupabaseGameStateAdapter
  auth/          SupabaseAuthAdapter
  fakes/         FakeNarratorAdapter, FakeMemoryDigestAdapter, FakeImageGeneratorAdapter,
                 FakeAuthAdapter (tests, sin gastar cuota de IA ni tocar red)
```

Regla de dependencias: **hacia adentro** (`adapters` → `ports` → `core`). El cliente Flutter depende de los puertos, nunca de un adaptador concreto.

## Roadmap

- **Fase 0 — Prueba de concepto** *(completa)*: un mundo (Xianxia), modo freeform, loop mínimo acción → resolución → narración JSON → render, `FakeNarratorAdapter`. Sin auth, sin imágenes.
- **Fase 1 — MVP jugable** *(completa)*: ✅ narrador real conectado al cliente (`HttpNarratorAdapter` -> Edge Function -> Gemini con fallback a Groq vía `FallbackNarratorAdapter`), ✅ memoria de tres niveles conectada (`HttpMemoryDigestAdapter` -> Edge Function `memory-digest` vía Groq), ✅ persistencia real en Supabase + Auth anónimo (RLS por sesión), ✅ posición en el grafo persistida (nodo actual, turnos de corredor, progreso de conflicto extendido — sobrevive un refresh), ✅ motor del modo híbrido completo (`core/narrative`: hitos fijos, corredores acotados, hubs de actividades, resoluciones; conflictos extendidos; combate por guard; chargen estructurado; progresión por rango con hitos), ✅ resolución de finales y epílogo (`GameController.availableEndings`/`chooseEnding`: chequeo contra la dificultad del final, fallback de fracaso, técnica final otorgada, epílogo ensamblado por `assembleEpilogueBeats`), ✅ una campaña híbrida real cargada (`xianxia_lianshu.json`, "Los nombres que devora el cielo") jugable de punta a punta, ya narrada por el modelo real, ✅ una historia curada 100% sin IA completa (`curated_zombie_01_ultimo_tren.json`, "El último tren no espera a los vivos"), ✅ menú de historias en 3 módulos con reinicio de partida, ✅ estado terminal explícito ("Fin de la historia") al llegar al epílogo de cualquiera de las dos campañas, ✅ `ClassifyFreeAction` reemplazando al inferidor por keyword en la acción libre, ✅ inventario real (`ItemDefinition` declarativo por mundo, `InventoryScreen` accesible desde el ícono en la barra de estado), ✅ generación de imágenes por turno (`generate-image` vía Pollinations.ai, cacheada por hash del prompt en Storage, nunca bloquea ni rompe la narración si falla), ✅ narrador reescrito en español neutro con tuteo (nunca voseo rioplatense) en todo el contenido y prompts, con [`NARRATIVE_VOICE.md`](NARRATIVE_VOICE.md) como guía de estilo durable.
- **Fase 2 — Contenido y mundos** *(en progreso)*: ✅ los 5 mundos freeform (Isekai, Xianxia, Superhéroes, Cyberpunk, Post-apocalíptico genérico — distinto de la historia curada zombi de fase 1) con chargen y theming propios, jugables desde "Creá tu propia historia". Falta: 2-3 campañas pre-armadas/híbridas más allá de las dos actuales.
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

✅ Fase 1 completa — motor híbrido completo con resolución de finales y epílogo, una historia curada 100% sin IA jugable de punta a punta ("El último tren no espera a los vivos") y una campaña híbrida real jugable de punta a punta ("Los nombres que devora el cielo"), ambas narradas/persistidas con los servicios reales, con acción libre clasificada en motor (`ClassifyFreeAction`), inventario real con pantalla propia, generación de imágenes por turno y narración en español neutro (tuteo) en todo el contenido. En curso Fase 2: ya jugables los 5 géneros freeform ("Creá tu propia historia"); quedan más campañas pre-armadas. Proyecto personal, desarrollado con [Claude Code](https://claude.com/claude-code).

## Licencia

Sin licencia definida todavía — todos los derechos reservados por el autor mientras tanto.
