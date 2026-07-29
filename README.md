# Aetherbook

> RPG de narrativa interactiva impulsado por IA — la historia se escribe en tiempo real según tus decisiones.

Aetherbook es un "elige tu propia aventura" evolucionado: un *Game Master* de IA narra sobre un estado de juego que el motor controla de forma **determinista**. La IA nunca decide mecánicas, calcula daño ni inventa ítems — solo narra sobre resultados que el código ya resolvió. Eso elimina el problema clásico de los "juegos con IA": que el modelo se olvide de algo, rompa una regla o contradiga lo que ya pasó.

📄 El diseño completo está en [`GDD-RPG-Narrativo-IA.md`](GDD-RPG-Narrativo-IA.md). Las reglas operativas para desarrollar con Claude Code están en [`CLAUDE.md`](CLAUDE.md). Toda la narración (prompts y contenido escrito a mano) sigue [`NARRATIVE_VOICE.md`](NARRATIVE_VOICE.md): español neutro con tuteo, nunca voseo rioplatense.

🎮 **Jugalo ya, sin instalar nada:** [aetherbook-rpg.vercel.app](https://aetherbook-rpg.vercel.app)

---

## Qué propone

La mayoría de los "juegos con IA" son un chat sin memoria ni reglas propias. Aetherbook separa el problema en dos capas que nunca se mezclan:

- **Estado del juego** (determinista, en Postgres): stats, inventario, flags de trama, relaciones, ubicación en la historia. Vive en el servidor, se valida en código, y es la única fuente de verdad.
- **Narración** (IA): recibe el estado y el resultado mecánico ya calculado, y solo lo viste con prosa. Nunca tira dados, nunca decide si algo tuvo éxito, nunca inventa una consecuencia mecánica por su cuenta.

Sobre esa base, tres formas distintas de jugar conviven en el mismo motor:

1. **Aventura libre** — elegís un género, armás tu personaje y la IA narra la historia turno a turno, sin guion previo.
2. **Historia completa** — una campaña escrita a mano de punta a punta, sin IA en absoluto: cada escena, cada tirada y cada final está preescrito. Se juega sin conexión una vez cargada.
3. **Historia híbrida** — un esqueleto de hitos fijos (escritos a mano, con final garantizado) relleno turno a turno por un narrador de IA real. La coherencia de una historia curada, con la libertad de una generada.

## Qué incluye hoy

**Cinco mundos para jugar libremente** — Isekai, Xianxia, Superhéroes, Cyberpunk y Post-apocalíptico, cada uno con su propio chargen (orígenes, juramento, vocabulario de atributos propio: nunca el mismo formulario repetido entre géneros). Podés tener varias historias abiertas a la vez por género — cada una es tuya, se listan y retoman desde "Tus historias".

**Historias completas y campañas híbridas ya escritas** — dos historias completas 100% curadas y sin IA ("El último tren no espera a los vivos", thriller post-apocalíptico zombi; "Treinta y seis horas antes del apagón violeta", thriller criminal cyberpunk) y una campaña híbrida real narrada por el modelo ("Los nombres que devora el cielo", xianxia), con chargen propio, conflictos extendidos, combate por guardia y múltiples finales que desembocan en un epílogo que reacciona a lo que hiciste.

**Memoria de tres niveles** — los últimos turnos viajan literales en el prompt, un diario resumido se regenera cada pocos turnos, y todo lo que no puede perderse vive en tablas de Postgres. El modelo nunca ve el historial completo de la partida.

**Generación de imágenes por escena** — cada turno narrado por IA dispara, en paralelo, la generación de una ilustración de la escena (cacheada por hash del prompt, así el mismo prompt nunca vuelve a pedirle nada al proveedor). Nunca bloquea ni rompe la narración si falla.

**Cuentas sin fricción** — arrancás como usuario anónimo, sin crear cuenta, y podés vincular un email después para llevar el progreso entre dispositivos sin perder nada de lo ya jugado.

**Escribí tu propia historia** — desde "Escribir", cualquier cuenta puede armar su propia campaña híbrida dentro de la app: un editor de mapa de nodos (escenas fijas, tramos libres, hubs de actividades, finales con su propia dificultad), una checklist de prepublicación que detecta referencias colgantes o nodos inalcanzables, un modo de prueba con dado forzable para recorrer cualquier rama sin depender del azar, y un flujo de publicación con aviso de derechos. Una vez publicada, aparece en **Explorar** para que cualquiera la juegue — como una novela de comunidad.

**Panel de administración** — un grupo reducido de cuentas puede además construir historias oficiales completas o híbridas con un sistema de atributos, recursos y tema visual propio desde cero (sin partir de un mundo existente), y revisar o editar cualquier campaña oficial ya publicada, la haya escrito quien la haya escrito. Una campaña oficial publicada aparece en el catálogo real ("Historias completas"/"Historias pre-armadas"), no solo en Explorar.

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

El cliente usa el narrador real ([lib/main.dart](lib/main.dart)): `HttpNarratorAdapter` llama a la Edge Function desplegada (Gemini → Groq de fallback), y `HttpMemoryDigestAdapter` hace lo mismo para el diario resumido. Jugar una historia híbrida o freeform gasta cuota real de esos proveedores (gratuita, pero real). Las historias completas no — su motor nunca invoca al narrador (`ai_runtime_required: false`), así que siguen siendo 100% gratis y funcionan sin conexión. Los tests nunca gastan cuota: corren contra `FakeNarratorAdapter`/`FakeMemoryDigestAdapter` (JSON fijo, sin red), nunca contra el narrador real.

### Cuentas: de anónimo a permanente

Al abrir la app por primera vez, Supabase te firma como usuario **anónimo** en silencio — nunca hace falta crear cuenta para jugar. Esa identidad vive en el `localStorage` del navegador, así que es *por origen*: `localhost:8080` y la IP de tu PC son dos usuarios distintos, y cada navegador/dispositivo que uses arranca con su propio progreso.

Para llevar el progreso entre dispositivos, "Guardar tu progreso con tu email" (botón en la pantalla de inicio, `lib/app/account_screen.dart`) **vincula** un email a la cuenta anónima actual sin cambiar su identidad (`AuthPort.continueWithEmail` → `SupabaseAuthAdapter`, usando `updateUser` de Supabase) — todo lo ya jugado se conserva. Si ese email ya estaba vinculado desde otro dispositivo, en cambio manda un enlace para entrar a esa cuenta existente. Ninguno de los dos casos cambia nada hasta que se abre el enlace del correo.

Configurado en [Authentication → URL Configuration](https://supabase.com/dashboard/project/hsgdldztcolteyodiscu/auth/url-configuration) del proyecto: Site URL `https://aetherbook-rpg.vercel.app` y `https://aetherbook-rpg.vercel.app/**` en Redirect URLs (ese campo sí admite wildcards; el de Site URL no). Para probar el flujo desde `localhost` en vez de producción, agregá también `http://localhost:8080/**` a Redirect URLs — sin la URL en esa allow-list, Supabase manda el correo igual pero el enlace no vuelve a la app.

### Correr los tests

```powershell
# Dominio + UI (Dart/Flutter)
.\tool\flutter.ps1 test
.\tool\flutter.ps1 analyze

# Edge Functions (Deno/TypeScript)
.\tool\deno.ps1 test --allow-net --allow-env supabase/functions/narrator/
.\tool\deno.ps1 test --allow-net --allow-env supabase/functions/memory-digest/
.\tool\deno.ps1 test --allow-net --allow-env supabase/functions/generate-image/
.\tool\deno.ps1 lint supabase/functions/narrator/
```

En Git Bash / Linux / macOS, usá los equivalentes `.sh`: `./tool/flutter.sh test`, `./tool/deno.sh test --allow-net --allow-env supabase/functions/narrator/`.

Ningún test toca red real ni gasta cuota de IA: todo corre contra fakes/mocks (`FakeNarratorAdapter` en Dart, `fetch` mockeado en los tests de Deno).

---

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| Cliente | **Flutter** (iOS / Android / web) | Una sola base de código, sensación de app nativa premium, animaciones y theming por mundo de alta calidad. |
| Backend | **Supabase** (Postgres, Auth, Storage, RLS) | Estado relacional + log de turnos inmutable (event-sourced light), tier gratuito, mínima operación. |
| Broker de IA | **Supabase Edge Functions** (Deno/TypeScript) | Guarda las API keys fuera del cliente y orquesta el fallback entre proveedores. |
| Narración | Gemini Flash (principal) → Groq (fallback real) | Structured output nativo, velocidad y cuotas gratuitas complementarias. |
| Imágenes | Pollinations.ai, vía Edge Function `generate-image` | Generación async de escenas, cacheada por SHA-256 del prompt en Storage. |

## Arquitectura

Ports & adapters, con el dominio del juego como **código puro Dart** sin dependencias de red ni de proveedor:

```
core/            Dart puro, sin infra
  engine/        ResolvePlayerAction, EXP, chequeos, costos
  narrative/     grafo de nodos, evaluación de gates
  state/         agregados: character, world, session
  authoring/     ediciones de grafo, checklist de prepublicación, materialización de mundos oficiales

ports/           interfaces (contratos), lib/ports/
  NarratorPort
  MemoryDigestPort
  ImageGeneratorPort
  GameStateRepositoryPort
  WorldRepositoryPort
  CampaignDraftRepositoryPort
  AuthPort

adapters/        lib/adapters/, salvo donde se aclara
  narrator/      HttpNarratorAdapter (cliente Dart, real) — llama a la Edge Function,
                 que por dentro orquesta GeminiNarratorAdapter -> GroqNarratorAdapter
                 (FallbackNarratorAdapter) en supabase/functions/narrator/ (Deno/TS)
  memory/        HttpMemoryDigestAdapter (cliente Dart, real) -> Edge Function memory-digest/
  image/         HttpImageGeneratorAdapter (cliente Dart, real) -> Edge Function
                 generate-image/ (Pollinations.ai, cachea en Storage por hash del prompt)
  content/       AssetWorldRepository (assets/worlds/*.json) + CompositeWorldRepository
                 (cae a una campaña oficial publicada en Supabase si el slug no es un asset)
  persistence/   SupabaseGameStateAdapter, SupabaseCampaignDraftAdapter
  auth/          SupabaseAuthAdapter
  fakes/         FakeNarratorAdapter, FakeMemoryDigestAdapter, FakeImageGeneratorAdapter,
                 FakeAuthAdapter (tests, sin gastar cuota de IA ni tocar red)

app/editor/      lib/app/editor/ — el editor de campañas en la app: mapa de nodos,
                 editores por tipo de nodo, checklist, modo de prueba, World Builder
```

Regla de dependencias: **hacia adentro** (`adapters` → `ports` → `core`). El cliente Flutter depende de los puertos, nunca de un adaptador concreto.

## Pilares de diseño

1. **Agencia real** — las decisiones cambian el estado del mundo de forma persistente y verificable.
2. **Coherencia sobre espectáculo** — el estado manda; nada de prosa brillante que se contradice.
3. **Costo cero de operación (al inicio)** — jugable con tiers gratuitos de IA.
4. **Presentación que enamora** — tipografía, ritmo, transiciones y ambientación son parte del gameplay.
5. **Motor agnóstico al proveedor de IA** — cambiar de Gemini a Groq no debe tocar la lógica del juego.

## Reglas de oro del proyecto

1. El estado manda; la IA solo narra.
2. Las mecánicas se resuelven en código, no en el prompt.
3. Los `state_deltas` que sugiere la IA son propuestas que el motor valida antes de aplicar.
4. Las API keys nunca tocan el cliente.
5. El dominio (`core/`) no depende de infra.
6. Agnóstico al proveedor de IA.
7. Los tiers gratuitos son una restricción de diseño, no un SLA.

Detalle completo en [`CLAUDE.md`](CLAUDE.md).

## Licencia

Sin licencia definida todavía — todos los derechos reservados por el autor mientras tanto.
