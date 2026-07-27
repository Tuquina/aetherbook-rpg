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

**Status:** in progress (2026-07-27) — dialog consolidation done; the
broader visual reflow (card layout, "continue" hierarchy, etc. per prototype
`2a`/`2b`/`3a`-`3d`) is still open, see below.

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

**Still open in this stage (deliberately not attempted yet):** the broader
visual reflow — richer story cards, "continue" as the clear primary action,
grid/library presentation per prototype `2a`/`2b`/`3a`-`3d`. This needs
either a `V2_DESIGN_SYSTEM.md` (spacing/layout conventions beyond what
`AetherSpace`/`AetherRadius` already give) or explicit sign-off on specific
layout choices before it's a well-scoped, reviewable change rather than a
large subjective rewrite — not done silently as part of this pass.

**Tests:** `test/app/story_resume_navigation_test.dart` must still pass
unmodified in behavior; add abandon/restart confirmation widget tests against
the new `ConfirmSheet`.

**Acceptance criteria:** all 3 story modules still list/resume/restart/abandon
correctly; visual parity with prototype sections `2a`/`2b`/`3a`-`3d`
(screen-layout only, no new mechanics). **Dialog consolidation done and
verified; visual reflow still open.**

**Risk:** low.

---

## Stage 3 — Character creation V2

**Goal:** reflow `chargen_screen.dart` into the prototype's step structure,
reusing real per-world origins/tags/vows/items — **never** the mockup's
hardcoded Isekai sample data (`oficinista`/`invisible`/etc. are illustrative
only).

**Non-goals:** no tone step (Decision C not yet accepted); no new `Character`
fields.

**Files:** `chargen_screen.dart` only.

**Tests:** existing chargen validation tests must stay green; add a widget
test per new step. Explicitly test against both schema shapes that must
render correctly: `xianxia_lianshu` (structured milestone ranks) and a
freeform genre (simpler flat attributes).

**Risk:** low-medium — most complex screen to reflow without breaking
world-specific field variability across all 8 worlds.

---

## Stage 4 — Gameplay reading experience

**Status:** in progress (2026-07-27) — dialog consolidation done early
(low-risk, decision-free); the rest (header, choice cards, `FateRoll`,
scene-image treatment) is still open, same reasoning as Stage 2's remaining
visual reflow — needs layout decisions locked down first.

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

**Still open in this stage:** collapsible/adaptive header, numbered
`ChoiceCard` actually wired in (built in Stage 1, unused until now), redesigned
compact `FateRoll`, image-bleed scene-open treatment. Same blocker as Stage
2's remaining work — these are real layout/interaction redesigns, not
mechanical swaps, and deserve either a design-system doc or explicit
sign-off on the specific choices before being attempted as one change.

**Tests:** the 3 existing cases in `test/widget_test.dart` must stay green
with unchanged *behavior* (only visuals change); add a header-collapse widget
test.

**Backward compatibility:** curated (`ai_runtime_required:false`), hybrid, and
freeform paths must all still render identically — every mode routes through
this screen.

**Risk:** medium — highest-traffic screen, most animation/scroll-linked logic.

---

## Stage 5 — Character, inventory, and story sheets

**Goal:** convert `InventoryScreen` and a new `CharacterSheetSheet`
(consolidating `StatusBar`'s inline stats) into bottom sheets; add a
story-menu sheet (continue/my-stories/abandon) replacing ad-hoc navigation.

**Files:** `inventory_screen.dart` → sheet, new `character_sheet_sheet.dart`.

**Tests:** `test/app/inventory_screen_test.dart` updated to sheet
presentation, same assertions.

**Risk:** low.

---

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
- **6c — Player-selectable tone.** Decision C accepted, **full mechanic**
  (user explicitly chose this over the cheaper display-only option). Not
  started yet. New field + chargen step + `prompt_builder.ts` instruction +
  authored preview copy (15 snippets: 5 worlds × 3 tones) — narrator-contract
  change, needs an Edge Function redeploy to actually take effect live.
- **6d — Auth expansion.** Decision D accepted, **discontinuing magic-link**
  (user's explicit choice — see `V2_PRODUCT_DECISIONS.md`). Not started yet.
  `AuthPort` methods + `SupabaseAuthAdapter` + `account_screen.dart`/
  `splash_screen.dart` UI can all be finished in code; **enabling Google as
  an OAuth provider itself requires the user to configure a Google Cloud
  Console OAuth client and enter it into the Supabase Auth dashboard** — not
  something this assistant can do unilaterally.
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

- `CLAUDE.md`: add a pointer to `docs/v2/V2_DESIGN_SYSTEM.md` (not yet
  created — create only once Stage 1 actually needs it) and update the phase
  marker as each stage ships.
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
| 2 — Story discovery and library | Partial: dialog consolidation done (2026-07-27), visual reflow still open | Stage 1 |
| 3 — Character creation V2 | Not started | Stage 1 |
| 4 — Gameplay reading experience | Partial: dialog consolidation done (2026-07-27), header/choices/FateRoll/image still open | Stage 1 |
| 5 — Character/inventory/story sheets | Not started | Stage 1 |
| 6a — Ending-discovery counter | ✅ Done (2026-07-27) | — |
| 6b — Per-world visual theming | ✅ Done (2026-07-27) | — |
| 6c — Player-selectable tone | Accepted (full mechanic), not started | — |
| 6d — Auth expansion | Accepted (drop magic-link), not started; Google OAuth needs user's Cloud Console setup | — |
| 6e — Story-graph editor | Deferred (2026-07-27) | — |
| 6f — Publishing/UGC | Deferred (2026-07-27) | — |
| 7 — Ending/account/offline/resilience polish | Not started | Stage 4, 6a |
| 8 — Accessibility/responsiveness/performance/release | Not started | Stages 1-7 |
