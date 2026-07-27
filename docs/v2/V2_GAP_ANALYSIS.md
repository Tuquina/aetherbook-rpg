# V2 Gap Analysis

Created 2026-07-27 from a full repository audit (4 parallel research passes over
`lib/app`, `lib/core`+`lib/ports`+`lib/adapters`, content/docs, and
`supabase`+`test`+repo hygiene) plus a full read-through of the V2 design
prototype (`Aetherbook Redesign.dc.html`, 41 annotated subsections `1a`–`10d`).

This is the reference snapshot — update it as stages ship and gaps close.
Do not re-derive this from scratch in a future session; read this first.

---

## 1. Methodology

- Design source of truth: `Aetherbook Redesign.dc.html` inside the Claude
  Design handoff bundle (`G:\Documentos Fernando\Claude Code\Designs\Aetherbook
  Mobile Redesign-handoff.zip`), per its own bundled `README.md` instruction —
  **not** the top-level `Aetherbook Redesign.html`, which is a compiled/bundled
  rendering of the same content and isn't independently readable as markup.
- The design tool's own `github.md` sync log confirms it already read the real
  repo (`splash_screen.dart`, `AuthPort`, `StoryGraph`, `game_screen.dart`,
  `status_bar.dart`, `choice_button.dart`, `fate_roll.dart`) before drawing
  anything, and ships a screen-map table pointing each mockup section at the
  real file it's meant to replace — meaningfully lowering translation risk.
- Current-state facts below are sourced from direct code reads (this session),
  not from CLAUDE.md/GDD/README's own descriptions of themselves — several
  discrepancies were found between what those docs claim and what the code
  actually does (noted inline below).

---

## 2. Current architecture map (reference)

```
lib/app/                — screens: splash, world_select, story_module,
                          create_story, chargen, game_screen, codex, account,
                          inventory + game_controller.dart (ChangeNotifier)
lib/app/design/         — tokens.dart (AetherColors/Space/Radius/Motion/Shadow),
                          typography.dart (AetherType — Georgia+system sans,
                          explicitly flagged as placeholder in its own comment)
lib/app/widgets/        — status_bar, choice_button, fate_roll, atmosphere
lib/core/               — pure Dart, enforced by test/architecture/core_purity_test.dart
  state/                — Character, GameSession, Turn, GameSessionSummary
  engine/                — ResolvePlayerAction, ExpProgression, RankProgression,
                          ClassifyFreeAction, StateDelta/ApplyStateDeltas,
                          ResolveStoryChoice
  narrative/             — StoryGraph, StoryNode (4 sealed subtypes), StoryChoice,
                          Gate (12 concrete types), Ending, HubActivity, EpilogueBeat
  world/                 — World.fromJson (canonical content-schema authority)
lib/ports/               — NarratorPort, MemoryDigestPort, ImageGeneratorPort,
                          GameStateRepositoryPort, WorldRepositoryPort, AuthPort
lib/adapters/            — narrator/, memory/, image/, persistence/, content/, auth/
                          (fakes live beside real adapters, not in a separate
                          folder — CLAUDE.md §4 describes an `adapters/fakes/`
                          that does not actually exist)
supabase/migrations/     — 7 files, all additive (grep confirms no DROP anywhere)
supabase/functions/      — narrator/ (Gemini→Groq fallback), memory-digest/ (Groq
                          only), generate-image/ (Pollinations + SHA-256 cache)
assets/worlds/*.json     — 8 files: 1 hybrid, 2 curated (ai_runtime_required:false),
                          5 freeform genres
test/                    — 62 files; core_purity_test.dart enforces the core/
                          import boundary; NO golden tests exist; widget tests
                          exist (4 files) but resume was only tested at the
                          GameController level until this audit's Stage 0 fix
tool/                    — Docker wrappers only; no local Flutter/Deno SDK
                          (ghcr.io/cirruslabs/flutter:stable, denoland/deno:latest)
```

**No CI** — `.github/` does not exist. All test/analyze runs are manual via `tool/`.

---

## 3. V2 feature inventory (every prototype subsection)

| # | Feature | Current equivalent | Status |
|---|---|---|---|
| 1a | Two-state collapsible header (ceremonial → 52px on scroll) | `StatusBar`, fixed/always-expanded | **New** — screen-layout |
| 1a | Numbered (roman-numeral) choice cards | `ChoiceButton`, plain rows | **New** — reusable-widget |
| 1a | Bottom sheets: character sheet / inventory / story-menu | Inventory + Codex are pushed `MaterialPageRoute`s; no dedicated character-sheet screen exists | **New** — screen-layout + navigation |
| 1a | Free-text action field | `FreeActionField` | **Exists** — restyle only |
| 1a | Progressive choice disclosure ("keep reading" gate) | `_choicesRevealed`/`_KeepReadingHint` in `game_screen.dart` | **Exists and correct** — do not re-design the mechanic, only its visuals |
| 1b | Loading state: image shimmer + text-line skeleton + "keep reading previous turn" hint | `DestinyWriting` (3-dot pulse only) | **New** — presentation-state |
| 1b | Error state: retry / choose-again / attempt counter ("Intento 2 de 3") | Bare `error` string; `FallbackNarratorAdapter`'s attempt count is tracked internally but never returned in the Edge Function response | **New** — presentation-state + narrator-contract (small additive field) |
| 1b | Ending screen: "Final descubierto · 1 de 5", stat cards, vow-fulfillment line | No ending-count concept surfaced; `ResolutionNode.endings.length` already available | **Mostly free** — just plumbing, no new mechanic |
| 1c | Web/tablet: fixed scene left, tome right | `_ReadingFrame` (closest existing analog, frames content >720px) | **Partial** — restyle + reflow |
| 2a–2d | Home / "Mis historias" / 3-step chargen / Codex link | `WorldSelectScreen`/`CreateStoryScreen`/`ChargenScreen`/`CodexScreen` | **Exists** — screen-layout only |
| 3a–3d | Codex as its own screen, mode-partitioned | `CodexScreen` exists but is one flat list | **Partial** — restructure, not rebuild |
| 4a–4d | 5 per-world visual token sets (accent/base/secondary/texture/title-treatment) | Does not exist; only 3 per-*module* accents exist (ember/arcane/nova) | **New** — content-schema + visual-token (Decision E) |
| 5a–5b | Web library grid (1280px) + 2-column chargen | Mobile-only layouts | **New** — screen-layout |
| 6a | Profile = reading history (worlds played, vows kept) | No aggregate cross-session view exists (`listActiveSessions` is scoped to explicit slugs, not "everything") | **New** — screen-layout + persistence (new aggregate query) |
| 6b | Settings grouped by reading effect | Doesn't exist (`AccountScreen` only handles email-link) | **New** — screen-layout |
| 6c–6e | 3-step onboarding | Doesn't exist | **New** — screen-layout, local-only, no domain impact |
| 7a–7c | Brand symbol (d20 + open-page "A"), app icon/favicon, marketing collateral | `SplashScreen._TomePainter` is the only existing brand mark | **New** — visual-token + repository-hygiene (icon assets) |
| 8a–8b | Web (1280px) / tablet (834px) home | Same gap as 5a-5b | **New** — screen-layout |
| 9a–9j | Visual story-graph editor (web+mobile), pre-publish lint, live playtest | Does not exist as UI; underlying domain model (`Gate`, `Ending.difficultyBySoftRequirementsMet`, 4 `StoryNode` subtypes, `StoryGraph.unknownTargetIds()`) already sufficient | **New application surface** (Decision A) — not a domain-mechanic gap |
| 10a | Splash: tome→d20-symbol, Georgia→Marcellus, +3 explanatory lines | `splash_screen.dart` structure unchanged, assets swap | **Partial** — visual-token + screen-layout |
| 10b/10d | Google OAuth + email/password, forgot-password, "account already exists" merge warning | `AuthPort.continueWithEmail` is magic-link only — confirmed no OAuth/password support exists | **New** — domain-mechanic, port contract (Decision D) |
| 10c | Rights notice at publish time | Does not exist in any form; implies a publish/library feature with no current data model | **Out of scope for V2** pending Decision B |
| (mock data) | Player-selectable narrative tone (épico/íntimo/ácido) | `tone` is 100% AI-emitted, display-only, confirmed zero mechanical effect, not even reliably persisted (`Turn.tone` hardcoded to `''` on resume) | **Product decision required** (Decision C) |

---

## 4. Gap matrix

| Area | V1 current | V2 intended | Gap | Change type | Files/layers | Risk | Recommendation |
|---|---|---|---|---|---|---|---|
| Color palette | Gold/ink/parchment + module accents | Same palette (prototype reuses exact hex values, including `nova`) | None of substance | visual-token | `design/tokens.dart` | low | Keep as-is |
| Typography | Georgia (system) + system sans, explicitly flagged placeholder | Marcellus (display) + Spectral (narration) + Archivo (chrome) | Real font bundling | visual-token | `typography.dart`, `pubspec.yaml`, `assets/fonts/` | low | Stage 1 |
| Choice reveal | Hidden until scroll-bottom ("Ver opciones") | Same mechanic, numbered cards | Visual only | reusable-widget | `choice_button.dart` | low | Stage 4 |
| Destructive confirmation | 4 `AlertDialog` sites (abandon/restart/story-choice/ending) | Same guarantee, sheet-styled with consequence text | Visual only — **do not weaken the confirm-before-destroy guarantee** | reusable-widget | shared `ConfirmSheet` widget | low | Stage 1 (component) + 2/4/5 (call sites) |
| EXP/level display | Animated bar + rank pill, fixed `StatusBar` | Same data, inside collapsible header | Layout only | screen-layout | `status_bar.dart`, `game_screen.dart` | low-med (scroll-linked animation) | Stage 4 |
| Character sheet | Inline in `StatusBar` only, no dedicated screen | Bottom sheet (stats/resources/vow/status) | New surface, all fields already exist on `Character` | screen-layout | new `CharacterSheetSheet` | low | Stage 5 |
| Inventory | Pushed route (`InventoryScreen`) | Bottom sheet, same content | Navigation only | navigation | `inventory_screen.dart` | low | Stage 5 |
| Per-world theming | Single global theme + 3 module accents only | 5 world-family token sets | New `World` fields + resolver | content-schema + visual-token | `world.dart`, all 8 world JSON, `tokens.dart`, `theme.dart` | medium | Decision E confirmed → Stage 6b |
| Story tone | AI-emitted, zero mechanical effect, unreliably persisted | Player-selected, narrator-affecting | New field, chargen step, prompt instruction, authored copy | domain-mechanic + narrator-contract + content-schema | `chargen_screen.dart`, `character.dart`, `prompt_builder.ts`, world JSON | medium | Decision C → Stage 6c (or just display, near-free) |
| Auth | Anonymous + email magic-link only | + Google OAuth + password + reset | New port methods, provider config, new UI | domain-mechanic (port) | `auth_port.dart`, `supabase_auth_adapter.dart`, `account_screen.dart` | medium | Decision D → Stage 6d |
| Publishing/UGC library | Does not exist | Rights notice + shared library | Entirely new: tables, RLS, moderation, legal | persistence + everything | new migrations, new RLS, new screens | **very high** | Decision B → defer |
| Story-graph editor | Does not exist; content is hand JSON | Visual editor (web+mobile), lint, playtest | New surface; domain model already sufficient | new surface, not domain-mechanic | new `lib/app/editor/` or separate tool | medium-high (scope), low (domain risk) | Decision A → own initiative |
| Ending discovery counter | Not surfaced | "Final descubierto · 1 de 5" | Just a getter + UI | presentation-state | `game_controller.dart`, `game_screen.dart` | low | Good early Stage-6 slice |
| Narrator failure visibility | Generic error, no retry count | Retry/choose-again + attempt counter | Edge Function needs to return attempt metadata | narrator-contract | `supabase/functions/narrator/types.ts`, `index.ts`, `game_controller.dart` | low-medium | Stage 7 |
| Session resume (navigation) | Fully correct at controller level (30+ tests); no navigation-level test existed | Same, presented via new UI | **Closed by Stage 0** — `test/app/story_resume_navigation_test.dart` added 2026-07-27 | testing | new test file | — | Done |
| Legacy tables | `inventory_items`, `relationships` created in first migration, never dropped, confirmed unused | N/A | Dead schema | repository-hygiene | supabase migrations | low | Flag only, not part of V2 UI work |

---

## 5. Features already implemented (do not rebuild)

- Progressive choice disclosure after reading (`game_screen.dart`)
- EXP/level visibility (`StatusBar` animated bar + rank pill + `LevelUpBanner`)
- User-defined story titles for freeform sessions (`GameSessionSummary.title`,
  `_SavedStoryCard._displayTitle`)
- Destructive-action confirmation dialogs (4 call sites)
- Multi-session freeform support (`listActiveSessions`/`loadSession`/
  `alwaysCreateNew`) — this is the mechanism Stage 0's new test exercises

## 6. Features requiring content-schema changes

- Per-world visual theming (Decision E)
- Per-tone preview copy, only if Decision C(1) is accepted

## 7. Features requiring narrator-contract changes

- Narrator retry-count surfaced to the player (Stage 7, no decision needed —
  purely additive)
- Player-selected tone shaping the prompt (only if Decision C(1) accepted)

## 8. Features explicitly out of scope for V2 (pending decisions)

- Publishing / UGC library (Decision B — recommend rejecting)
- Visual story-graph editor (Decision A — recommend deferring as separate initiative)

## 9. Repository hygiene findings (carried over from the audit)

- `.claude/launch.json` is tracked and contains a hardcoded Windows-specific
  absolute path in a Docker volume-mount arg. Not a secret; will need editing
  on any other machine/OS. Flagged only.
- `inventory_items`/`relationships` tables exist in schema, confirmed unused,
  never dropped by any migration. Safe to clean up later; unrelated to V2 UI work.
- No CI exists (`.github/` absent).
- Otherwise clean: `.gitignore` correct, no untracked build artifacts, no
  secrets, no `.env*` files found.
- Never commit the design bundle (`.html`/`.dc.html`/handoff zip/reference
  PNGs) into this repo — it's a design reference, not application code.

---

## Revision log

- **2026-07-27** — initial audit and this document created. Stage 0 executed
  (baseline `flutter analyze`/`flutter test` recorded, navigation-resume
  widget test added). See `V2_IMPLEMENTATION_PLAN.md` for stage status.
