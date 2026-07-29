import '../world/world.dart';
import 'campaign_draft.dart';

/// Turns an admin-authored official [CampaignDraft] (Admin Stage 3, project
/// decision 2026-07-31) into the real, playable [World]
/// `GameController.start` needs — the same shape a bundled
/// `assets/worlds/*.json` world already produces, so nothing downstream
/// (chargen, the engine, the narrator prompt) has to know whether a world
/// came from a file or from this table.
///
/// [baseWorld] is required exactly when [draft] borrows its attribute
/// system via `baseWorldSlug` rather than declaring its own — the caller
/// (an adapter, since only it can actually fetch a bundled world) is
/// responsible for loading it first. A [draft.customWorld] world is used
/// as-is instead.
///
/// The draft's own metadata always wins over the underlying world's: a
/// published campaign's title/synopsis/duration/content-warnings are what
/// the author actually set on this specific campaign, not whatever the
/// borrowed base world happened to declare. [World.storyGraph] is always
/// replaced with [CampaignDraft.graph] — that's the one this draft was
/// actually written against, never the base/custom world's own (always
/// empty) graph.
World materializeOfficialWorld(CampaignDraft draft, {World? baseWorld}) {
  final base = draft.customWorld ?? baseWorld;
  if (base == null) {
    throw ArgumentError(
      'materializeOfficialWorld: draft "${draft.slug}" has no customWorld and no baseWorld was supplied',
    );
  }
  return base.copyWith(
    slug: draft.slug,
    name: draft.title.isNotEmpty ? draft.title : base.name,
    catalogDescription: draft.synopsis.isNotEmpty ? draft.synopsis : base.catalogDescription,
    estimatedDurationMinutes: draft.estimatedDurationMinutes ?? base.estimatedDurationMinutes,
    contentWarning:
        draft.contentWarnings.isNotEmpty ? draft.contentWarnings.join(', ') : base.contentWarning,
    storyGraph: draft.graph,
    aiRuntimeRequired: draft.aiRuntimeRequired,
  );
}
