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

**Follow-up closed (2026-07-27), the rest of §10a:** `V2_GAP_ANALYSIS.md`
flagged `10a` as only "Partial" — the typography swap above was done, but
the tome→symbol swap and the three explanatory lines it also calls for were
not. Closed now, prompted by you noticing the splash screen still looked
like the old one:
- New `lib/app/widgets/brand_mark.dart` (`BrandMark`) — the hexagon-with-"A"
  symbol (V2 prototype §7a/§10a/§10b), the one brand mark used everywhere
  the app shows an identity from here on. Two treatments: an outlined
  gradient-bordered version for the splash (`filled: false`, with a `glow`
  parameter tied to the same shimmer clock the wordmark already used, so
  reduce-motion silences both together) and a flat solid-gold version for
  inline use elsewhere (`filled: true`).
- `splash_screen.dart`: the old animated `_TomePainter` (removed entirely)
  is replaced by `BrandMark`; three explanatory lines now sit between the
  tagline and the button (escribes-lo-que-quieras / el-mundo-recuerda /
  cinco-mundos); the button's icon moved from a leading book glyph to a
  trailing arrow, matching the prototype exactly.
- `account_screen.dart`: swapped its placeholder `Icons.shield_moon_rounded`
  (never a real brand element) for the same `BrandMark` — the design's own
  sync notes call for "el hexágono con la «A» como único logo en todas las
  pantallas".

**Deliberately not done in this pass:** the Google button on
`account_screen.dart` still uses a generic Material `Icons.g_mobiledata_rounded`
rather than Google's real 4-color "G" mark the prototype specifies as an
inline SVG — transcribing that path by hand was judged not worth it next to
just fixing the splash gap that was actually reported; flagging as a real,
known small gap rather than silently leaving it unmentioned. Also not done:
a distinct **web-only** layout for the splash (prototype §8a/8b) — today's
`splash_screen.dart` is the same single-column layout at every width,
bounded by `ConstrainedBox(maxWidth: 440)`; a real two-column web treatment
would be new work, not a fix to what's here.

**Follow-up closed (2026-07-27, later the same day):** the Google icon gap
above was closed in the same pass as the anonymous-auth removal below — added
`flutter_svg` and a new `google_logo.dart` (`GoogleLogo`) rendering the real
4-color "G" mark verbatim from the prototype's inline SVG, replacing the
Material glyph in `account_screen.dart`. Two more things reported against the
deployed app (screenshots of the live site, not the prototype) were fixed in
a further pass right after:
- `splash_screen.dart`'s `_Wordmark` read "AETHERBOOK" in bold caps with wide
  tracking — the prototype's §10a CSS is `font:400 42px/1.05
  Marcellus,serif;letter-spacing:1.2px` over the text "Aetherbook" (normal
  case, normal weight). Matched exactly; also added the trailing period the
  prototype's tagline has (`Un multiverso que se escribe contigo.`) that was
  missing.
- `brand_mark.dart`'s hexagon path used an elliptical radius (`rx ≠ ry`) to
  match the prototype's `clip-path` exactly touching all four edges of its
  box — re-derived vertex-by-vertex twice and confirmed it was mathematically
  correct, so it isn't why the filled variant read as warped in the user's
  screenshots at `size: 44` in `account_screen.dart`. Simplified anyway to a
  regular hexagon (single radius, `size/2`) since every call site passes a
  square box, so nothing is lost, and it removes a whole axis of doubt.
  **This screen's actual pixels were never re-confirmed visually in this
  session** — the Browser pane's screenshot tool stayed non-functional
  throughout ("the Browser pane is not displayed, so the page is not
  compositing frames"), so this fix is verified by `flutter analyze`/`flutter
  test` and by re-deriving the geometry, not by seeing the render. If it
  still looks off after this deploys, it's worth ruling out a stale Flutter
  web service-worker cache on the client (a hard refresh / incognito load)
  before assuming the code is still wrong.

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

  **Revision (2026-07-27, later the same day) — anonymous play removed
  entirely, per your explicit instruction ("Ya NO se debe poder seguir sin
  cuenta ni hacer un ingreso anónimo"):** see
  `V2_PRODUCT_DECISIONS.md`'s Decision D for full detail. Summary of what
  changed on top of everything above:
  - `main.dart` no longer signs in anonymously at launch — `ensureSignedIn()`
    is gone. `SplashScreen`'s "Comenzar" now gates on `isAnonymous`, routing
    to `AccountScreen` first (and only there) when there's no real account.
  - `SupabaseAuthAdapter.signInWithGoogle`/`signUpWithPassword` switched from
    `linkIdentity`/`updateUser` to `signInWithOAuth`/`signUp` — there's no
    anonymous session left to attach to, so these create a real account
    directly. **"Allow manual linking" is no longer required** for this
    reason — the two dashboard steps below are now down to one.
  - `AccountScreen` gained a required `onAuthenticated` callback, dropped its
    persistent "linked" resting view, and now hands control back to
    `SplashScreen` immediately once a real identity exists — it's a one-shot
    gate, not an opt-in settings screen anymore.
  - The Google button's icon is now Google's real 4-color mark (new
    `lib/app/widgets/google_logo.dart`, `flutter_svg` dependency added) —
    was a generic single-color Material icon before.
  - `test/app/account_screen_test.dart` rewritten again for the new
    `onAuthenticated`-callback shape (15 cases); new
    `test/app/splash_screen_test.dart` (5 cases) covers the gating itself —
    no test existed for `SplashScreen` before this. 648/648 Flutter tests
    passing, `analyze` clean.

  **Still needed in the Google/Supabase dashboards** — down to one item now:
  configure a Google Cloud Console OAuth client (ID + secret) and enable
  Google as a provider in Supabase's Auth settings. You reported this is
  already done. Email/password (sign-up, sign-in, reset) needs no dashboard
  configuration at all.

  **Not independently re-verified visually this session:** the browser
  preview's screenshot tool hit the same "Browser pane is not displayed"
  environment issue from earlier sessions and never recovered despite
  several retries — could not confirm pixel rendering of the new Google
  logo (a new dependency, `flutter_svg`, rendering on Flutter *Web*
  specifically) or the gated splash flow visually. Confidence here rests on
  `analyze`/the test suite (which does drive the real widget tree through
  `AccountScreen`/`SplashScreen`, including tapping the real "Continuar con
  Google" button), not a screenshot. Recommend a manual look once deployed,
  same caveat as Stage 1's typography change.
- **6e — Story-graph editor.** Decision A **deferred** (2026-07-27, user
  confirmed). Not scheduled.
- **6f — Publishing/UGC.** Decision B **deferred** (2026-07-27, user
  confirmed). Not scheduled.
- **6g — Perfil, Ajustes, onboarding (V2 prototype §6a-e).** ✅ **Done
  (2026-07-28)**, full scope on all three axes the user chose (real vow
  tracking, functionally-wired Ajustes including world harshness/avoided
  themes, account-synced settings):
  - New backend: `user_settings` table (jsonb) + `reading_stats()` RPC
    (both migrated and applied), `SettingsPort`/`Supabase`/`FakeSettingsAdapter`,
    `AuthPort.signOut`/`accountCreatedAt`, `GameStateRepositoryPort.completeSession`/
    `readingStats`.
  - New engine: `StateDeltaType.vowStatus` (`sostenido`/`puesto_a_prueba`/`roto`,
    narrator may only propose the latter two — `sostenido` is engine-set once,
    at `chooseEnding`, unless already `roto`), `difficultyOffset` threaded
    through `ResolvePlayerAction`/`ResolveStoryChoice` for `WorldHarshness`
    (indulgente/justo/cruel, ±2). `VowReward` (the qi-restore/exp-grant
    decision class) stays deliberately unwired — tracking outcome for Perfil
    didn't need it.
  - Narrator prompt: `vowText`/`avoidedThemes` reach `NarratorRequest`
    (resolved client-side from `World.vows`/`UserSettings.avoidedThemeLabels`),
    two new `prompt_builder.ts` instructions. Gemini's `RESPONSE_SCHEMA` enum
    needed `"vow_status"` added (and `STRING` to the value `anyOf`) — caught
    only once actually deploying, since Groq's free-text prompt has no schema
    to enforce this and the deno tests don't exercise the Gemini schema
    directly.
  - New screens: `profile_screen.dart` (real tomos/turnos/terminadas,
    per-world breakdown, juramentos list — nothing hardcoded), `settings_screen.dart`
    (every control wired, not cosmetic), `widgets/avoided_themes_sheet.dart`
    (a sheet, not a 6th screen), `widgets/step_dots.dart` (extracted from
    `ChargenScreen` for reuse), `onboarding_screen.dart` (3 pages, reuses
    `FateRoll` with a fixed resolution for the dice demo). `WorldSelectScreen`
    gained a Perfil entry icon and an `autoOpenModule` param so onboarding's
    last page can open the chosen module directly.
  - `GameController` gained `auth`/`settingsPort` fields (a convenience
    carrier so `WorldSelectScreen`/`ProfileScreen` can reach them without a
    constructor param rippling through every intermediate screen) and
    `settings`/`updateSettings`.
  - `SplashScreen`'s `onAuthenticated` path now loads settings before
    deciding whether to show onboarding — checked for both a freshly
    signed-in account **and** an already-signed-in returning one, so an
    account that signed up then closed the app mid-onboarding still gets
    routed there on the next launch, not just one that finishes in the same
    sitting. Caught and fixed a real bug here during testing: the "already
    signed in, no `AccountScreen` push first" path replaces `SplashScreen`'s
    own route, so a `_SplashScreenState` method closed over as `onDone` would
    reach into an already-disposed `State`'s `context` — fixed by having
    `OnboardingScreen`'s `pageBuilder` close over its own live `pageContext`
    instead.
  - Deliberately not built: actually *sending* reminder notifications (no
    push infra exists, the setting value is still saved) and "exportar mis
    tomos" (a real export feature, bigger than a settings row) — both flagged
    explicitly rather than silently left inert.
  - 686 Flutter tests passing (up from 588), `analyze` clean; 62 Deno tests
    passing for the narrator function. Both new migrations applied and the
    `narrator` Edge Function redeployed (v10) to the real Supabase project.
  - **Not independently re-verified visually this session**: a live browser
    smoke test was blocked by an unrelated, long-running Docker Desktop
    process squatting on port 8080 (not something this session started) —
    confidence rests on the test suite (which drives real widget trees
    through `SplashScreen`/`OnboardingScreen`/`ProfileScreen`/`SettingsScreen`,
    including the full sign-in → onboarding → world-select navigation chain)
    and the backend deploy succeeding, not a screenshot. Recommend a manual
    look once deployed.
- **6h — Home dashboard, responsive (V2 prototype §8a/§8b web-tablet, §2a/§2b
  mobile).** ✅ **Done (2026-07-28)**. The prototype's own roadmap note at the
  end of its §2 turn had already named this as the next step ("versión web
  de 2b") — not a new idea, the planned continuation of Stage 2's
  single-column reflow. Per your explicit choices: **adds** a cross-module
  dashboard/library rather than merging `StoryModuleScreen`/`CreateStoryScreen`
  away; backend is one new purpose-built RPC instead of overloading
  `readingStats()`/`listActiveSessions`; "Explorar" renders but is inert (a
  "todavía no está disponible" snackbar, same treatment as Ajustes' "Exportar
  mis tomos").
  - New backend: `story_library()` RPC (one row per session the account owns,
    any status — session id/world slug/status/title/character name/turn
    count/updated_at), migrated with `security invoker`/`search_path`
    hardening applied up front this time (the previous migration,
    `reading_stats()`, needed a follow-up fix for this — learned from that).
    Applied to the live Supabase project; `get_advisors` confirmed no new
    security warnings.
  - New domain: `SessionLibraryEntry` (`lib/core/state/game_session.dart`),
    `GameStateRepositoryPort.storyLibrary()` +
    `SupabaseGameStateAdapter`/mapper, `GameController.storyLibrary()` (same
    null-persistence-degrades-to-`[]` pattern as `readingStats()`).
  - New responsive infrastructure: `AetherBreakpoints` (`tablet = 700`,
    `desktop = 1100` — new constants, distinct from `game_screen.dart`'s
    pre-existing `_ReadingFrame` 720px content-frame width, which is a
    different concern and stays untouched), `HomeSidebar` (desktop: brand,
    nav, per-world story counts, account row) and `HomeBottomNav` (tablet: 4
    destinations, no Ajustes — sidebar-only per the mockup).
  - New `MyStoriesScreen` (§2b) — unified cross-module story list (Todas/En
    curso/Sin empezar filters), reachable from "Sigue leyendo → Ver todos"
    and from the sidebar/bottom-nav "Mis historias" item. `library_rows.dart`
    (`buildLibraryRows`) and `story_navigation.dart` (`StoryNavigation.open`/
    `resume`, extracted verbatim from `WorldSelectScreen`'s prior `_select`/
    `_resumeStory`) are shared by both screens so the resume/chargen-or-not
    decision logic isn't duplicated.
  - `WorldSelectScreen` rewritten around `LayoutBuilder` +
    `AetherBreakpoints` into 3 chrome modes: mobile keeps its original
    single-column shape (title, a real hero + up to 2 more library rows
    where `_ContinueHero` previously only reflected whatever session
    happened to be in memory, then the unchanged module-card list); tablet
    adds `HomeBottomNav` + a 2-column "sigue leyendo" grid; desktop adds
    `HomeSidebar` + a 3-column grid. `_ContinueHero` now takes a `LibraryRow`
    instead of an in-memory `World`/`Character` pair, so "what did I leave
    open" is a real query result that survives a fresh launch, not something
    that only worked mid-session.
  - Deliberately **not** built: a full visual redesign of mobile's home
    screen to match prototype §2a exactly (full-bleed background image,
    centered brand mark) — mobile keeps its pre-existing, already-tested
    visual identity, just gaining the real hero/list data. Scoped out for
    time, not asked about explicitly; worth a follow-up if the mismatch
    bothers you once you see it deployed.
  - Fixed along the way (see "Errors and fixes" precedent in prior stages
    for this pattern): a `Border`-with-non-uniform-colors +
    `borderRadius` crash in `MyStoriesScreen`'s card (accent stripe moved to
    a separate `Container` inside a `ClipRRect`); an infinite-height
    constraint crash from a `Row(crossAxisAlignment: stretch)` with a
    childless sized `Container` (wrapped in `IntrinsicHeight`); text overflow
    in `HomeSidebar` at its fixed width (`Flexible`/`Expanded` +
    `TextOverflow.ellipsis`). Also: setting `tablet = 700` meant Flutter's
    default 800×600 test surface now resolves to tablet chrome instead of
    the historically-assumed mobile layout, breaking 3 pre-existing tests
    (`world_select_confirm_sheet_test.dart`×2, `story_resume_navigation_test.dart`×1)
    — fixed by explicitly forcing those tests to a 600×1000 viewport.
  - **Not independently re-verified visually this session** as of writing —
    recommend the same manual look once deployed as every prior stage in
    this section.
  - **Noted but out of scope**: a pre-existing overflow bug in
    `create_story_screen.dart`'s `_GenreGridCard` at very narrow widths
    (~400px), found incidentally while picking a test viewport size for the
    fix above (never previously exercised since the test default was always
    800px wide). Not fixed — flagging here since it wasn't reported
    elsewhere yet.
- **6i — Game screen states and wide layout (V2 prototype §1a/§1b/§1c).**
  ✅ **Done (2026-07-28)**. `game_screen.dart` had Stage 4's collapsible
  header/`ChoiceCard`/compact `FateRoll`/scene-bleed, but never got §1b's
  polished loading/error/ending states or §1c's real wide layout — the
  `_ReadingFrame` just centered the same mobile column in a 720px card on
  any width. This closes both gaps:
  - **Loading**: `_ChoicesBar`'s busy state gained the mockup's "Puedes
    seguir leyendo el turno anterior" caption under `DestinyWriting` — the
    rest of the mockup's loading skeleton was judged already covered in
    spirit (the previous turn's real text/image staying visible while
    waiting is arguably better than a static skeleton wipe, and matches
    what that caption itself promises).
  - **Narrator error**: new `_NarratorErrorPanel` (icon, fixed reassuring
    copy, "Reintentar"/"Elegir otra vez") replaces the old bare red error
    text, plus the stale narration now dims to 40% opacity while an error is
    showing. `GameController` gained `retryLastAction()`/`clearError()` and
    a `_lastAction` closure captured at the top of every turn-attempting
    method (`choose`/`continueStory`/`_chooseOption`/`chooseEnding`) —
    replaying it is safe because `_resolveTurn` never commits anything to
    `_session`/`_error` until it either succeeds or hits its `catch`.
    Deliberately **not** built: the mockup's attempt counter/auto-retry
    countdown — nothing in the client or the narrator Edge Function tracks
    attempts today, and building that just for this panel was judged out of
    proportion to a visual pass.
  - **Ending reveal**: new `_EndingRevealOverlay`, shown once between
    confirming an `Ending` and reading its epilogue (turns/level/juramento
    stats, single "Leer el epílogo" CTA). Deliberately the **lightweight**
    version you chose over full fidelity: `Ending` gained no new
    `title`/`summaryQuote` fields, so the headline reuses
    `Ending.visibleChoice` instead of authoring new copy across ~21
    endings/failures in 3 worlds' content. Built as a pure UI interstitial
    with zero engine changes — `GameController.chooseEnding` still resolves
    and narrates the epilogue in one call exactly as before; the overlay
    just delays *revealing* that already-finished narration one beat,
    tracked entirely in `_GameScreenState` (`_pendingEnding`/
    `_endingRevealedFor`).
  - **Wide layout (§1c)**: `game_screen.dart` now reuses
    `AetherBreakpoints.tablet` (already introduced for the home dashboard,
    Stage 6h) as its own mobile/split-view switch, via a `LayoutBuilder`.
    Below it, mobile is byte-for-byte the same column, scroll-gate and all.
    At or above it, a new `_SplitView` (fixed-width `_ScenePanel` on the
    left, `StatusBar` pinned uncollapsed + narration + an always-visible
    `_ChoicesBar` — no scroll-gated hint — on the right) takes over, and
    `_ReadingFrame` now frames whichever child at its own width (720px
    mobile, 1040px wide, was previously a single hardcoded 720px for
    everything). `StatusBar`/`FateRoll` are reused completely unchanged
    (no compact variant built) — an accepted, minor size/density difference
    from the mockup rather than doubling either widget's surface area.
  - **Two pre-existing bugs found and fixed along the way** (both
    surfaced only once a test exercised a genuinely realistic mobile
    width instead of the historical 800px default): `fate_roll.dart`'s
    `_OutcomeLabel` Row had no flex protection at all and overflowed
    horizontally for any critical/natural-roll outcome at normal mobile
    column widths (~550px) — fixed by wrapping the "vs dificultad N" text
    in an `Expanded` with `overflow: ellipsis`. `test/vertical_slice_test.dart`
    forcing a **narrow** viewport (600×1000, needed to dodge Stage 6h's new
    tablet-breakpoint collision at the old 800×600 default) also exposed a
    third, separate, **not fixed** issue: `_armRevealGate`'s single-frame
    check of `maxScrollExtent` can race a turn whose content sits right at
    the edge of fitting without scrolling, permanently stranding the
    choices bar behind "Sigue leyendo" — confirmed present on unmodified
    code too (not something this stage introduced). Worked around by giving
    that one test a taller viewport (600×2000) instead of fixing the race;
    flagging it here as a real, pre-existing UX bug worth its own
    investigation, in the same spirit as the `_GenreGridCard` overflow
    flagged in 6h.
  - 704 Flutter tests passing (up from 699), `analyze` clean. No backend
    changes this stage — pure Flutter, no migration, no Edge Function
    redeploy needed.
  - **Not independently re-verified visually this session**: the browser
    preview is still blocked by the same stray Docker container on port
    8080 from prior sessions (this time with a different, more actionable
    error suggesting a `.claude/launch.json` `autoPort` fix — not attempted,
    judged out of scope for this stage). Recommend a manual look once
    deployed, same as every prior stage.

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
| 6d — Auth expansion | ✅ Code done (2026-07-27), revised same day to remove anonymous play entirely (your explicit instruction) — Google Cloud Console client reportedly configured by you; "Allow manual linking" no longer needed (`linkIdentity` → `signInWithOAuth`); not yet confirmed end-to-end (blocked on a browser-preview tooling issue, not the app) | — |
| 6e — Story-graph editor | Deferred (2026-07-27) | — |
| 6f — Publishing/UGC | Deferred (2026-07-27) | — |
| 6g — Perfil, Ajustes, onboarding | ✅ Done and deployed (2026-07-28) — 2 migrations applied, Edge Function redeployed (v10); visual sign-off still recommended, see 6g notes | — |
| 6h — Home dashboard, responsive | ✅ Done and deployed (2026-07-28), migration applied; visual sign-off still recommended, see 6h notes | — |
| 6i — Game screen states + wide layout | ✅ Done (2026-07-28), no backend changes; visual sign-off still recommended, see 6i notes | — |
| 7 — Ending/account/offline/resilience polish | Not started | Stage 4, 6a |
| 8 — Accessibility/responsiveness/performance/release | Not started | Stages 1-7 |
