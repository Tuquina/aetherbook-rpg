/// The campaign editor's admin allowlist (project decision 2026-07-30) —
/// only these accounts may author/edit an official "historia completa" or
/// "historia híbrida" (`CampaignDraft.officialModule`). This is a UI-gating
/// convenience only: the real enforcement is the `is_admin()` Postgres
/// function backing `campaign_drafts`' RLS policies
/// (`20260730_campaign_drafts_admin_official.sql`), which this list must be
/// kept in sync with by hand — there's no single source of truth shared
/// between Dart and SQL yet.
const adminEmails = {
  'carrizoaagustin@gmail.com',
  'fernandotuquina@gmail.com',
  'franjaime2016@gmail.com',
  'francoq96@gmail.com',
  'aetherbook.app@gmail.com',
};

/// Whether [email] (typically `AuthPort.email`, `null` while anonymous)
/// belongs to an editor admin.
bool isAdminEmail(String? email) => email != null && adminEmails.contains(email);
