import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/authoring/campaign_draft.dart';
import '../../ports/campaign_draft_repository_port.dart';
import 'campaign_draft_mappers.dart';

/// Talks to Postgres via Supabase, same thin shape as
/// `SupabaseGameStateAdapter`: row<->domain translation lives in
/// `campaign_draft_mappers.dart`, this class only orchestrates queries. RLS
/// (`20260730_campaign_drafts.sql`) is what actually enforces "only the
/// author can write, anyone can read a published row" — this adapter relies
/// on it rather than filtering by author_id itself.
class SupabaseCampaignDraftAdapter implements CampaignDraftRepositoryPort {
  SupabaseCampaignDraftAdapter(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CampaignDraftSummary>> listMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('campaign_drafts')
        .select('id, slug, title, base_world_slug, status, cover_image_url, graph, updated_at')
        .eq('author_id', userId)
        .order('updated_at', ascending: false);
    return [for (final row in rows) campaignDraftSummaryFromRow(row)];
  }

  @override
  Future<CampaignDraft?> loadDraft(String id) async {
    final row = await _client
        .from('campaign_drafts')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return campaignDraftFromRow(row);
  }

  @override
  Future<CampaignDraft> createDraft({
    required String baseWorldSlug,
    required String title,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('createDraft requires a signed-in user');
    }

    final slug = await _uniqueSlug(slugify(title));
    final row = await _client
        .from('campaign_drafts')
        .insert({
          'author_id': userId,
          'slug': slug,
          'title': title,
          'base_world_slug': baseWorldSlug,
        })
        .select()
        .single();
    return campaignDraftFromRow(row);
  }

  /// Appends a short numeric suffix until [base] isn't already taken —
  /// `slugify` itself is pure/deterministic and can't know that, only the
  /// adapter can check the database.
  Future<String> _uniqueSlug(String base) async {
    var candidate = base;
    var attempt = 1;
    while (true) {
      final existing = await _client
          .from('campaign_drafts')
          .select('id')
          .eq('slug', candidate)
          .maybeSingle();
      if (existing == null) return candidate;
      attempt += 1;
      candidate = '$base-$attempt';
    }
  }

  @override
  Future<void> saveDraft(CampaignDraft draft) async {
    if (draft.id == null) {
      throw ArgumentError('saveDraft requires an already-created draft (id set)');
    }
    await _client
        .from('campaign_drafts')
        .update(campaignDraftToRow(draft))
        .eq('id', draft.id!);
  }

  @override
  Future<void> deleteDraft(String id) async {
    await _client.from('campaign_drafts').delete().eq('id', id);
  }

  @override
  Future<void> publishDraft(String id, {required DateTime licenseAcceptedAt}) async {
    await _client.from('campaign_drafts').update({
      'status': CampaignDraftStatus.published.toString(),
      'published_at': DateTime.now().toIso8601String(),
      'license_accepted_at': licenseAcceptedAt.toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> unpublishDraft(String id) async {
    await _client
        .from('campaign_drafts')
        .update({'status': CampaignDraftStatus.draft.toString()})
        .eq('id', id);
  }

  @override
  Future<String> uploadCoverImage(
    String id,
    Uint8List bytes, {
    required String fileExtension,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('uploadCoverImage requires a signed-in user');
    }
    // Same path every time (upsert): a re-upload replaces the previous
    // cover in place instead of accumulating orphaned files per edit.
    final path = '$userId/$id/cover.$fileExtension';
    await _client.storage.from('campaign-covers').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('campaign-covers').getPublicUrl(path);
  }
}
