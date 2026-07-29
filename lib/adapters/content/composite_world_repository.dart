// prefer_initializing_formals is disabled here: the fields are private and
// Dart forbids private *named* parameters, so `this._field` initializing
// formals aren't usable for this public named-argument constructor — same
// reasoning as `campaign_playtest_controller.dart`'s own file-level ignore.
// ignore_for_file: prefer_initializing_formals
import '../../core/authoring/campaign_materializer.dart';
import '../../core/world/world.dart';
import '../../ports/campaign_draft_repository_port.dart';
import '../../ports/world_repository_port.dart';

/// Resolves a world slug against the bundled assets first, falling back to a
/// published `campaign_drafts` row (admin-authored official, Admin Stage 3,
/// or an ordinary published community novel, Admin Stage 4) when the assets
/// don't recognize it — the one integration point that lets
/// `GameController.start`/`loadWorldInfo` play a DB-sourced campaign without
/// knowing the difference, since both paths end up handing back a plain
/// [World].
class CompositeWorldRepository implements WorldRepositoryPort {
  CompositeWorldRepository({
    required WorldRepositoryPort assets,
    required CampaignDraftRepositoryPort campaignDrafts,
  })  : _assets = assets,
        _campaignDrafts = campaignDrafts;

  final WorldRepositoryPort _assets;
  final CampaignDraftRepositoryPort _campaignDrafts;

  @override
  Future<World> loadWorld(String slug) async {
    try {
      return await _assets.loadWorld(slug);
    } catch (_) {
      // Not a bundled asset — fall through to the published-campaign lookup
      // below rather than surfacing whatever asset-loading error this was
      // (a missing file is the expected case here, not a real failure).
    }

    final draft = await _campaignDrafts.loadPublishedBySlug(slug);
    if (draft == null) {
      throw StateError('No world or published campaign found for slug "$slug"');
    }
    World? baseWorld;
    final baseWorldSlug = draft.baseWorldSlug;
    if (baseWorldSlug != null) {
      baseWorld = await _assets.loadWorld(baseWorldSlug);
    }
    return materializeOfficialWorld(draft, baseWorld: baseWorld);
  }
}
