import '../narrative/story_graph.dart';
import '../world/world.dart';

/// A player-authored hybrid campaign (V2 design prototype §9a-9j), before or
/// after publishing. Reuses [StoryGraph] as-is for [graph] — a draft's node
/// content is exactly the same `StoryNode`/`StoryChoice`/`Ending`/`Gate`
/// model every other campaign uses (CLAUDE.md §7, §11); only the surrounding
/// metadata (title, cover, publish status...) and where it's persisted are
/// new. Authored on top of its attributes/resources/colors/narrator-tone
/// system either way (§9f: "Define los atributos, los colores y el tono del
/// narrador") — either borrowed from an existing [baseWorldSlug] (every
/// community novel, the only option before admin authoring existed), or, for
/// an admin-authored official campaign, a fully custom one in
/// [customWorld] (project decision 2026-07-31: "permitir un sistema de
/// atributos propio desde cero"). Exactly one of the two is ever set — see
/// the `campaign_drafts_world_source_check` constraint. [customWorld] is
/// always built with a `null`/empty `storyGraph` — [graph] is this class's
/// own, single source of truth for the node graph, never duplicated inside
/// the custom world.
///
/// Immutable, same shape as [GameSession]: the editor produces new instances
/// via [copyWith], never mutates in place.
class CampaignDraft {
  const CampaignDraft({
    this.id,
    required this.authorId,
    required this.slug,
    this.title = '',
    this.synopsis = '',
    this.baseWorldSlug,
    this.customWorld,
    this.status = CampaignDraftStatus.draft,
    this.contentWarnings = const [],
    this.coverImageUrl,
    this.estimatedDurationMinutes,
    this.aiRuntimeRequired = true,
    required this.graph,
    this.nodeTitles = const {},
    this.officialModule,
    this.licenseAcceptedAt,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  }) : assert(
          (baseWorldSlug == null) != (customWorld == null),
          'exactly one of baseWorldSlug/customWorld must be set',
        );

  /// The persisted row's id (`campaign_drafts.id`), or `null` for a draft
  /// that only exists in memory (not saved yet).
  final String? id;

  final String authorId;

  /// URL-safe, globally unique identifier — see [slugify]. Assigned once at
  /// creation from the initial title and never changed by a title edit
  /// afterwards (a published campaign's URL shouldn't move under it).
  final String slug;

  final String title;
  final String synopsis;

  /// Which bundled world (`assets/worlds/$baseWorldSlug.json`) this draft
  /// borrows attributes/resources/theme/narrator tone from (§9f: "Define los
  /// atributos, los colores y el tono del narrador"). `null` when
  /// [customWorld] is set instead.
  final String? baseWorldSlug;

  /// A fully custom attribute/resource/theme/narrator-tone system, authored
  /// from scratch by an admin instead of borrowing one via [baseWorldSlug]
  /// (World Builder, Admin Stage 2). `null` for every ordinary community
  /// novel. Its `storyGraph` is always ignored/empty — [graph] is this
  /// draft's own graph.
  final World? customWorld;

  final CampaignDraftStatus status;

  /// e.g. `['violencia', 'muerte_de_un_personaje']` — free-form ids, shown
  /// to a reader who's opted into that warning (§9f).
  final List<String> contentWarnings;

  final String? coverImageUrl;
  final int? estimatedDurationMinutes;

  /// Whether this campaign must stay playable with the AI narrator off
  /// (§9f "Se puede jugar sin narrador de IA") — when `true`, the pre-publish
  /// checklist (§9i) requires every reachable outcome to carry its own
  /// `resultText`, the same contract `ai_runtime_required: false` worlds
  /// already enforce via `test/content/*`.
  final bool aiRuntimeRequired;

  final StoryGraph graph;

  /// Author-facing short title per node id ("El maestro del portón"), shown
  /// on every map/list card (§9a/§9d) — distinct from a node's own body text
  /// (narration/goal), and deliberately kept off `StoryNode` itself (see the
  /// migration's comment): the game engine never reads it, only this editor
  /// does. A node id with no entry here falls back to the id itself.
  final Map<String, String> nodeTitles;

  /// [id]'s display title, or [id] itself if none was set yet.
  String titleForNode(String id) => nodeTitles[id]?.trim().isNotEmpty == true
      ? nodeTitles[id]!
      : id;

  /// `null` for an ordinary community novel (published, it only ever shows
  /// up in "Explorar"). When set, this is an admin-authored official
  /// campaign that belongs in the real "Historias completas"/"Historias
  /// pre-armadas" catalog modules instead — only an admin
  /// ([isAdminEmail]) may ever set this, enforced by both the editor UI and
  /// `campaign_drafts`' RLS (`20260730_campaign_drafts_admin_official.sql`).
  final CampaignOfficialModule? officialModule;

  /// When the author accepted the publish-rights notice (§10c) — set once,
  /// on first publish, and never cleared by a later unpublish (the
  /// acceptance itself doesn't need to be re-shown for the same campaign).
  final DateTime? licenseAcceptedAt;

  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => status == CampaignDraftStatus.published;

  CampaignDraft copyWith({
    String? id,
    String? title,
    String? synopsis,
    String? baseWorldSlug,
    World? customWorld,
    CampaignDraftStatus? status,
    List<String>? contentWarnings,
    String? coverImageUrl,
    bool clearCoverImageUrl = false,
    int? estimatedDurationMinutes,
    bool? aiRuntimeRequired,
    StoryGraph? graph,
    Map<String, String>? nodeTitles,
    CampaignOfficialModule? officialModule,
    bool clearOfficialModule = false,
    DateTime? licenseAcceptedAt,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return CampaignDraft(
      id: id ?? this.id,
      authorId: authorId,
      slug: slug,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      baseWorldSlug: baseWorldSlug ?? (customWorld != null ? null : this.baseWorldSlug),
      customWorld: customWorld ?? (baseWorldSlug != null ? null : this.customWorld),
      status: status ?? this.status,
      contentWarnings: contentWarnings ?? this.contentWarnings,
      coverImageUrl:
          clearCoverImageUrl ? null : (coverImageUrl ?? this.coverImageUrl),
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      aiRuntimeRequired: aiRuntimeRequired ?? this.aiRuntimeRequired,
      graph: graph ?? this.graph,
      nodeTitles: nodeTitles ?? this.nodeTitles,
      officialModule:
          clearOfficialModule ? null : (officialModule ?? this.officialModule),
      licenseAcceptedAt: licenseAcceptedAt ?? this.licenseAcceptedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum CampaignDraftStatus {
  draft,
  published;

  static CampaignDraftStatus fromString(String raw) => switch (raw) {
        'published' => CampaignDraftStatus.published,
        _ => CampaignDraftStatus.draft,
      };

  @override
  String toString() => switch (this) {
        CampaignDraftStatus.draft => 'draft',
        CampaignDraftStatus.published => 'published',
      };
}

/// Which official catalog module an admin-authored [CampaignDraft] belongs
/// to (project decision 2026-07-30) — mirrors exactly the two non-freeform
/// branches `WorldSelectScreen.moduleFor` already classifies a [World] into
/// via `aiRuntimeRequired` (`false` -> [complete], `true` -> [hybrid]).
/// `null` on [CampaignDraft.officialModule] means an ordinary community
/// novel instead, visible only in "Explorar".
enum CampaignOfficialModule {
  complete,
  hybrid;

  static CampaignOfficialModule? fromString(String? raw) => switch (raw) {
        'complete' => CampaignOfficialModule.complete,
        'hybrid' => CampaignOfficialModule.hybrid,
        _ => null,
      };

  @override
  String toString() => switch (this) {
        CampaignOfficialModule.complete => 'complete',
        CampaignOfficialModule.hybrid => 'hybrid',
      };
}

/// A lightweight summary of one [CampaignDraft] — everything
/// `EditorLibraryScreen` needs to render a card, without loading the full
/// `graph` jsonb column (same "summary vs. full load" split as
/// `GameSessionSummary`/`SessionLibraryEntry` in `game_state_repository_port
/// .dart`, for the same reason: a graph can be large, a list screen doesn't
/// need it).
class CampaignDraftSummary {
  const CampaignDraftSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.baseWorldSlug,
    required this.status,
    this.coverImageUrl,
    required this.nodeCount,
    required this.updatedAt,
    this.officialModule,
  });

  final String id;
  final String slug;
  final String title;

  /// `null` for a draft built on a [CampaignDraft.customWorld] instead.
  final String? baseWorldSlug;
  final CampaignDraftStatus status;
  final String? coverImageUrl;
  final CampaignOfficialModule? officialModule;

  /// How many nodes the graph has so far — enough for a card's "N escenas"
  /// without loading the whole graph.
  final int nodeCount;
  final DateTime updatedAt;

  bool get isPublished => status == CampaignDraftStatus.published;
}

/// Lowercase, hyphen-separated, ASCII-only slug from a free-text [title] —
/// pure and deterministic so it's unit-testable without a database.
/// Uniqueness (appending a short suffix on collision) is the adapter's job,
/// since only it can check what's already taken.
String slugify(String title) {
  final normalized = title
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');
  final slug = normalized
      .replaceAll(RegExp(r"[^a-z0-9\s-]"), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');
  return slug.isEmpty ? 'historia' : slug;
}
