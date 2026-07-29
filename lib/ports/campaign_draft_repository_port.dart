import 'dart:typed_data';

import '../core/authoring/campaign_draft.dart';

/// Persists and loads player-authored campaigns (V2 design prototype
/// §9a-9j). Mirrors [GameStateRepositoryPort]'s shape: the domain never
/// talks to Supabase directly, only through this port; RLS (see
/// `20260730_campaign_drafts.sql`) is what actually keeps a draft private to
/// its author and a published campaign readable by everyone else — this port
/// doesn't filter by author itself.
abstract class CampaignDraftRepositoryPort {
  /// Every draft/published campaign the current user has authored, newest-
  /// updated first, as lightweight summaries (no `graph` — see
  /// [CampaignDraftSummary]). Powers `EditorLibraryScreen`.
  Future<List<CampaignDraftSummary>> listMine();

  /// Every campaign flagged [CampaignDraft.officialModule], of any status,
  /// regardless of author — "revisar y editar todas las historias completas
  /// e híbridas" (project decision 2026-07-30). Relies entirely on RLS
  /// (`20260730_campaign_drafts_admin_official.sql`) to actually restrict
  /// this to admins for non-published rows; a non-admin caller simply gets
  /// back whatever's already publicly readable (published official
  /// campaigns), never an error.
  Future<List<CampaignDraftSummary>> listOfficial();

  /// One draft by id, graph included, or `null` if it doesn't exist (or
  /// isn't this user's — RLS handles that transparently).
  Future<CampaignDraft?> loadDraft(String id);

  /// Creates a new, empty draft based on [baseWorldSlug] and returns it
  /// (with its persisted `id`/`slug` set). [title] seeds both the display
  /// title and (via [slugify]) the initial slug.
  Future<CampaignDraft> createDraft({
    required String baseWorldSlug,
    required String title,
  });

  /// Persists every field of [draft] — the editor's autosave, called after
  /// any edit (a map change, a node save, a metadata change). Upserts by
  /// [CampaignDraft.id], which must already be set (see [createDraft]).
  Future<void> saveDraft(CampaignDraft draft);

  /// Deletes a draft outright. A published campaign should be
  /// [unpublishDraft]d first — deleting it directly also removes it for
  /// anyone currently reading it, same caveat the rights notice (§10c)
  /// states for unpublishing.
  Future<void> deleteDraft(String id);

  /// Flips [id] to `published` — from this point [status] is world-readable
  /// under the RLS "public read published campaigns" policy. Only ever
  /// called once the author has accepted the rights notice (§10c);
  /// [licenseAcceptedAt] is stamped once and never cleared by a later
  /// [unpublishDraft] (CLAUDE.md doesn't require re-accepting to republish
  /// the same campaign).
  Future<void> publishDraft(String id, {required DateTime licenseAcceptedAt});

  /// Flips [id] back to `draft` — stops it being world-readable. In-progress
  /// reads by other players may still finish (§10c: "Las partidas ya
  /// empezadas por otros lectores pueden terminarse"); enforcing that is a
  /// property of how a reading session snapshots its own campaign content,
  /// not something this method needs to do.
  Future<void> unpublishDraft(String id);

  /// Uploads [bytes] as [id]'s cover image (V2 design prototype §9f,
  /// "Imagen de portada") to the `campaign-covers` bucket and returns its
  /// public URL — the one place in the app a player uploads a file from
  /// their own device rather than receiving one generated server-side.
  /// Overwrites any previous cover for the same draft (same path every
  /// time, `upsert`). Doesn't itself call [saveDraft]; the caller still
  /// sets [CampaignDraft.coverImageUrl] and persists it like any other
  /// field edit.
  Future<String> uploadCoverImage(
    String id,
    Uint8List bytes, {
    required String fileExtension,
  });
}
