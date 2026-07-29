// Pure mapping between CampaignDraft and its `campaign_drafts` row shape —
// same split as game_state_mappers.dart: free of any Supabase import so it's
// unit-testable without a network call.

import '../../core/authoring/campaign_draft.dart';
import '../../core/narrative/story_graph.dart';

Map<String, Object?> campaignDraftToRow(CampaignDraft draft) {
  return {
    if (draft.id != null) 'id': draft.id,
    'author_id': draft.authorId,
    'slug': draft.slug,
    'title': draft.title,
    'synopsis': draft.synopsis,
    'base_world_slug': draft.baseWorldSlug,
    'status': draft.status.toString(),
    'content_warnings': draft.contentWarnings,
    'cover_image_url': draft.coverImageUrl,
    'estimated_duration_minutes': draft.estimatedDurationMinutes,
    'ai_runtime_required': draft.aiRuntimeRequired,
    'graph': draft.graph.toJson(),
    'node_titles': draft.nodeTitles,
    'official_module': draft.officialModule?.toString(),
    'license_accepted_at': draft.licenseAcceptedAt?.toIso8601String(),
    'published_at': draft.publishedAt?.toIso8601String(),
  };
}

CampaignDraft campaignDraftFromRow(Map<String, dynamic> row) {
  return CampaignDraft(
    id: row['id'] as String,
    authorId: row['author_id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String? ?? '',
    synopsis: row['synopsis'] as String? ?? '',
    baseWorldSlug: row['base_world_slug'] as String,
    status: CampaignDraftStatus.fromString(row['status'] as String? ?? 'draft'),
    contentWarnings: _stringList(row['content_warnings']),
    coverImageUrl: row['cover_image_url'] as String?,
    estimatedDurationMinutes:
        (row['estimated_duration_minutes'] as num?)?.toInt(),
    aiRuntimeRequired: row['ai_runtime_required'] as bool? ?? true,
    graph: _graphFromRow(row['graph']),
    nodeTitles: _stringMap(row['node_titles']),
    officialModule: CampaignOfficialModule.fromString(row['official_module'] as String?),
    licenseAcceptedAt: _dateTime(row['license_accepted_at']),
    publishedAt: _dateTime(row['published_at']),
    createdAt: _dateTime(row['created_at']),
    updatedAt: _dateTime(row['updated_at']),
  );
}

CampaignDraftSummary campaignDraftSummaryFromRow(Map<String, dynamic> row) {
  final graph = row['graph'];
  final nodeCount =
      graph is Map && graph['nodes'] is Map ? (graph['nodes'] as Map).length : 0;
  return CampaignDraftSummary(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String? ?? '',
    baseWorldSlug: row['base_world_slug'] as String,
    status: CampaignDraftStatus.fromString(row['status'] as String? ?? 'draft'),
    coverImageUrl: row['cover_image_url'] as String?,
    nodeCount: nodeCount,
    updatedAt: _dateTime(row['updated_at']) ?? DateTime.now(),
    officialModule: CampaignOfficialModule.fromString(row['official_module'] as String?),
  );
}

StoryGraph _graphFromRow(Object? value) {
  if (value is! Map) return const StoryGraph(startNodeId: '', nodes: {});
  final graphJson = value.cast<String, dynamic>();
  if ((graphJson['nodes'] as Map?)?.isEmpty ?? true) {
    return const StoryGraph(startNodeId: '', nodes: {});
  }
  return StoryGraph.fromJson(graphJson);
}

DateTime? _dateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.parse(value);
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const [];
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k as String, v as String));
  }
  return const {};
}
