# V2 Design System — Stage 2/4 layout decisions

Created 2026-07-27, once Stage 2's and Stage 4's visual reflow actually
shipped. This is the record `V2_IMPLEMENTATION_PLAN.md` said was needed
before either stage's remaining work could be "well-scoped" instead of "a
large subjective rewrite" — written *after* the decisions were made and
implemented, not as an upfront spec, since the decisions themselves were
small and low-risk enough to make directly. Read this alongside
`V2_PRODUCT_DECISIONS.md` (the decisions that needed your sign-off) and
`V2_IMPLEMENTATION_PLAN.md` (stage status).

The design source is the Claude Design prototype, `Aetherbook Redesign.dc.html`
inside `Aetherbook Mobile Redesign-handoff.zip` (never committed here — see
`V2_GAP_ANALYSIS.md` §1). Section refs below (`§2a`, `§1a`, ...) point at that
file's own numbered subsections.

---

## 1. Stage 4 — Gameplay reading experience

### 1a. Collapsible header

**Shipped:** `StatusBar` gained a `collapse` parameter (`double`, 0 =
expanded/default, 1 = fully collapsed). `GameScreen` drives it directly from
the reading scroll offset (`_onScroll`, `_headerCollapseDistance = 90.0`
logical pixels) — no separate animation clock, same philosophy as the
prototype's own scroll-bound `headerH`/`opacity` bindings. At `collapse: 1`:

- The EXP bar + resource pills fold away (`Align(heightFactor: ...)` +
  `Opacity`, both driven by the same continuous value — no
  `AnimationController` needed since scroll position already interpolates).
- A 2px EXP-only rail fades in along the header's bottom edge in their place.
- The identity row (back / world+name+level / inventory / codex) never
  moves or resizes.

**Deliberately not shipped — the header does not float over the scene
image.** The prototype's §1a has the header absolutely positioned over the
scrolling content, transparent at the top (image visible through it) and
solidifying to an opaque `AetherColors.surface` as the reader scrolls. That
requires either measuring the expanded header's real height at runtime
(varies per world: EXP disabled, or a different number of resource pills) or
hardcoding a padding estimate that would drift out of sync — meaningfully
higher risk for a "highest-traffic screen" (the plan's own risk note) than
the value it adds. The prototype's own `dv-next` line for this section
independently suggests trying "a version of 1a with the header always
minimal" as a *separate* next step — i.e. even the prototype's author treated
the floating-over-image behavior as separable from the collapse mechanic
itself. Revisit only if you want the overlap look specifically; the
collapse mechanic that ships today is the same interaction, just laid out as
a normal (non-overlapping) column sibling above the scene image instead.

### 1b. Numbered choice cards

**Shipped:** `ChoiceCard` (built in Stage 1, unused until now) is wired into
`_ChoicesBar` for every *enumerated* decision point — curated story choices,
hub activities, and endings share one running Roman-numeral sequence (I, II,
III, ... across all three sources, since the player reads "Tu decisión" as
one list, not three); freeform AI-suggested choices get their own I..N.
`ChoiceButton` (unchanged) stays reserved for single, non-enumerated actions:
the "Continuar" fallback when the AI returns no suggestions, and "Volver al
menú" in `_EndOfStory` — neither is "one of several options to pick", so
numbering either would misrepresent it as a choice among alternatives.

### 1c. FateRoll compact presentation

**Already done — no changes needed.** Reading `fate_roll.dart` against the
prototype's dice-check markup (hexagonal d20 + `attribute + d20 = total`
equation tiles + a three-band meter with a landing-position indicator + a
band legend + a result chip with the difficulty and EXP) showed the existing
implementation is already a near 1:1 translation, built earlier than this
audit realized. Verified, not rebuilt.

### 1d. Image-bleed scene open

**Shipped:** `_SceneImage` moved from an inline `AspectRatio(4/3)` card
*after* the Fate Roll to a full-bleed 260px-tall hero at the very top of the
scroll view (before the Fate Roll), edge-to-edge (no padding, no rounded
corners on mobile — automatically gets the `_ReadingFrame`'s rounded top
corners for free on web/tablet, since that frame already `ClipRRect`s
everything inside it). A bottom gradient (`transparent → ~80% ink → solid
ink`, stops at 0/0.75/1.0) dissolves it into the reading background instead
of stopping at a hard card edge. `_NarrationView`'s padding moved from the
whole scrollable column onto just the text/FateRoll portion, so the image is
the one element that bleeds past it.

**Deliberately not shipped:** the prototype's `-96px` negative-margin overlap
(content pulled up to visually sit over the image's fading tail). The
gradient alone already gives a seamless transition; the overlap is a
cosmetic embellishment on top of it, and negative margins inside a
`Column`/`SingleChildScrollView` are easy to get subtly wrong (paint-order
overlap vs. layout-space double-counting) for a gain that's marginal next to
the risk. Worth trying as a small follow-up, not bundled into this pass.

---

## 2. Stage 2 — Story discovery and library

The prototype's single unified "biblioteca" (§2b: one screen mixing
in-progress tomes and closed-world cards) does not map onto this app's
architecture, and that's intentional, not a gap to close: CLAUDE.md's three
story modules (curated / hybrid / freeform) behave differently enough
(freeform allows several simultaneous sessions per world; curated/hybrid
allow exactly one) that merging their navigation into one flat list would be
a genuine information-architecture change, not a visual reflow — explicitly
out of Stage 2's non-goals ("no gameplay-engine changes"). What shipped
instead reinterprets each prototype section's *intent* inside the existing
module → module-screen structure.

### 2a. "Retomar es la acción principal" → `WorldSelectScreen`'s continue-hero

**Shipped:** `_ContinueHero`, shown above the module picker whenever
`GameController.isReady` is true (the same in-memory-session check
`_select`'s back-arrow-resume branch already used) — the session already
loaded gets top billing instead of waiting to be re-found inside its own
module. Carries the world's own Stage-6b accent (`WorldTheme.forWorld`),
not a module accent, since at this point it's one specific story. No new
persistence or controller API needed — this is a read of state that already
existed.

### 2b. "Mundos por abrir" grid → `CreateStoryScreen`'s genre picker

**Shipped:** the 5 freeform genres moved from a vertical list of `StoryCard`s
to a 2-column `GridView.count` of `_GenreGridCard` (icon + name + the
world's own one-line `tone` as blurb), matching the prototype's grid density
for "5 mundos" (there are exactly 5 freeform genres, same count as the
mockup). Icons are a small presentation-only map keyed by `World.slug`
(`_genreIcons`), same pattern as `story_module_screen.dart`'s existing
`_themeLabels` map — purely UI, never blocks a world from being playable if
a future genre isn't in the map (falls back to a generic icon).
`StoryCard` itself is no longer used by this screen (it now only serves
`StoryModuleScreen`) but stays exported — no reason to delete a component
still doing its job elsewhere.

"Tus historias" keeps its list presentation (already close to the
prototype's "tomos vivos" card language) but both it and `StoryCard` gained
a small icon-tile treatment (see below) for visual consistency with the new
grid and hero cards.

### 2c. Richer story cards → icon tiles, not cover art

**Shipped:** `StoryCard` (used by `StoryModuleScreen`) and `_SavedStoryCard`
(used by `CreateStoryScreen`'s "Tus historias") both replaced their old
3px accent rail with a 44px icon-in-circle tile — `StoryCard` uses its
parent module's icon (`style.icon`, passed in), `_SavedStoryCard` uses
`play_arrow_rounded` (a "this resumes" cue, matching `_ContinueHero`'s own
icon). This is the same tile language `_ModuleCard` and `_ContinueHero`
already established, so every tappable card in the story-select flow now
reads as one visual family.

**Deliberately not shipped:** per-story cover imagery, which is what the
prototype's list rows actually use (a 50-58px scene screenshot per campaign).
There is no per-campaign "cover image" concept anywhere in the content
schema — `assets/worlds/*.json` describes mechanics and prose, not branding
assets, and the only imagery the engine generates (`generate-image`,
CLAUDE.md §3) is per-*turn*, not a stable campaign identity. Adding one would
be a content-schema change, not a visual reflow — out of scope here, and
not obviously worth the authoring burden (one hand-picked or generated cover
per world) for a picker screen. Flagging as a real gap if a future session
wants richer library cards, not silently dropped.

---

## 3. What this doc deliberately does not cover

- Stage 3 (chargen V2 reflow) and Stage 5 (character sheet / inventory / story
  menu → bottom sheets) — not attempted in this pass; still need their own
  scoping when picked up.
- Per-world theming reaching story-library cards/chargen (Decision E's
  explicitly deferred follow-up, `V2_IMPLEMENTATION_PLAN.md` Stage 6b) —
  `_ContinueHero` is the one exception (it already reads `WorldTheme` since
  it's showing one specific world), everything else in Stage 2 still uses
  module accents (ember/arcane/nova), unchanged.
- Background-texture and title-treatment tokens (fog/scanline/grain painters,
  per-world font tracking) from Decision E's table — still not built anywhere.
