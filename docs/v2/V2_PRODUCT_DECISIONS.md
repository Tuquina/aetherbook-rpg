# V2 Product Decisions

Status: **living document**. Created 2026-07-27 from the V1→V2 architecture audit
(design source: `Aetherbook Redesign.dc.html`, the Claude Design handoff bundle at
`G:\Documentos Fernando\Claude Code\Designs\`). Every decision below blocks at
least one implementation stage in `V2_IMPLEMENTATION_PLAN.md` — do not start the
stage a decision blocks until that decision's status is **Accepted** or
**Rejected/Deferred**.

Do not silently assume an answer to any decision marked **Pending** here. If a
future session is asked to implement something that depends on a Pending
decision, stop and ask before writing code.

---

## Decision A — Story-graph editor (visual campaign authoring tool)

**Status:** **Deferred (2026-07-27)** — user confirmed, alongside Decision B.
Not scheduled; revisit only if explicitly requested as its own initiative.

**Context.** The prototype's section 9 (`9a`–`9j`) specs a full visual editor —
web node-graph canvas + a mobile list-based equivalent — for authoring
`StoryGraph`/`StoryNode`/`StoryChoice`/`Ending`/`Gate` content, including a
pre-publish lint pass and a live playtest mode with forced dice results and
flag toggles.

**Current behavior.** Campaigns are hand-authored JSON in `assets/worlds/*.json`,
written by a developer (via Claude Code) and checked by `test/content/*`.

**Prototype behavior.** Non-technical authoring UI inside the product (web +
mobile), with a save/validate/publish pipeline.

**Options:**
1. Build it as a new screen/surface inside the Flutter app.
2. Build it as a separate web tool (e.g. Deno/Vite) that emits the same JSON
   schema and never ships in the mobile client.
3. Don't build it now — keep authoring via Claude Code + hand-written JSON,
   revisit as its own initiative later.

**Recommendation:** (3) for V2. If ever pursued, (2) over (1) — an authoring
tool with a debug-capable "force this dice roll" playtest mode has no business
inside the same binary players use to actually play, and the domain model
(`Gate`, `Ending.difficultyBySoftRequirementsMet`, the 4 `StoryNode` subtypes,
`StoryGraph.unknownTargetIds()`) already supports everything the mockup shows —
so nothing is lost by deferring; this is a UI/tooling investment, not a
domain-mechanic gap.

**Consequence of accepting now:** multi-week detour before any V2 visual work
ships; introduces a debug-capable `GameController` surface (playtest mode) that
must be firewalled from production builds.

**Consequence of deferring:** campaign authoring stays developer-mediated
(current, working model) until explicitly greenlit as its own initiative.

**Blocks:** Stage 6e in the implementation plan (not otherwise scheduled).

---

## Decision B — Publishing / user-generated-content library

**Status:** **Deferred (2026-07-27)** — user confirmed, alongside Decision A.
Not scheduled; no RLS/schema/legal work is to be attempted without this
being explicitly revisited first.

**Context.** Section `10c` (a rights/licensing notice shown "at publish time")
and the "Publicar" button in `9a` imply other players can read stories a user
authored.

**Current behavior.** Every table's RLS policy is `auth.uid() = user_id` —
single-owner, no concept of a story visible to anyone but its creator. No
moderation, reporting, or multi-tenant content model of any kind exists.

**Prototype behavior.** Publish → visible in a shared library; author retains
attribution and can unpublish; explicit non-exclusive license grant text;
originality attestation required at publish time.

**Options:**
1. Build the full UGC publishing platform now.
2. Build only the story-graph editor (Decision A) for the user's own
   authoring, with no cross-user publishing.
3. Explicitly mark out of scope for V2.

**Recommendation:** (3). This requires a new RLS model, a moderation/reporting
story, a legal ToS review, and abuse-handling (impersonation, copyright,
harassment) with zero groundwork today. It is also logically downstream of
Decision A — publishing needs an editor to publish from.

**Consequence of accepting:** the single largest risk item in the entire V2
effort — could stall the redesign behind legal/infra work unrelated to its
actual goal (a better reading experience).

**Consequence of rejecting:** sections `9i`/`10c`'s "publish" affordances in the
mockup are treated as illustrative of a possible future product, not a V2
requirement. No code, schema, or RLS change is attempted for this.

**Blocks:** Stage 6f in the implementation plan (not otherwise scheduled; would
need its own `V2_DATA_MIGRATION.md`-equivalent deep-dive before any code).

---

## Decision C — Player-selectable narrative tone

**Status:** **Accepted, full mechanic (2026-07-27)** — user chose option (1),
not the cheaper display-only option this document recommended. Implementing
as a real new mechanic: chargen step + new field + `prompt_builder.ts`
instruction + authored preview/tone copy for every world. Scoped as its own
Stage 6c slice (see `V2_IMPLEMENTATION_PLAN.md`) — narrator-contract and
Edge Function changes, not bundled with anything else.

**Context.** The prototype's interactive JS mock (chargen state) includes a
tone selector (épico / íntimo / ácido) with per-world preview copy.

**Current behavior (confirmed, not inferred).** `tone` is 100% AI-emitted,
per-turn, display-only, and has **zero mechanical effect** anywhere in the
engine. It isn't even reliably persisted: `game_state_mappers.dart` hardcodes
`Turn.tone` back to `''` on session resume, falling back to the static
`World.tone` string. No widget in `lib/app/*.dart` currently reads/renders
`GameController.tone` at all, despite the getter existing.

**Prototype behavior.** Player picks a tone at chargen; it visibly shapes
narrator voice for the rest of the story.

**Options:**
1. Implement as a real new mechanic: chargen step + new `Character`/
   `GameSession` field + a `prompt_builder.ts` instruction block per tone +
   authored preview copy (5 worlds × 3 tones = 15 new snippets).
2. Treat as prototype flavor only — don't implement.
3. Implement only the *display* of the already-existing AI-emitted tone
   (near-zero cost — the data already flows, it's just never shown).

**Recommendation:** (3) first — cheap, real, uses data that already exists.
Defer (1) as its own explicitly-scoped Stage-6 slice if wanted later, since it
is a narrator-contract change requiring genuinely new authored content per
world.

**Consequence of accepting (1) now:** narrator-contract change + new content
requirement before any visual work ships.

**Consequence of deferring:** no loss — the AI inferring tone contextually
turn-to-turn is arguably better UX for genre fiction than asking the player to
pre-declare a tone at chargen.

**Blocks:** Stage 6c in the implementation plan.

---

## Decision D — Auth expansion: Google OAuth + email/password

**Status:** **Accepted, option (2) — discontinue magic-link (2026-07-27).**
User explicitly overrode this document's recommendation (keep magic-link
alongside the new methods): "Agrega Google OAuth y pass con contraseña,
quitando el enlace mágico. Total todavía estamos en etapa de pruebas, no hay
usuarios reales más que yo hasta ahora." Recorded as the reasoning — no
migration-safety concern applies while there are no real linked users yet.
Scoped as Stage 6d — **code finished 2026-07-27** (`AuthPort`/
`SupabaseAuthAdapter`/`FakeAuthAdapter`/`account_screen.dart` all rewritten,
631/631 tests passing). **External dependencies the assistant cannot
complete alone, still outstanding:**
1. A Google Cloud Console OAuth client (ID + secret) configured as a
   provider in the Supabase Auth dashboard.
2. **"Allow manual linking"** enabled in that same dashboard —
   `SupabaseAuthAdapter.signInWithGoogle` uses `linkIdentity` (not
   `signInWithOAuth`) specifically to attach Google to the current
   anonymous session instead of switching to a separate one, and
   `linkIdentity` requires this setting or every attempt fails.

Email/password (sign-up/sign-in/reset) needs no dashboard changes beyond
what magic-link already had — it's ready as soon as this code deploys.

**Context.** Sections `10b`/`10d` assume Google OAuth and email/password
sign-in/sign-up/reset exist. The prototype's own annotation on `10d` admits:
*"Nada de esto existe todavía: hoy AuthPort sólo expone continueWithEmail por
enlace."*

**Current behavior.** Anonymous session by default (CLAUDE.md's documented
model); **opt-in** magic-link email continuation
(`AuthPort.continueWithEmail`) is the only account-linking path that exists.

**Prototype behavior.** Google OAuth + password signup/signin/reset,
*discontinuing* the magic link entirely.

**Options:**
1. Add Google OAuth + password auth **alongside** the existing magic-link path.
2. Add them and remove magic-link entirely (matches the prototype literally).
3. Defer — keep magic-link only.

**Recommendation:** (1) if pursued at all. Never remove an existing sign-in
path outright without confirming no linked users depend on it — magic-link is
CLAUDE.md's own documented anonymous-first model, and removing it is a product
regression, not a redesign. This is additive to `AuthPort`, low domain-risk,
but real scope (new Supabase Auth provider config, new port methods, new UI).

**Consequence of accepting:** new `AuthPort` methods
(`signInWithGoogle`/`signUpWithPassword`/`signInWithPassword`/`resetPassword`
or similar), Supabase Auth dashboard configuration (Google OAuth client),
password-reset email flow, new UI states in `account_screen.dart`/
`splash_screen.dart`.

**Consequence of rejecting:** splash/account screens get the V2 visual refresh
(section `10a`) without new auth methods; "Entrar"/"Crear cuenta" stay out of
scope; magic-link remains the only account path.

**Blocks:** Stage 6d in the implementation plan.

---

## Decision E — Per-world visual theming: lock the token values

**Status:** **Accepted, option (1) — adopted as-is (2026-07-27).** Implemented
in Stage 6b: `World` gained nullable `themeAccentHex`/`themeBaseHex`/
`themeSecondaryHex` (raw hex strings — `core/` stays Flutter-free),
`lib/app/design/world_theme.dart`'s `WorldTheme.forWorld` resolves them to
real `Color`s falling back to the existing global palette, and
`AetherBackground` gained a `base` parameter so the per-world tint shows in
the backdrop gradient even with `particles: false` (as on `GameScreen`) —
`accent`-only wiring would have been invisible there. All 8 world JSON files
now declare the table below. **Not yet done:** the title-treatment
(font-tracking per world) and background-texture (fog/scanline/grain
`CustomPainter`s) dimensions from the original prototype, and wiring the
per-world accent into story-library cards/chargen (currently still
module-accent-colored, which is a separate, pre-existing system) — left
for a follow-up pass, not silently dropped.

**Context.** Section `4a` proposes 5 named token sets (accent / base /
secondary / title-treatment / background-texture), one per world family. This
requires new fields on every world JSON file — currently **no per-world visual
metadata exists at all**; only per-*module* accents (`ember`/`arcane`/`nova`)
exist in `design/tokens.dart` today. GDD §9 describes per-world theming
aspirationally; it was never built.

**Proposed values, extracted directly from the prototype** (already
internally consistent with the existing global palette — `gold`, `success`,
`failure` hex values are reused verbatim):

| World | Accent | Base | Secondary | Title treatment | Texture |
|---|---|---|---|---|---|
| Isekai | `#EAC978` (existing gold) | `#15120F` (existing ink) | `#9B5DE0` (existing nova) | Marcellus, normal tracking | radial warm glow from top |
| Xianxia | `#7FD4C1` | `#0F1D1A` | `#D8B65E` (rank) | Marcellus, wide tracking | layered horizontal fog |
| Superhéroes | `#F0564A` | `#170F0E` | `#4C8BF0` (ally) | Archivo 800, uppercase, small-caps feel | hard diagonal, no soft gradient |
| Cyberpunk | `#55E0F0` | `#0C1016` | `#FF4FA3` (alert) | Archivo 700, tracked, uppercase | 3px scanline + neon halo |
| Post-apocalíptico | `#B8B27A` | `#161611` | `#D2762F` (danger) | Marcellus, desaturated | flat grain, no shine |

**Options:**
1. Adopt these values as-is.
2. Adjust specific values before locking (record the change here with a date
   and reason).
3. Defer per-world theming entirely (fold into Decision-independent low
   priority).

**Recommendation:** (1) — the prototype's own designer already reconciled
these against the real global tokens; re-deriving them from scratch adds
nothing. Confirm and move on.

**Consequence of accepting:** additive, nullable `World` fields with a
safe fallback to the current global gold theme when absent — zero migration
risk regardless of which specific hex values are used.

**Blocks:** Stage 6b in the implementation plan.

---

## Decisions already resolved (no further confirmation needed)

- **Design bundle is a reference, not application code.** `Aetherbook
  Redesign.html`/`.dc.html`, the handoff zip, and its `assets/scene-*.png`
  reference images must never be committed into this repo.
- **Stage 0 is unconditionally safe to execute** regardless of any Pending
  decision above — it adds test coverage only, touches no product code.
  Already done; see `V2_IMPLEMENTATION_PLAN.md`.
