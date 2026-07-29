import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/authoring/campaign_draft.dart';
import '../../core/world/world.dart';
import '../../ports/campaign_draft_repository_port.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/world_theme.dart';
import '../widgets/library_thumbnail.dart';
import 'design/editor_tokens.dart';
import 'widgets/chip_list_field.dart';

const _synopsisMaxLength = 240;

const _durationPresets = [
  (label: 'Menos de 1 hora', minutes: 45),
  (label: '1 a 2 horas', minutes: 90),
  (label: '2 a 4 horas', minutes: 180),
  (label: '4 a 6 horas', minutes: 300),
  (label: '6 a 10 horas', minutes: 480),
  (label: 'Más de 10 horas', minutes: 700),
];

int _closestPreset(int? minutes) {
  if (minutes == null) return _durationPresets[3].minutes;
  return _durationPresets
      .reduce((a, b) => (a.minutes - minutes).abs() <= (b.minutes - minutes).abs() ? a : b)
      .minutes;
}

/// Cover/metadata editor (V2 design prototype §9f) — title, synopsis, base
/// world, duration, cover image, content warnings, and the offline-playable
/// toggle, with a live reader-facing preview on the side. Publishing itself
/// (§9i's checklist, §10c's rights notice) is a later stage; this screen
/// only edits [CampaignDraft] fields and hands the result back.
class CoverEditorScreen {
  const CoverEditorScreen._();

  static Future<CampaignDraft?> open(
    BuildContext context, {
    required CampaignDraft draft,
    required CampaignDraftRepositoryPort campaignDrafts,
    required List<World> baseWorlds,
    required int nodeCount,
  }) {
    return Navigator.of(context).push<CampaignDraft>(
      MaterialPageRoute(
        builder: (_) => _CoverForm(
          initial: draft,
          campaignDrafts: campaignDrafts,
          baseWorlds: baseWorlds,
          nodeCount: nodeCount,
        ),
      ),
    );
  }
}

class _CoverForm extends StatefulWidget {
  const _CoverForm({
    required this.initial,
    required this.campaignDrafts,
    required this.baseWorlds,
    required this.nodeCount,
  });

  final CampaignDraft initial;
  final CampaignDraftRepositoryPort campaignDrafts;
  final List<World> baseWorlds;
  final int nodeCount;

  @override
  State<_CoverForm> createState() => _CoverFormState();
}

class _CoverFormState extends State<_CoverForm> {
  late final _titleController = TextEditingController(text: widget.initial.title);
  late final _synopsisController = TextEditingController(text: widget.initial.synopsis);

  /// `true` for an admin-authored official campaign that declares its own
  /// [World] instead of borrowing one via `baseWorldSlug` — this screen
  /// never offers to switch it to a bundled base world, and never touches
  /// `baseWorldSlug` on save (would silently clear `customWorld`, see
  /// [CampaignDraft.copyWith]'s mutual-exclusion rule).
  late final bool _isCustomWorld = widget.initial.customWorld != null;
  late String _baseWorldSlug =
      widget.initial.baseWorldSlug ?? widget.baseWorlds.first.slug;
  late int _durationMinutes = _closestPreset(widget.initial.estimatedDurationMinutes);
  late String? _coverImageUrl = widget.initial.coverImageUrl;
  late List<String> _contentWarnings = widget.initial.contentWarnings;
  late bool _aiRuntimeRequired = widget.initial.aiRuntimeRequired;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _synopsisController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _synopsisController.dispose();
    super.dispose();
  }

  World get _selectedWorld =>
      widget.initial.customWorld ??
      widget.baseWorlds.firstWhere((w) => w.slug == _baseWorldSlug, orElse: () => widget.baseWorlds.first);

  bool get _offlinePlayable => !_aiRuntimeRequired;

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final url = await widget.campaignDrafts.uploadCoverImage(
        widget.initial.id!,
        bytes,
        fileExtension: extension,
      );
      if (!mounted) return;
      setState(() {
        _coverImageUrl = url;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AetherColors.surfaceRaised,
          content: Text('No se pudo subir la imagen. Probá de nuevo.',
              style: TextStyle(color: AetherColors.parchment)),
        ),
      );
    }
  }

  CampaignDraft get _result => widget.initial.copyWith(
        title: _titleController.text.trim(),
        synopsis: _synopsisController.text.trim(),
        baseWorldSlug: _isCustomWorld ? null : _baseWorldSlug,
        estimatedDurationMinutes: _durationMinutes,
        coverImageUrl: _coverImageUrl,
        clearCoverImageUrl: _coverImageUrl == null,
        contentWarnings: _contentWarnings,
        aiRuntimeRequired: _aiRuntimeRequired,
      );

  void _save() => Navigator.of(context).pop(_result);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      appBar: AppBar(
        backgroundColor: AetherColors.ink,
        iconTheme: const IconThemeData(color: AetherColors.goldSoft),
        title: const Text('Portada e información',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Guardar', style: EditorType.button.copyWith(color: AetherColors.goldBright)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final formColumn = _FormColumn(
            titleController: _titleController,
            synopsisController: _synopsisController,
            isCustomWorld: _isCustomWorld,
            customWorldName: widget.initial.customWorld?.name,
            baseWorldSlug: _baseWorldSlug,
            baseWorlds: widget.baseWorlds,
            onBaseWorldChanged: (v) => setState(() => _baseWorldSlug = v),
            durationMinutes: _durationMinutes,
            onDurationChanged: (v) => setState(() => _durationMinutes = v),
            nodeCount: widget.nodeCount,
            coverImageUrl: _coverImageUrl,
            uploading: _uploading,
            onPickImage: _pickCoverImage,
            worldAccent: WorldTheme.forWorld(_selectedWorld).accent,
            contentWarnings: _contentWarnings,
            onContentWarningsChanged: (v) => setState(() => _contentWarnings = v),
            offlinePlayable: _offlinePlayable,
            onOfflinePlayableChanged: (v) => setState(() => _aiRuntimeRequired = !v),
          );
          final previewColumn = _PreviewColumn(
            title: _titleController.text.trim(),
            synopsis: _synopsisController.text.trim(),
            world: _selectedWorld,
            durationMinutes: _durationMinutes,
            coverImageUrl: _coverImageUrl,
            hasBasics: _titleController.text.trim().isNotEmpty &&
                _synopsisController.text.trim().isNotEmpty,
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AetherSpace.xl),
                    child: formColumn,
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: AetherColors.hairline)),
                    ),
                    padding: const EdgeInsets.all(AetherSpace.xl),
                    child: previewColumn,
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AetherSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                formColumn,
                const SizedBox(height: AetherSpace.xl),
                Text('ASÍ LA VERÁ UN LECTOR', style: EditorType.overline),
                const SizedBox(height: AetherSpace.sm),
                previewColumn,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.titleController,
    required this.synopsisController,
    required this.isCustomWorld,
    required this.customWorldName,
    required this.baseWorldSlug,
    required this.baseWorlds,
    required this.onBaseWorldChanged,
    required this.durationMinutes,
    required this.onDurationChanged,
    required this.nodeCount,
    required this.coverImageUrl,
    required this.uploading,
    required this.onPickImage,
    required this.worldAccent,
    required this.contentWarnings,
    required this.onContentWarningsChanged,
    required this.offlinePlayable,
    required this.onOfflinePlayableChanged,
  });

  final TextEditingController titleController;
  final TextEditingController synopsisController;

  /// `true` for an admin-authored official campaign that declares its own
  /// [World] (Admin Stage 3) — shows [customWorldName] as a static label
  /// instead of [baseWorlds]' dropdown, which has no entry for it.
  final bool isCustomWorld;
  final String? customWorldName;
  final String baseWorldSlug;
  final List<World> baseWorlds;
  final ValueChanged<String> onBaseWorldChanged;
  final int durationMinutes;
  final ValueChanged<int> onDurationChanged;
  final int nodeCount;
  final String? coverImageUrl;
  final bool uploading;
  final VoidCallback onPickImage;
  final Color worldAccent;
  final List<String> contentWarnings;
  final ValueChanged<List<String>> onContentWarningsChanged;
  final bool offlinePlayable;
  final ValueChanged<bool> onOfflinePlayableChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo se llama', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: titleController,
          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 22, color: AetherColors.goldBright),
          decoration: _decoration(),
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('De qué va, en dos frases', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: synopsisController,
          maxLines: null,
          minLines: 3,
          maxLength: _synopsisMaxLength,
          style: AetherType.body.copyWith(fontSize: 13.5),
          decoration: _decoration().copyWith(counterStyle: EditorType.meta),
        ),
        const SizedBox(height: AetherSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('En qué mundo pasa', style: EditorType.overline),
                  const SizedBox(height: 8),
                  if (isCustomWorld)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AetherSpace.sm + 2, vertical: AetherSpace.sm + 3),
                      decoration: BoxDecoration(
                        color: AetherColors.surface,
                        borderRadius: AetherRadius.allMd,
                        border: Border.all(color: worldAccent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: worldAccent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(customWorldName ?? 'Mundo personalizado',
                              style: AetherType.body.copyWith(fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
                      decoration: BoxDecoration(
                        color: AetherColors.surface,
                        borderRadius: AetherRadius.allMd,
                        border: Border.all(color: worldAccent.withValues(alpha: 0.35)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: baseWorldSlug,
                          isExpanded: true,
                          dropdownColor: AetherColors.surface,
                          items: [
                            for (final world in baseWorlds)
                              DropdownMenuItem(
                                value: world.slug,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: WorldTheme.forWorld(world).accent, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(world.name, style: AetherType.body.copyWith(fontSize: 13)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => v == null ? null : onBaseWorldChanged(v),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                      isCustomWorld
                          ? 'Este mundo fue creado con el constructor de mundo.'
                          : 'Define los atributos, los colores y el tono del narrador.',
                      style: EditorType.hint),
                ],
              ),
            ),
            const SizedBox(width: AetherSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cuánto dura', style: EditorType.overline),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
                    decoration: BoxDecoration(
                      color: AetherColors.surface,
                      borderRadius: AetherRadius.allMd,
                      border: Border.all(color: AetherColors.hairline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: durationMinutes,
                        isExpanded: true,
                        dropdownColor: AetherColors.surface,
                        items: [
                          for (final preset in _durationPresets)
                            DropdownMenuItem(
                              value: preset.minutes,
                              child: Text(preset.label, style: AetherType.body.copyWith(fontSize: 13)),
                            ),
                        ],
                        onChanged: (v) => v == null ? null : onDurationChanged(v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Calculado sobre $nodeCount escenas.', style: EditorType.hint),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('Imagen de portada', style: EditorType.overline),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: uploading ? null : onPickImage,
              borderRadius: AetherRadius.allMd,
              child: Container(
                width: 104,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: AetherRadius.allMd,
                  border: Border.all(color: worldAccent.withValues(alpha: 0.4)),
                ),
                child: uploading
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AetherColors.gold)))
                    : coverImageUrl == null
                        ? const Icon(Icons.add_photo_alternate_rounded,
                            color: AetherColors.parchmentFaint, size: 26)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: AetherRadius.allMd,
                                child: LibraryThumbnail(
                                  imageUrl: coverImageUrl,
                                  accent: worldAccent,
                                  size: 104,
                                  borderRadius: AetherRadius.allMd,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.check_circle_rounded,
                                    size: 16, color: AetherColors.goldBright, shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4)
                                ]),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Si no subís ninguna, la historia usa la ilustración de su primera escena.',
                  style: AetherType.caption,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('Avisos de contenido', style: EditorType.overline),
        const SizedBox(height: 8),
        ChipListField(
          values: contentWarnings,
          accent: AetherColors.failure,
          onChanged: onContentWarningsChanged,
        ),
        const SizedBox(height: 6),
        Text('Un lector que haya marcado uno de estos temas verá el aviso antes de empezar.',
            style: EditorType.hint),
        const SizedBox(height: AetherSpace.lg),
        Container(
          padding: const EdgeInsets.all(AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.success.withValues(alpha: 0.04),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.success.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.offline_bolt_rounded, size: 18, color: AetherColors.success),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Se puede jugar sin narrador de IA', style: EditorType.label),
                    Text('Todas las escenas y desenlaces alcanzables tienen texto escrito por vos.',
                        style: EditorType.hint),
                  ],
                ),
              ),
              Switch(
                value: offlinePlayable,
                activeThumbColor: AetherColors.success,
                onChanged: onOfflinePlayableChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.title,
    required this.synopsis,
    required this.world,
    required this.durationMinutes,
    required this.coverImageUrl,
    required this.hasBasics,
  });

  final String title;
  final String synopsis;
  final World world;
  final int durationMinutes;
  final String? coverImageUrl;
  final bool hasBasics;

  String get _durationLabel =>
      _durationPresets.firstWhere((p) => p.minutes == durationMinutes).label;

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(world).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: LibraryThumbnail(
                      imageUrl: coverImageUrl,
                      accent: accent,
                      size: 400,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AetherColors.void_.withValues(alpha: 0.75),
                        borderRadius: AetherRadius.allSm,
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(world.name.toUpperCase(),
                          style: EditorType.kicker.copyWith(color: accent)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AetherSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Sin título' : title,
                      style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: accent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      synopsis.isEmpty ? 'Sin sinopsis todavía.' : synopsis,
                      style: AetherType.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    Wrap(
                      spacing: 6,
                      children: [
                        _PreviewPill(text: _durationLabel, accent: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.lg),
        _ChecklistRow(done: hasBasics, label: 'Título y sinopsis completos'),
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(text, style: EditorType.pill.copyWith(color: accent)),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = done ? AetherColors.success : AetherColors.failure;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2, vertical: 9),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: color),
          const SizedBox(width: AetherSpace.sm),
          Expanded(child: Text(label, style: AetherType.caption)),
        ],
      ),
    );
  }
}

InputDecoration _decoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
      filled: true,
      fillColor: AetherColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: const BorderSide(color: AetherColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: const BorderSide(color: AetherColors.gold),
      ),
    );
