# V2 Implementation Plan

Created 2026-07-27. Companion to `V2_PRODUCT_DECISIONS.md` (decisions that
block specific stages) and `V2_GAP_ANALYSIS.md` (the full feature/gap
inventory this plan executes against). Read all three before starting any
stage — do not re-derive the audit from scratch in a future session.

**Rule for every stage:** leave the repo compilable, testable, playable, and
documented. Never bundle a visual-only stage with a domain-mechanic stage.
Never touch a file not listed under that stage without calling it out
explicitly first.

**Verification commands** (every stage, minimum bar):
```bash
./tool/flutter.sh analyze
./tool/flutter.sh test
```
PowerShell equivalents: `.\tool\flutter.ps1 analyze`, `.\tool\flutter.ps1 test`.
If a stage touches an Edge Function, also run the matching:
```bash
./tool/deno.sh test --allow-net --allow-env supabase/functions/narrator/
./tool/deno.sh test --allow-net --allow-env supabase/functions/memory-digest/
./tool/deno.sh test --allow-net --allow-env supabase/functions/generate-image/
```

---

## Stage 0 — Baseline and safeguards — ✅ DONE (2026-07-27)

**Goal:** freeze a known-good reference point; no product behavior changes.

**What was done:**
- Baseline `./tool/flutter.sh analyze` → **No issues found.**
- Baseline `./tool/flutter.sh test` → **580/580 tests passed** (one pre-existing,
  non-fatal hit-test warning in `test/vertical_slice_test.dart`, unrelated to
  this work, not a failure).
- Added `test/app/story_resume_navigation_test.dart` — closes the one confirmed
  test gap from the audit: resume behavior was previously only tested at the
  `GameController` API level (`test/app/game_controller_persistence_test.dart`,
  the `"sessionId resumes that exact session, not the latest one"` case), never
  through actual screen navigation. The new test drives real taps through
  `WorldSelectScreen` → "Crea tu propia historia" → `CreateStoryScreen` →
  taps a specific saved story card → lands on `GameScreen` — and asserts the
  **exact tapped session** loaded (not whatever `loadLatestSession` would have
  returned, and not a freshly created session).
- Re-ran full suite after adding the test → **581/581 tests passed** (580 + 1
  new), `analyze` still clean.
- Created this `docs/v2/` planning workspace.

**Files touched:** `test/app/story_resume_navigation_test.dart` (new file
only — no other file modified, per instruction).

**Acceptance criteria:** met. Baseline recorded above; new test passes; no
regressions.

---

## Stage 1 — Design-system foundation — ✅ DONE (2026-07-27)

**Goal:** introduce Marcellus/Spectral/Archivo typography and reusable
`ConfirmSheet`/numbered `ChoiceCard` components — built, not yet wired into
every screen.

**Non-goals:** no screen migrations yet (that's Stage 2+); spacing/radii/motion
tokens are already adequate and are **not** being redesigned, only reused.

**What was done:**
- `lib/app/widgets/choice_card.dart` — numbered (Roman-numeral) choice card,
  same press-and-brighten interaction as the existing `ChoiceButton`. Not yet
  wired into `game_screen.dart` (that's Stage 4).
- `lib/app/widgets/confirm_sheet.dart` — `showConfirmSheet(...)`, a bottom-sheet
  destructive-confirmation replacing `showDialog`/`AlertDialog`. Not yet wired
  into any of the app's 4 existing confirmation call sites (that's Stage 2/4/5,
  done call-site by call-site).
- Vendored `assets/fonts/Marcellus-Regular.ttf`, `Spectral-Regular.ttf`,
  `Spectral-Italic.ttf` (Google Fonts, OFL license, downloaded from
  `github.com/google/fonts` with your explicit go-ahead — their `OFL.txt`
  files are kept alongside them) and declared them in `pubspec.yaml`.
- **Correction to the original plan:** the recommended first slice below
  said to wire the new typography into `SplashScreen` only. `AetherType` is a
  single shared token file by design ("nothing hardcoded in widgets — a
  future reskin only touches these tokens", per its own doc comment), so
  changing `AetherType`'s font-family constants necessarily changes every
  screen that reads `display`/`title`/`narration`/`body` at once — there is
  no way to scope a shared-token change to one screen without duplicating
  styles, which would be the wrong fix. Went with the correct, global change
  (`lib/app/design/typography.dart`: split the old single `_serif` constant
  into `_display` = Marcellus and `_narration` = Spectral) instead of a
  splash-only hack. Also updated `splash_screen.dart`'s `_Wordmark._style`,
  which had its own hardcoded `fontFamily: 'Georgia'` outside `AetherType`
  entirely — otherwise "AETHERBOOK" would have silently kept rendering in
  Georgia.
- Tests: `test/app/widgets/choice_card_test.dart` (2 cases), `test/app/widgets/
  confirm_sheet_test.dart` (5 cases). Full suite: 588/588 passing, `analyze`
  clean, both before and after the typography change (font-family isn't
  something the existing test suite asserts on, so this is a coverage gap
  by nature, not a false green — see "known limitation" below).
- Verified in the local web preview: all 3 font files fetch with `200 OK`
  (`/assets/assets/fonts/Marcellus-Regular.ttf`, `Spectral-Regular.ttf`,
  `Spectral-Italic.ttf`), Supabase initializes, no app-level console errors
  (one `TypeError` in the DWDS-injected debug client is a known
  `flutter run` web-server tooling artifact, unrelated to app code).

**Known limitation:** could not capture an actual pixel screenshot of the
running app in this session (`the Browser pane is not displayed, so the
page is not compositing frames` — an environment/tooling constraint, not an
app bug). Verification here is network + console + test-suite based, not
visual. **Recommend a manual look at the splash screen** (and one or two
other screens, since the font change is global) before this is treated as
fully signed off — `tool/run-web.ps1` / `tool/run-web.sh`, or ask a future
session with working screenshot access to confirm.

**Backward compatibility:** N/A — additive components; typography swap is
visually total but mechanically inert (no domain/persistence impact).

**Acceptance criteria:** met, with the visual-verification caveat above.

**Risk:** low.

---

## Stage 2 — Story discovery and library

**Status:** ✅ Done (2026-07-27) — dialog consolidation, then the visual
reflow described below and recorded in full in `V2_DESIGN_SYSTEM.md` §2.

**Goal:** migrate `WorldSelectScreen`/`StoryModuleScreen`/`CreateStoryScreen`
visuals; consolidate the app's `AlertDialog` confirmations into `ConfirmSheet`.

**Non-goals:** no gameplay-engine changes; multi-session freeform behavior and
story titles must survive unchanged (this is exactly what Stage 0's new test
guards against regressing).

**Files:** `world_select_screen.dart`, `story_module_screen.dart`,
`create_story_screen.dart`. No controller changes.

**Done:**
- **Dialog consolidation, corrected scope.** The original goal said "4
  existing `AlertDialog` confirmations" but only 2 of them live in this
  stage's files — `world_select_screen.dart`'s `_abandonStory` and
  `_restart`. The other 2 (`game_screen.dart`'s story-choice and ending
  confirmations) are Stage 4/5 files and stay on `AlertDialog` for now;
  migrating them belongs to those stages, not this one. Both of this
  stage's sites now call `showConfirmSheet` instead of
  `showDialog`/`AlertDialog`.
- **Bug found and fixed in the same file this stage already touches:**
  `create_story_screen.dart`'s `_reload` was `setState(() => _stories =
  _load())` — an *expression-bodied* closure, so its inferred return value
  was the assignment's own value (a `Future`), which trips Flutter's "a
  setState() callback returned a Future" assertion. Pre-existing, unrelated
  to the dialog migration, and only surfaced now because this is the first
  test to actually exercise abandon-then-reload through real widget
  interaction rather than only through `GameController` directly. Fixed to
  a block body (`setState(() { _stories = _load(); });`), which returns
  `void` instead.
- Tests: `test/app/world_select_confirm_sheet_test.dart` (2 cases —
  abandon-via-`CreateStoryScreen` and restart-via-`StoryModuleScreen`, both
  asserting the destructive action only fires *after* confirming, never
  before). Full suite: 592/592 passing, `analyze` clean.

**Visual reflow (2026-07-27), see `V2_DESIGN_SYSTEM.md` §2 for full detail:**
- `WorldSelectScreen` gained `_ContinueHero` — the in-memory session gets a
  prominent card above the module picker (V2 prototype §2a: "retomar es la
  acción principal"), carrying the world's own Stage 6b theme accent.
- `CreateStoryScreen`'s 5 freeform genres moved from a vertical list to a
  2-column `GridView` of `_GenreGridCard` (icon + name + tone blurb), per
  prototype §2b's "Mundos por abrir" grid density.
- `StoryCard` (now `StoryModuleScreen`-only) and `_SavedStoryCard`
  (`CreateStoryScreen`'s "Tus historias") both replaced their accent rail
  with a 44px icon-tile, matching `_ModuleCard`/`_ContinueHero`'s language.
- **Deliberately not shipped:** merging the 3 modules into one prototype-style
  unified library (an information-architecture change, not a visual reflow —
  see design-system doc for why), and per-campaign cover imagery (no such
  content-schema concept exists — flagged as a real gap, not silently
  dropped).
- Full suite re-verified green (631/631), `analyze` clean, after each slice.

**Tests:** `test/app/story_resume_navigation_test.dart` still passes
unmodified in behavior; `test/app/world_select_confirm_sheet_test.dart`
covers abandon/restart. No new widget tests added for the card-visual reflow
itself — behavior (tap targets, callbacks) is unchanged, only presentation;
existing tests already assert on the callbacks firing correctly.

**Acceptance criteria:** met — all 3 story modules still list/resume/
restart/abandon correctly; visual intent of prototype §2a/§2b reinterpreted
within the existing module architecture (see design-system doc for the
deliberate deviations).

**Risk:** low.

---

## Stage 3 — Character creation V2

**Status:** ✅ Done (2026-07-27).

**Goal:** reflow `chargen_screen.dart` into the prototype's step structure,
reusing real per-world origins/tags/vows/items — **never** the mockup's
hardcoded Isekai sample data (`oficinista`/`invisible`/etc. are illustrative
only).

**Non-goal that's no longer accurate by the time this shipped:** this entry
originally said "no tone step (Decision C not yet accepted)" — Decision C
was accepted and Stage 6c shipped the tone step before Stage 3 was picked up,
so the tone step already existed going in. No new `Character` fields were
added regardless — this stage is presentation-only, exactly as scoped.

**Files:** `chargen_screen.dart`, `test/app/chargen_screen_test.dart`.

**What shipped:** reflowed from one long scroll into 3 steps (V2 prototype
§2c/§5b), with a shared header (back arrow + "Paso N de 3 · <título>" + 3
progress pips) and a bottom CTA that reads "Siguiente" until the last step,
where it becomes "Confirmar ficha":
- **Step 1 — "Nombre y origen":** story title (freeform only, optional),
  name (or the fixed protagonist's name for a curated world), origin, the
  free `+1` point (only when the world declares one).
- **Step 2 — "Tu voz":** tone (only for the 5 freeform genres, optional),
  vow/juramento (required).
- **Step 3 — "Últimos detalles":** personal item (optional, free text) and a
  live-updating character-sheet preview ("Así entras al mundo" — name,
  attribute stat pills, personal item, vow quote), computed via a direct,
  synchronous `CreateCharacter` domain call — the exact same engine call
  `_confirm` makes for real, so the preview can never drift from what
  actually gets created.

One deliberate deviation from the prototype, recorded here rather than in
`V2_DESIGN_SYSTEM.md` since it's Stage-3-specific: the prototype bundles
*world selection* into its own chargen step 1 ("mundo y voz"). That doesn't
apply here — this app always picks the world first
(`WorldSelectScreen`/`CreateStoryScreen`), so by the time a player reaches
`ChargenScreen` the world is already fixed. Tone (the "voz" half of that
prototype step) was folded into step 2 alongside the vow instead, since both
are "who this character sounds/feels like" choices.

**Tests:** `test/app/chargen_screen_test.dart` fully rewritten to navigate
the 3 steps as a player would (fill a step, tap "Siguiente") rather than
assume every field is visible at once. 9 cases: step 1 blocks on name+origin
(and the free point, for a world that declares one) before advancing; a
world with no free point never blocks on it; the back arrow returns to the
previous step without losing already-made choices; step 2 blocks on the vow
and step 3 shows the live preview; plus the 5 pre-existing tone-step cases
from Stage 6c, updated to step through rather than assume one screen.
Covers both schema shapes named in the original scoping (`hasFreeAttributePoint`
true/false — the actual axis of chargen-flow variance across worlds; the
"structured milestone ranks" framing in the original scoping turned out not
to affect chargen at all, since no chargen field reads `World.ranks`/
`progression`). 636/636 Flutter tests passing, `analyze` clean.

Manually verified in the browser preview: step header/pips render correctly,
origin selection is a real single-select (confirmed by switching between
origins and watching the previous one deselect), no layout overflow at any
step. Text-field entry (name/title/personal item) could not be verified
through the browser tool specifically — synthetic typing doesn't reach
Flutter's web-server debug target's hidden text-input element (a tooling
limitation of that run mode, confirmed by the field still focusing correctly
with a visible cursor) — but this exact interaction is covered by
`tester.enterText` in the automated suite, which doesn't share that
limitation.

**Risk realized:** low — no world-specific field variability broke; the
`hasCustomizableName`/`hasFreeAttributePoint`/`tones.isEmpty` conditionals
all carried over unchanged from the single-page version, just relocated to
their step.

---

## Stage 4 — Gameplay reading experience

**Status:** ✅ Done (2026-07-27) — dialog consolidation, then the reflow
below. Full detail in `V2_DESIGN_SYSTEM.md` §1.

**Goal:** collapsible header, numbered choices, redesigned `FateRoll` compact
presentation, image-bleed scene open. Progressive-disclosure logic stays
**unchanged** — it's already correct.

**Non-goals:** ending-counter / tone-display / narrator-retry-count (those
need small `GameController`/Edge-Function additions first — Stage 6/7).

**Files:** `game_screen.dart`, `status_bar.dart`, `fate_roll.dart`,
`atmosphere.dart`.

**Done:**
- `game_screen.dart`'s remaining 2 `AlertDialog` confirmations (story-choice
  with `requiresConfirmation`, and the always-confirmed ending choice) now
  use `showConfirmSheet`, completing the dialog consolidation this document
  originally scoped as "4 sites" under Stage 2 — see Stage 2's note on why
  it split across stages by file ownership. Pure mechanical swap, no new
  design decision needed (same component, same call pattern already proven
  in Stage 2).
- Tests: `test/app/game_screen_confirm_sheet_test.dart` (3 cases —
  no-confirmation choice resolves on one tap; confirmation-required choice
  shows the authored `confirmationText` and does nothing until confirmed,
  including a cancel-then-retry path; ending confirmation shows the sheet
  titled with `Ending.visibleChoice` and only sets the ending flag after
  confirming). Full suite: 595/595 passing, `analyze` clean.

**Visual reflow (2026-07-27), see `V2_DESIGN_SYSTEM.md` §1 for full detail:**
- `StatusBar` gained a `collapse` double (0 expanded/default, 1 collapsed),
  driven directly by `GameScreen`'s reading scroll offset (no separate
  animation clock) — the EXP bar and resource pills fold away past 90px of
  scroll, replaced by a thin EXP-only rail; the identity row never moves.
  Deliberately **not** a floating overlay over the scene image (the
  prototype's own literal behavior) — see design-system doc for why that's
  a separable, higher-risk follow-up rather than bundled here.
- `ChoiceCard` (built in Stage 1, unused until now) is wired into
  `_ChoicesBar` for every enumerated decision (curated story choices + hub
  activities + endings share one running numeral sequence; freeform AI
  choices get their own). `ChoiceButton` stays for single non-enumerated
  actions ("Continuar", "Volver al menú").
- `FateRoll` needed **no changes** — already a near 1:1 match for the
  prototype's compact dice-check presentation (verified by direct
  comparison against the design source, not rebuilt).
- `_SceneImage` moved to a full-bleed 260px hero at the top of the scroll
  view (before the Fate Roll), edge-to-edge, with a bottom gradient
  dissolving it into the reading background instead of a hard card edge.
- Full suite re-verified green (631/631) and `analyze` clean after each
  slice.

**Tests:** the 3 existing cases in `test/widget_test.dart` pass unmodified
(behavior-only assertions, e.g. `find.text('ÉXITO')` — visuals changed,
outcomes didn't). No new widget test for the header-collapse specifically —
it's a continuous, scroll-bound value with no discrete state transition to
assert on beyond what already-passing scroll/reveal-gate tests exercise.

**Backward compatibility:** curated (`ai_runtime_required:false`), hybrid, and
freeform paths all still render identically — every mode routes through this
screen, confirmed by the existing suite (which exercises all three).

**Risk realized:** low — no scroll-linked logic broke; the collapse value
composes cleanly with the pre-existing reveal-gate scroll listener.

---

## Stage 5 — Character, inventory, and story sheets

**Status:** ✅ Done (2026-07-27).

**Goal:** convert `InventoryScreen` and a new `CharacterSheetSheet`
(consolidating `StatusBar`'s inline stats) into bottom sheets; add a
story-menu sheet (continue/my-stories/abandon) replacing ad-hoc navigation.

**Files:** `inventory_screen.dart` (→ sheet), new `character_sheet_sheet.dart`,
new `widgets/sheet_shell.dart` (shared chrome all 3 sheets use), new
`widgets/story_menu_sheet.dart`, `widgets/status_bar.dart`, `game_screen.dart`,
`game_controller.dart` (`sessionId` getter, `abandonActiveSession()`),
`core/world/world.dart` (`vowByIdOrNull`, mirroring the existing
`originByIdOrNull`/`toneByIdOrNull` pattern).

**What shipped:**
- `SheetShell` — shared drag-handle + title + close-button + height-capped
  scrollable-body chrome (V2 prototype §1a's shared `sheetOpen` shell), used
  by all 3 sheets below so they read as one family.
- `showInventorySheet` replaces the old pushed `InventoryScreen` route —
  same empty-state/item-card content, now a bottom sheet.
- `showCharacterSheet` (new) — origin + personal item as info chips, the
  world's own vow label (`chargenVowLabel`, e.g. a curated world's
  "Recuerdo conservado" instead of the generic "Juramento") with the vow
  quote, a 2-column attribute grid, and the resource pills that used to live
  inline in `StatusBar`. Reachable by tapping the name in the header (V2
  prototype §1a: "Toca el nombre para la ficha").
- `StatusBar` **consolidated**: resource pills removed entirely from the
  always-visible header (moved into `CharacterSheetSheet`); the header now
  only carries identity + EXP progress, which still collapses on scroll
  exactly as Stage 4 built it. Gained `onOpenCharacterSheet`, wired to an
  `InkWell` around the name/level block.
- `showStoryMenuSheet` (new) — the back arrow no longer leaves the story on
  one tap; it opens a menu with "Seguir leyendo" (dismiss), "Volver a mis
  historias" (existing `_goToMenu`), and "Abandonar esta historia"
  (destructive, new — see below). `StatusBar`'s back-button tooltip changed
  from "Volver a las historias" to "Menú de la historia" to match.
- `GameController.abandonActiveSession()` (new) — abandoning from *inside*
  the story itself is new functionality (the only prior abandon path,
  `abandonStory(sessionId)`, operates on a `GameSessionSummary` from a story
  list, which `GameScreen` doesn't have — it only knows the session it's
  currently showing, hence the new `sessionId` getter). Clears
  `world`/`character`/`isReady` back to their pre-`start()` state so
  `WorldSelectScreen`'s Stage-2 continue-hero doesn't offer to resume a story
  that no longer exists.

**Bug found and fixed by the new test suite, not by manual testing:**
`abandonActiveSession()` originally called `notifyListeners()` after clearing
`world`/`session`. `GameScreen`'s `ListenableBuilder` reads `c.world!`/
`c.character!` unconditionally in its main content branch; during the
`PageRouteBuilder`'s fade-out transition (the outgoing route stays mounted
and subscribed for the transition's duration), that notification triggered a
rebuild with both now `null`, crashing on the null-check operators. Fixed by
not calling `notifyListeners()` there at all — the caller is always
navigating away immediately after, so nothing needs to reactively re-render
a screen that's about to be replaced. Caught by
`test/app/game_screen_story_menu_test.dart`'s last case, which failed with
exactly that crash before the fix and passes after it.

**Tests:** `test/app/inventory_screen_test.dart` rewritten for sheet
presentation (opens via `showInventorySheet` from a throwaway Scaffold, same
3 assertions plus a new close-button case). New
`test/app/game_screen_story_menu_test.dart` (5 cases: menu opens instead of
leaving immediately; "Seguir leyendo" just dismisses; "Volver a mis
historias" navigates with the session kept; "Abandonar esta historia" asks
for confirmation and does nothing until confirmed; confirming clears the
session and navigates — the case that caught the bug above). 642/642
Flutter tests passing, `analyze` clean.

Manually verified in the browser preview: character sheet renders real data
end to end (origin, the world's custom vow label, attribute grid, resource
pill), inventory sheet's empty state, and the story-menu sheet's 3 rows —
all screenshotted and confirmed correct. Could **not** get a clean
click-through of "Abandonar esta historia" → "Abandonar" specifically in the
browser tool — every attempt landed on a choice card in the reading view
behind the sheet instead, most likely because a `resize_window` mid-session
left the tool's screenshot dimensions out of sync with Flutter's actual
`MediaQuery` size (the mismatch would explain why clicks near the *bottom*
of tall sheet content specifically kept missing). This did not block
verification: the exact same sequence (open menu → tap abandon → confirm →
tap "Abandonar" → session cleared → navigated) is what
`game_screen_story_menu_test.dart`'s last case drives through the real
Flutter test framework, unaffected by browser-tool viewport quirks — and
it's the test that caught the real crash above, so it's a stronger check
than a manual click would have been anyway.

**Risk realized:** low-medium — the `notifyListeners()`-during-transition
crash was a genuine miss that only automated testing (not code review) caught.

## Stage 6 — New mechanics (each its own vertical slice — never bundled)

Only proceed with a sub-stage once its blocking decision in
`V2_PRODUCT_DECISIONS.md` is **Accepted**.

- **6a — Ending-discovery counter — ✅ DONE (2026-07-27).** `GameController`
  gained `achievedEndingOrdinal`/`achievedEndingsTotal` (`int?`, both `null`
  until `chooseEnding` is called, reset by `start`), captured inside
  `chooseEnding` itself — `node.endings.indexOf(ending) + 1` and
  `node.endings.length` — since `currentNode` moves on to the epilogue
  immediately after, at which point the `ResolutionNode` (and its `endings`
  list) is no longer reachable. Wired into `_EndOfStory` in `game_screen.dart`
  as a "Final descubierto · N de M" line, shown only when both values are
  non-null (i.e. never for a curated AI-free story's dead end or a pure
  epilogue node with no endings mechanic — no special-casing needed, the
  values are simply `null` there). Tests: 2 new cases + assertions added to
  the existing success/fallback-failure cases in
  `test/app/game_controller_ending_test.dart` (ordinal reflects the
  *attempted* ending even when a failure fallback redirects the flag
  elsewhere). Full suite: 590/590 passing, `analyze` clean.
- **6b — Per-world visual theming — ✅ DONE (2026-07-27).** Decision E
  accepted as-is. `World` gained nullable `themeAccentHex`/`themeBaseHex`/
  `themeSecondaryHex` (raw hex strings, parsed from new `theme_accent`/
  `theme_base`/`theme_secondary` JSON keys — kept as `String?` rather than
  `Color` so `core/` stays Flutter-free per `core_purity_test.dart`). New
  `lib/app/design/world_theme.dart` (`WorldTheme.forWorld`) resolves them
  into real `Color`s in the presentation layer, falling back to the
  existing global gold/ink/nova palette for any world that declares
  nothing. `AetherBackground` (`widgets/atmosphere.dart`) gained a `base`
  parameter — needed because `accent` alone only tints the drifting motes,
  which `GameScreen` disables (`particles: false`); without `base` feeding
  the backdrop gradient's mid stop, per-world theming would have been
  invisible on the one screen it matters most. All 8 `assets/worlds/*.json`
  files now declare real values (Isekai `#EAC978`/`#15120F`/`#9B5DE0`,
  Xianxia `#7FD4C1`/`#0F1D1A`/`#D8B65E` — shared by `xianxia_lianshu`,
  Superhéroes `#F0564A`/`#170F0E`/`#4C8BF0`, Cyberpunk `#55E0F0`/`#0C1016`/
  `#FF4FA3` — shared by `curated_cyberpunk_02_apagon_violeta`,
  Post-apocalíptico `#B8B27A`/`#161611`/`#D2762F` — shared by
  `curated_zombie_01_ultimo_tren`). Wired into `GameScreen`'s
  `AetherBackground` only so far — library cards, chargen, and the
  title-treatment/texture dimensions are explicitly deferred, see
  `V2_PRODUCT_DECISIONS.md`'s Decision E entry. Tests: `test/world/
  world_test.dart` (2 cases), `test/app/design/world_theme_test.dart` (6
  cases: hex parsing, fallback, per-field independence), `test/app/widgets/
  atmosphere_test.dart` (2 cases: default gradient, themed gradient). Full
  suite: 605/605 passing, `analyze` clean, all `test/content/*` JSON-parsing
  tests re-verified green after editing all 8 world files.
- **6c — Player-selectable tone — ✅ DONE (2026-07-27).** Decision C
  accepted, **full mechanic** (user explicitly chose this over the cheaper
  display-only option):
  - [x] Domain: new `core/world/tone_option.dart` (`ToneOption{id, label,
    blurb, previewText}`), `World.tones`/`World.toneByIdOrNull`, parsed from
    a new `tones` JSON array (empty/no tone step for any world that
    declares none — every world predating this). `Character.chosenTone`
    (nullable) threaded through `CreateCharacterInput`/`CreateCharacter`,
    same optional-step pattern as `freeAttributePoint`. Tests: `test/world/
    tone_option_test.dart`, a new group in `test/world/world_test.dart`, 2
    new cases in `test/engine/create_character_test.dart`. 611/611 passing,
    `analyze` clean.
  - [x] Content: authored the `tones` array (3 entries: épico/íntimo/ácido,
    each with a per-world `preview`) for all 5 freeform genre worlds
    (isekai/xianxia/superheroes/cyberpunk/postapoc) — 15 snippets total,
    grounded in each world's own opening scenario, matching
    `NARRATIVE_VOICE.md`'s tuteo/register/rhythm rules. Curated/hybrid
    worlds (`xianxia_lianshu`, the 2 curated stories) intentionally keep
    their own fixed authorial tone — no `tones` array added there, no tone
    step for those. New test group in `test/content/freeform_worlds_test.dart`
    (one case per world, 5 total) checks exactly `{epico, intimo, acido}`
    are declared, every `label`/`blurb`/`previewText` is non-empty, and a
    regex sweep for common voseo markers (`vos`, `tenés`, `podés`, ...)
    catches any that slipped in. 616/616 passing, `analyze` clean.
  - [x] Narrator contract: `HttpNarratorAdapter._chosenToneJson` resolves
    `Character.chosenTone` against `World.tones` into `{label, blurb}`
    (never the raw id or the world's full tone list) and sends it as a new
    top-level `chosenTone` request field — `null` for any world/character
    without one. TS side: `types.ts` gained `ChosenTone`/`NarratorRequest
    .chosenTone`; `prompt_builder.ts` gained `buildToneInstruction`, wired
    into `buildSystemPrompt` right after `HUMAN_STYLE_INSTRUCTION` (a tone
    instruction is a style directive, not per-turn context, so it belongs
    in the system prompt, not the user prompt). Explicitly tells the model
    the tone affects *how* the story is told, never *what* happens
    mechanically. Tests: 2 new cases in `test/adapters/
    http_narrator_adapter_test.dart` (resolves correctly; `null` for
    absent/unknown), 4 new Deno cases in `prompt_builder_test.ts`. 618/618
    Flutter tests + 54/54 Deno tests passing, both `analyze`/`deno check`
    clean. **Deployed 2026-07-27** — `narrator` redeployed on the
    `aetherbook` Supabase project (hsgdldztcolteyodiscu), version 8 → 9,
    status ACTIVE, confirmed via `get_advisors`/`get_logs` with no new
    issues introduced. The tone instruction is now live.
  - [x] Persistence: `supabase/migrations/20260727_characters_chosen_tone.sql`
    — additive nullable `characters.chosen_tone text`. `game_state_mappers
    .dart`'s `characterToRow`/`characterFromRow` read and write it.
    **Applied 2026-07-27** to the live Supabase project (migration
    `20260727195209_characters_chosen_tone`, confirmed via
    `list_migrations`). Tests: extended the existing round-trip case in
    `test/adapters/game_state_mappers_test.dart` plus its
    missing-field-defaults case. 618/618 passing, `analyze` clean (no new
    test *count* here — existing cases gained assertions, no new `test()`
    blocks needed).
  - [x] UI: `chargen_screen.dart` gained a "Tono de la narración (opcional)"
    section, shown only when `world.tones.isNotEmpty` (every world except
    the 5 freeform genres today). Reuses the existing `_SelectableCard`
    (single-select, tap-to-toggle — tapping the already-selected tone again
    clears it, since this is explicitly optional, unlike origin/vow) and
    shows the selected tone's `previewText` in a highlighted box below the
    options, matching the "Pasiva" highlight pattern already used for
    origins. Threaded into `CreateCharacterInput.chosenTone` at confirm.
    New `test/app/chargen_screen_test.dart` (5 cases — no widget test
    existed for this screen before: step hidden with no tones, tones shown
    + preview on tap, deselect-by-re-tapping, confirms with a tone chosen,
    confirms with none chosen). 623/623 passing, `analyze` clean.

  **Stage 6c is now fully done, deployed, and live** (2026-07-27) — both
  the Edge Function redeploy and the migration were explicitly confirmed
  with you before being executed. `master` was also pushed to origin (14
  commits) the same day, triggering Vercel's auto-deploy of the client.
- **6d — Auth expansion — ✅ code done (2026-07-27), not live yet.** Decision D
  accepted, **discontinuing magic-link** (user's explicit choice — see
  `V2_PRODUCT_DECISIONS.md`).
  - `AuthPort` (`lib/ports/auth_port.dart`): `continueWithEmail`/
    `EmailLinkOutcome` removed entirely. New surface: `signInWithGoogle()`,
    `signUpWithPassword({email, password})`, `signInWithPassword({email,
    password})`, `resetPassword(email)`, plus a new
    `EmailAlreadyRegisteredException` (thrown by `signUpWithPassword` when
    the email belongs to a different account — V2 design prototype §10d's
    merge-warning case).
  - `SupabaseAuthAdapter`: `signInWithGoogle` uses `linkIdentity(OAuthProvider
    .google)` — deliberately **not** `signInWithOAuth`, which would create a
    separate session instead of attaching Google to the current anonymous
    one (losing the "keep today's progress" property every other auth path
    has). `signUpWithPassword` reuses the existing `isEmailAlreadyTakenError`
    helper (untouched, still tested by
    `test/adapters/auth/supabase_auth_adapter_test.dart`) to turn Supabase's
    error into `EmailAlreadyRegisteredException`. `signInWithPassword`/
    `resetPassword` are thin `GoTrueClient` wrappers — per existing
    precedent, these aren't unit-tested directly (no `GoTrueClient` mock
    harness exists in this repo); coverage comes from `FakeAuthAdapter` +
    `AccountScreen` widget tests instead, same as `continueWithEmail` always
    was.
  - `account_screen.dart` rewritten: Google button + sign-up (email/
    password) as the default view + a sign-in mode + a forgot-password
    mode, switchable via text links. Listens to `AuthPort.onChange` in
    `initState` (not just reacting to each call's own `Future`) because
    Google's `linkIdentity` only *launches* the consent screen — actual
    completion arrives later via that stream, once the player returns from
    the external browser.
  - `splash_screen.dart`: button copy simplified from "Guardar tu progreso
    con tu email" to "Guardar tu progreso" (no longer email-specific).
  - Tests: `test/app/account_screen_test.dart` fully rewritten (14 cases —
    sign-up form/disabled-submit/success/email-taken/generic-error, Google
    link/success/failure, sign-in success/failure/links, forgot-password).
    Found and fixed a real overflow bug in the email-taken warning card's
    `Row` (missing `Expanded` around the message text) that the old tests
    couldn't have caught since that card didn't exist before. Also hit the
    same long-`ListView`-in-a-small-test-viewport issue `chargen_screen_test
    .dart` did — fixed the same way (taller test viewport). 631/631 passing,
    `analyze` clean.

  **Not live yet — two things need your action in the Supabase/Google
  dashboards before Google sign-in actually works for a player:**
  1. Configure a Google Cloud Console OAuth client (ID + secret) and enable
     Google as a provider in Supabase's Auth settings.
  2. Enable **"Allow manual linking"** in Supabase's Auth settings —
     `linkIdentity` requires it, and without it every Google attempt fails.

  Email/password (sign-up, sign-in, reset) needs no extra dashboard
  configuration beyond what magic-link already had — it works as soon as
  this code is deployed.
- **6e — Story-graph editor.** Decision A **deferred** (2026-07-27, user
  confirmed). Not scheduled.
- **6f — Publishing/UGC.** Decision B **deferred** (2026-07-27, user
  confirmed). Not scheduled.

---

## Stage 7 — Ending, account, offline, and resilience polish

**Goal:** narrator retry-count surfaced (Edge Function + `GameController`
change), re-verify image-failure-never-blocks after all UI changes, re-verify
AI-free curated stories make zero network calls after the redesign.

**Files:** `supabase/functions/narrator/types.ts`, `index.ts`,
`game_controller.dart`, `game_screen.dart`.

**Verification:** re-run `test/content/curated_zombie_01_ultimo_tren_test.dart`
and `test/content/curated_cyberpunk_02_apagon_violeta_test.dart`, plus a
manual network-tab check in the browser preview during a curated playthrough.

**Risk:** low-medium — touches the Edge Function, needs a deploy.

---

## Stage 8 — Accessibility, responsiveness, performance, release hardening

**Goal:** dynamic text scaling (Spectral narration at 62ch max-width must
reflow, not clip), reduced-motion consistency (the prototype's own
`@media (prefers-reduced-motion:reduce)` rule and the existing
`_TomePainter`/`AetherBackground` motion-respecting behavior should match),
contrast verification on the 5 new per-world palettes (Cyberpunk's cyan-on-near-black
in particular needs a real contrast check, not just visual approval), full
suite + manual preview pass across mobile/tablet/web breakpoints.

**Risk:** low-medium, mostly verification work.

---

## Recommended first implementation slice — ✅ DONE (2026-07-27, see Stage 1)

Originally scoped as "typography-only, wired into `SplashScreen` only."
Executed as a **global** `AetherType` font-family swap instead, since the
token file can't be scoped to one screen without duplicating styles — see
the "Correction to the original plan" note under Stage 1 above for why.
`flutter analyze`/`flutter test` green (588/588); pixel-level visual
confirmation still recommended (tooling limitation, not skipped on purpose).

---

## Test strategy summary (see `V2_GAP_ANALYSIS.md` §4 for the gap this closes)

- **Widget/navigation tests:** the one confirmed gap (resume-through-navigation)
  is closed as of Stage 0. Add one per new reusable component (Stage 1), one
  for header-collapse behavior (Stage 4).
- **Golden tests:** start small, stay small — `ChoiceCard` (Stage 1), one
  gameplay-reading-state screenshot (Stage 4), one per-world-theme card
  (Stage 6b). Do not golden-test every screen state.
- **Domain tests:** only needed for accepted Stage-6 mechanics (tone-prompt
  test, theme-fallback test, ending-count getter test).
- **Adapter tests:** only if Decision D lands — mirror the existing
  email-link test shape in `supabase_auth_adapter_test.dart` for
  Google-OAuth/password flows.

## Documentation update plan summary (see full plan in the original audit
conversation if a future session needs the "why" — kept out of this file to
avoid duplicating `V2_GAP_ANALYSIS.md`/`V2_PRODUCT_DECISIONS.md`)

- `CLAUDE.md`: add a pointer to `docs/v2/V2_DESIGN_SYSTEM.md` (created
  2026-07-27, once Stage 2/4's visual reflow actually needed it — done, see
  §1 below) and update the phase marker as each stage ships.
- `GDD-RPG-Narrativo-IA.md`: update §9's aspirational per-world-theming
  language once Decision E is confirmed and Stage 6b ships.
- `README.md`: update only after a stage actually ships — never describe
  planned V2 functionality (the editor, publishing, etc.) as currently playable.

---

## Stage status tracker

| Stage | Status | Blocked by |
|---|---|---|
| 0 — Baseline and safeguards | ✅ Done (2026-07-27) | — |
| 1 — Design-system foundation | ✅ Done (2026-07-27) — visual sign-off still recommended, see Stage 1 notes | — |
| 2 — Story discovery and library | ✅ Done (2026-07-27) | Stage 1 |
| 3 — Character creation V2 | ✅ Done (2026-07-27) | Stage 1 |
| 4 — Gameplay reading experience | ✅ Done (2026-07-27) | Stage 1 |
| 5 — Character/inventory/story sheets | ✅ Done (2026-07-27) | Stage 1 |
| 6a — Ending-discovery counter | ✅ Done (2026-07-27) | — |
| 6b — Per-world visual theming | ✅ Done (2026-07-27) | — |
| 6c — Player-selectable tone | ✅ Done and deployed (2026-07-27) — Edge Function redeployed (v9) and migration applied to the live Supabase project | — |
| 6d — Auth expansion | ✅ Code done (2026-07-27); Google Cloud Console client + "Allow manual linking" reportedly configured by you, not yet confirmed end-to-end (blocked on a browser-preview tooling issue, not the app) | — |
| 6e — Story-graph editor | Deferred (2026-07-27) | — |
| 6f — Publishing/UGC | Deferred (2026-07-27) | — |
| 7 — Ending/account/offline/resilience polish | Not started | Stage 4, 6a |
| 8 — Accessibility/responsiveness/performance/release | Not started | Stages 1-7 |
