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

## Stage 1 — Design-system foundation

**Status:** in progress (2026-07-27) — reusable components done; typography
swap blocked on a download permission (see below).

**Goal:** introduce Marcellus/Spectral/Archivo typography and reusable
`ConfirmSheet`/numbered `ChoiceCard` components — built, not yet wired into
every screen.

**Non-goals:** no screen migrations yet (that's Stage 2+); spacing/radii/motion
tokens are already adequate and are **not** being redesigned, only reused.

**Done:**
- `lib/app/widgets/choice_card.dart` — numbered (Roman-numeral) choice card,
  same press-and-brighten interaction as the existing `ChoiceButton`. Not yet
  wired into `game_screen.dart` (that's Stage 4).
- `lib/app/widgets/confirm_sheet.dart` — `showConfirmSheet(...)`, a bottom-sheet
  destructive-confirmation replacing `showDialog`/`AlertDialog`. Not yet wired
  into any of the app's 4 existing confirmation call sites (that's Stage 2/4/5,
  done call-site by call-site).
- Tests: `test/app/widgets/choice_card_test.dart` (2 cases: Roman-numeral
  spelling for indices 1/2/4/9/40, label + tap), `test/app/widgets/
  confirm_sheet_test.dart` (5 cases: renders title/message/actions, resolves
  true on confirm, resolves false on cancel, resolves false on barrier-tap
  dismiss, `destructive: false` uses the gold accent instead of failure red).
  Full suite re-run after adding both: 588/588 passing, `analyze` clean.

**Blocked / needs your input before continuing this stage:**
- The typography swap (Georgia/system → Marcellus/Spectral) requires
  **downloading** the two open-source font files (Google Fonts, OFL license)
  to vendor under `assets/fonts/` — per this assistant's operating rules,
  downloading any file requires asking first in chat. Not done yet; asked
  separately from this document. Once approved: `pubspec.yaml` (font asset
  declarations), new `assets/fonts/`, `lib/app/design/typography.dart` (swap
  families), then wire into `SplashScreen` only per the "recommended first
  implementation slice" below.

**Backward compatibility:** N/A — additive components; typography swap is
visually total but mechanically inert (no domain/persistence impact).

**Acceptance criteria:** app still builds/runs/plays end-to-end unchanged;
new components render correctly in isolation. **Met so far** for the
components; typography portion still pending.

**Risk:** low.

---

## Stage 2 — Story discovery and library

**Goal:** migrate `WorldSelectScreen`/`StoryModuleScreen`/`CreateStoryScreen`
visuals; consolidate the 4 existing `AlertDialog` confirmations into
`ConfirmSheet`.

**Non-goals:** no gameplay-engine changes; multi-session freeform behavior and
story titles must survive unchanged (this is exactly what Stage 0's new test
guards against regressing).

**Files:** `world_select_screen.dart`, `story_module_screen.dart`,
`create_story_screen.dart`. No controller changes.

**Tests:** `test/app/story_resume_navigation_test.dart` must still pass
unmodified in behavior; add abandon/restart confirmation widget tests against
the new `ConfirmSheet`.

**Acceptance criteria:** all 3 story modules still list/resume/restart/abandon
correctly; visual parity with prototype sections `2a`/`2b`/`3a`-`3d`
(screen-layout only, no new mechanics).

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

**Goal:** collapsible header, numbered choices, redesigned `FateRoll` compact
presentation, image-bleed scene open. Progressive-disclosure logic stays
**unchanged** — it's already correct.

**Non-goals:** ending-counter / tone-display / narrator-retry-count (those
need small `GameController`/Edge-Function additions first — Stage 6/7).

**Files:** `game_screen.dart`, `status_bar.dart`, `fate_roll.dart`,
`atmosphere.dart`.

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

- **6a — Ending-discovery counter.** No decision needed (purely additive,
  already reusing `ResolutionNode.endings.length`). `GameController` getter +
  UI in the ending screen. **Good early win, can run before or alongside
  Stage 4.**
- **6b — Per-world visual theming.** Blocked by Decision E. `World.fromJson`
  new nullable fields → all 8 world JSONs → `AetherColors` per-world resolver
  → wired into `game_screen.dart`/`chargen_screen.dart`/library cards.
- **6c — Player-selectable tone.** Blocked by Decision C. New field + chargen
  step + `prompt_builder.ts` instruction + authored preview copy (15
  snippets: 5 worlds × 3 tones).
- **6d — Auth expansion.** Blocked by Decision D. `AuthPort` methods +
  Supabase Auth provider config + `account_screen.dart`/`splash_screen.dart` UI.
- **6e — Story-graph editor.** Blocked by Decision A. Own multi-week
  initiative, likely a separate app/tool — not scoped further in this document.
- **6f — Publishing/UGC.** Blocked by Decision B. Needs its own
  `V2_DATA_MIGRATION.md`-equivalent deep-dive before any code — not scoped
  further in this document.

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

## Recommended first implementation slice (within Stage 1)

**Typography-only, scoped to `SplashScreen`.**

- Swap `AetherType`'s `display`/`title`/`narration`/`body` families from
  Georgia/system-default to bundled Marcellus/Spectral.
- Wire the new typography into `splash_screen.dart` only — lowest-traffic,
  most self-contained screen (no `GameController` dependency, no persistence,
  no world-specific variability).
- Requires: `pubspec.yaml` font asset declarations + `assets/fonts/` (download
  and vendor the open-source font files).
- **Acceptance criteria:** `flutter analyze`/`flutter test` still green; splash
  renders Marcellus wordmark + Spectral tagline in the browser preview;
  reduced-motion behavior on `_TomePainter`'s shimmer unchanged; no other
  screen's typography changes yet.
- **Verification:** `tool/flutter.sh analyze && tool/flutter.sh test`, then a
  manual preview-pane check of `SplashScreen`.
- **Why this one:** visibly moves toward V2's stated goal, zero domain/
  persistence/content risk, establishes the font-bundling pattern every later
  stage reuses, can't regress gameplay (`SplashScreen` has no game state).

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
| 1 — Design-system foundation | In progress: components done, typography pending download approval | — |
| 2 — Story discovery and library | Not started | Stage 1 |
| 3 — Character creation V2 | Not started | Stage 1 |
| 4 — Gameplay reading experience | Not started | Stage 1 |
| 5 — Character/inventory/story sheets | Not started | Stage 1 |
| 6a — Ending-discovery counter | Not started | — (can run anytime) |
| 6b — Per-world visual theming | Not started | Decision E |
| 6c — Player-selectable tone | Not started | Decision C |
| 6d — Auth expansion | Not started | Decision D |
| 6e — Story-graph editor | Not started | Decision A |
| 6f — Publishing/UGC | Not started | Decision B |
| 7 — Ending/account/offline/resilience polish | Not started | Stage 4, 6a |
| 8 — Accessibility/responsiveness/performance/release | Not started | Stages 1-7 |
