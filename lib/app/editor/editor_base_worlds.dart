/// The base worlds a campaign can be authored on top of (V2 design prototype
/// §9f: "Define los atributos, los colores y el tono del narrador") — the 5
/// freeform genre frameworks (CLAUDE.md Fase 2), not the fully-authored
/// curated campaigns or the one existing hybrid campaign, since those are
/// specific stories rather than reusable attribute/theme systems. Shared by
/// `EditorLibraryScreen` (picking one for a new draft) and
/// `CampaignMapScreen`/`CoverEditorScreen` (re-listing them to change one).
const editorBaseWorldSlugs = [
  'isekai',
  'xianxia',
  'superheroes',
  'cyberpunk',
  'postapoc',
];
