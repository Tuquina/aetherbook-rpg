import 'package:flutter/material.dart';

import '../../core/narrative/abstract_opponent.dart';
import '../../core/state/character.dart';
import '../../core/world/character_origin.dart';
import '../../core/world/character_tag_rule.dart';
import '../../core/world/codex_place.dart';
import '../../core/world/codex_term.dart';
import '../../core/world/item_definition.dart';
import '../../core/world/npc.dart';
import '../../core/world/progression.dart';
import '../../core/world/rank_definition.dart';
import '../../core/world/technique.dart';
import '../../core/world/tone_option.dart';
import '../../core/world/vow.dart';
import '../../core/world/world.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';
import 'widgets/chip_list_field.dart';

/// A blank starting point for a brand-new custom world — every field an
/// admin would otherwise have to fill in by hand before the form can even
/// render. [WorldBuilderScreen.open] with `initial: null` starts from this.
World blankCustomWorld() => const World(
      slug: '',
      name: '',
      theme: '',
      tone: '',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: '',
      startingCharacter: Character(
        name: 'Protagonista',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      ),
      seedNarration: '',
      seedChoices: [],
    );

/// The World Builder (Admin Stage 2, project decision 2026-07-31): lets an
/// admin author a fully custom attribute/resource/theme/narrator-tone system
/// from scratch — [CampaignDraft.customWorld] — instead of always borrowing
/// one via `baseWorldSlug`. Reuses [World] as-is: every field here maps
/// directly onto one of its ~40 fields or 13 declarative collections
/// (CLAUDE.md §8 — nothing about this is hardcoded engine logic, it's all
/// still content). Deliberately not wired into "attach to a play session"
/// yet — that materialization step, and the 3-way creation picker that opens
/// this screen, are Admin Stage 3's job; this screen only produces a [World]
/// value and hands it back.
class WorldBuilderScreen {
  const WorldBuilderScreen._();

  static Future<World?> open(BuildContext context, {World? initial}) {
    return Navigator.of(context).push<World>(
      MaterialPageRoute(
        builder: (_) => _WorldBuilderForm(initial: initial ?? blankCustomWorld()),
      ),
    );
  }
}

const _textureOptions = <String?>[null, 'radial_warm', 'fog', 'hard_diagonal', 'scanline', 'grain'];

String _textureLabel(String? texture) => switch (texture) {
      null => 'Por defecto (radial)',
      'radial_warm' => 'Radial cálido',
      'fog' => 'Niebla',
      'hard_diagonal' => 'Diagonal duro',
      'scanline' => 'Líneas de escaneo',
      'grain' => 'Grano',
      _ => texture,
    };

class _WorldBuilderForm extends StatefulWidget {
  const _WorldBuilderForm({required this.initial});

  final World initial;

  @override
  State<_WorldBuilderForm> createState() => _WorldBuilderFormState();
}

class _WorldBuilderFormState extends State<_WorldBuilderForm> {
  // Identidad
  late final _slug = TextEditingController(text: widget.initial.slug);
  late final _name = TextEditingController(text: widget.initial.name);
  late final _theme = TextEditingController(text: widget.initial.theme);
  late final _tone = TextEditingController(text: widget.initial.tone);
  late final _systemPrompt = TextEditingController(text: widget.initial.systemPrompt);
  late final _imageStyleSuffix = TextEditingController(text: widget.initial.imageStyleSuffix);
  late final _catalogDescription =
      TextEditingController(text: widget.initial.catalogDescription ?? '');
  late final _contentWarning = TextEditingController(text: widget.initial.contentWarning ?? '');
  late int _estimatedDurationMinutes = widget.initial.estimatedDurationMinutes ?? 180;

  // Mecánicas
  late final _primaryAttribute = TextEditingController(text: widget.initial.primaryAttribute);
  late List<String> _attributeKeys = widget.initial.attributeKeys;
  late int _defaultDifficulty = widget.initial.defaultDifficulty;
  late int _criticalMargin = widget.initial.criticalMargin;
  late bool _progressionEnabled = widget.initial.progression.enabled;
  late final _unitLabel = TextEditingController(text: widget.initial.progression.unitLabel);
  late int _baseExpPerLevel = widget.initial.progression.baseExpPerLevel;

  // Personaje inicial / chargen
  late final _startingName = TextEditingController(text: widget.initial.startingCharacter.name);
  late int _startingLevel = widget.initial.startingCharacter.level;
  late int _startingExp = widget.initial.startingCharacter.exp;
  late Map<String, int> _startingAttributes = {...widget.initial.startingCharacter.attributes};
  late bool _hasFreeAttributePoint = widget.initial.hasFreeAttributePoint;
  late final _chargenVowLabel = TextEditingController(text: widget.initial.chargenVowLabel);
  late bool _hasCustomizableName = widget.initial.hasCustomizableName;
  late final _seedNarration = TextEditingController(text: widget.initial.seedNarration);
  late List<String> _seedChoices = widget.initial.seedChoices;
  late final _personalItemSeedHook =
      TextEditingController(text: widget.initial.personalItemSeedHook ?? '');
  late List<CharacterOrigin> _origins = widget.initial.origins;
  late List<Vow> _vows = widget.initial.vows;
  late List<ToneOption> _tones = widget.initial.tones;

  // Tema visual
  late final _themeAccentHex = TextEditingController(text: widget.initial.themeAccentHex ?? '');
  late final _themeBaseHex = TextEditingController(text: widget.initial.themeBaseHex ?? '');
  late final _themeSecondaryHex =
      TextEditingController(text: widget.initial.themeSecondaryHex ?? '');
  late String? _themeTexture = widget.initial.themeTexture;

  // Reparto y objetos
  late List<Npc> _npcs = widget.initial.npcs;
  late List<ItemDefinition> _items = widget.initial.items;
  late List<CodexPlace> _places = widget.initial.places;
  late List<CodexTerm> _terms = widget.initial.terms;
  late List<CharacterTagRule> _characterTags = widget.initial.characterTags;

  // Avanzado
  late List<RankDefinition> _ranks = widget.initial.ranks;
  late List<AbstractOpponent> _opponents = widget.initial.opponents;
  late List<Technique> _techniques = widget.initial.techniques;
  late bool _aiRuntimeRequired = widget.initial.aiRuntimeRequired;
  late bool _allowFreeText = widget.initial.allowFreeText;

  @override
  void initState() {
    super.initState();
    // The only controllers _isValid reads — Guardar's enabled state must
    // react live to these, unlike every other field here.
    for (final c in [_slug, _name, _primaryAttribute, _systemPrompt]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _slug,
      _name,
      _theme,
      _tone,
      _systemPrompt,
      _imageStyleSuffix,
      _catalogDescription,
      _contentWarning,
      _primaryAttribute,
      _unitLabel,
      _startingName,
      _chargenVowLabel,
      _seedNarration,
      _personalItemSeedHook,
      _themeAccentHex,
      _themeBaseHex,
      _themeSecondaryHex,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncStartingAttributesToKeys() {
    final next = <String, int>{};
    for (final key in _attributeKeys) {
      next[key] = _startingAttributes[key] ?? 1;
    }
    _startingAttributes = next;
  }

  bool get _isValid =>
      _slug.text.trim().isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _primaryAttribute.text.trim().isNotEmpty &&
      _systemPrompt.text.trim().isNotEmpty;

  World get _result => World(
        slug: _slug.text.trim(),
        name: _name.text.trim(),
        theme: _theme.text.trim(),
        tone: _tone.text.trim(),
        systemPrompt: _systemPrompt.text.trim(),
        imageStyleSuffix: _imageStyleSuffix.text.trim(),
        defaultDifficulty: _defaultDifficulty,
        criticalMargin: _criticalMargin,
        primaryAttribute: _primaryAttribute.text.trim(),
        progression: Progression(
          enabled: _progressionEnabled,
          unitLabel: _unitLabel.text.trim().isEmpty ? 'nivel' : _unitLabel.text.trim(),
          baseExpPerLevel: _baseExpPerLevel,
        ),
        attributeKeys: _attributeKeys,
        origins: _origins,
        vows: _vows,
        tones: _tones,
        ranks: _ranks,
        opponents: _opponents,
        npcs: _npcs,
        techniques: _techniques,
        items: _items,
        places: _places,
        terms: _terms,
        characterTags: _characterTags,
        startingCharacter: Character(
          name: _startingName.text.trim().isEmpty ? 'Protagonista' : _startingName.text.trim(),
          level: _startingLevel,
          exp: _startingExp,
          attributes: _startingAttributes,
          resources: const {},
        ),
        seedNarration: _seedNarration.text.trim(),
        seedChoices: _seedChoices,
        personalItemSeedHook:
            _personalItemSeedHook.text.trim().isEmpty ? null : _personalItemSeedHook.text.trim(),
        aiRuntimeRequired: _aiRuntimeRequired,
        allowFreeText: _allowFreeText,
        catalogDescription:
            _catalogDescription.text.trim().isEmpty ? null : _catalogDescription.text.trim(),
        estimatedDurationMinutes: _estimatedDurationMinutes,
        contentWarning: _contentWarning.text.trim().isEmpty ? null : _contentWarning.text.trim(),
        hasFreeAttributePoint: _hasFreeAttributePoint,
        chargenVowLabel:
            _chargenVowLabel.text.trim().isEmpty ? 'Juramento' : _chargenVowLabel.text.trim(),
        hasCustomizableName: _hasCustomizableName,
        themeAccentHex: _themeAccentHex.text.trim().isEmpty ? null : _themeAccentHex.text.trim(),
        themeBaseHex: _themeBaseHex.text.trim().isEmpty ? null : _themeBaseHex.text.trim(),
        themeSecondaryHex:
            _themeSecondaryHex.text.trim().isEmpty ? null : _themeSecondaryHex.text.trim(),
        themeTexture: _themeTexture,
      );

  void _save() {
    if (!_isValid) return;
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      appBar: AppBar(
        backgroundColor: AetherColors.ink,
        iconTheme: const IconThemeData(color: AetherColors.goldSoft),
        title: const Text('Constructor de mundo',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
        actions: [
          TextButton(
            onPressed: _isValid ? _save : null,
            child: Text('Guardar',
                style: EditorType.button.copyWith(
                  color: _isValid ? AetherColors.goldBright : AetherColors.parchmentFaint,
                )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AetherSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Identidad'),
              _textRow('Slug (único, sin espacios)', _slug),
              _textRow('Nombre', _name),
              _textRow('Género/ambientación', _theme),
              _textRow('Tono narrativo', _tone),
              _textRow('Prompt del narrador', _systemPrompt, maxLines: 4),
              _textRow('Sufijo de estilo de imagen', _imageStyleSuffix),
              _textRow('Descripción de catálogo', _catalogDescription, maxLines: 2),
              _textRow('Aviso de contenido', _contentWarning),
              _DurationField(
                minutes: _estimatedDurationMinutes,
                onChanged: (v) => setState(() => _estimatedDurationMinutes = v),
              ),
              const SizedBox(height: AetherSpace.lg),
              _SectionHeader('Mecánicas'),
              _textRow('Atributo por defecto', _primaryAttribute),
              _label('Atributos del mundo'),
              const SizedBox(height: 8),
              ChipListField(
                values: _attributeKeys,
                onChanged: (v) => setState(() {
                  _attributeKeys = v;
                  _syncStartingAttributesToKeys();
                }),
              ),
              const SizedBox(height: AetherSpace.md),
              Row(
                children: [
                  Expanded(
                    child: _intRow('Dificultad por defecto', _defaultDifficulty,
                        (v) => setState(() => _defaultDifficulty = v)),
                  ),
                  const SizedBox(width: AetherSpace.md),
                  Expanded(
                    child: _intRow('Margen crítico', _criticalMargin,
                        (v) => setState(() => _criticalMargin = v)),
                  ),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              _SwitchRow(
                label: 'Progresión por nivel',
                value: _progressionEnabled,
                onChanged: (v) => setState(() => _progressionEnabled = v),
              ),
              if (_progressionEnabled) ...[
                Row(
                  children: [
                    Expanded(child: _textRow('Nombre de la unidad (nivel, reino...)', _unitLabel)),
                    const SizedBox(width: AetherSpace.md),
                    Expanded(
                      child: _intRow('EXP base por nivel', _baseExpPerLevel,
                          (v) => setState(() => _baseExpPerLevel = v)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AetherSpace.lg),
              _SectionHeader('Personaje inicial'),
              _textRow('Nombre del protagonista', _startingName),
              Row(
                children: [
                  Expanded(
                    child: _intRow('Nivel inicial', _startingLevel,
                        (v) => setState(() => _startingLevel = v)),
                  ),
                  const SizedBox(width: AetherSpace.md),
                  Expanded(
                    child: _intRow(
                        'EXP inicial', _startingExp, (v) => setState(() => _startingExp = v)),
                  ),
                ],
              ),
              if (_attributeKeys.isNotEmpty) ...[
                const SizedBox(height: AetherSpace.sm),
                _label('Valor inicial de cada atributo'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: AetherSpace.sm,
                  runSpacing: AetherSpace.sm,
                  children: [
                    for (final key in _attributeKeys)
                      SizedBox(
                        width: 150,
                        child: _intRow(key, _startingAttributes[key] ?? 1, (v) {
                          setState(() => _startingAttributes = {..._startingAttributes, key: v});
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AetherSpace.md),
              _SwitchRow(
                label: 'Punto de atributo libre en el chargen',
                value: _hasFreeAttributePoint,
                onChanged: (v) => setState(() => _hasFreeAttributePoint = v),
              ),
              _SwitchRow(
                label: 'El jugador puede nombrar al personaje',
                value: _hasCustomizableName,
                onChanged: (v) => setState(() => _hasCustomizableName = v),
              ),
              _textRow('Etiqueta del paso de juramento', _chargenVowLabel),
              _textRow('Narración semilla (apertura)', _seedNarration, maxLines: 4),
              _label('Opciones de apertura'),
              const SizedBox(height: 8),
              ChipListField(
                values: _seedChoices,
                onChanged: (v) => setState(() => _seedChoices = v),
              ),
              const SizedBox(height: AetherSpace.md),
              _textRow('Gancho de objeto personal (opcional)', _personalItemSeedHook),
              const SizedBox(height: AetherSpace.sm),
              _ListSection<CharacterOrigin>(
                title: 'Orígenes',
                items: _origins,
                itemTitle: (o) => o.displayName,
                itemSubtitle: (o) => o.tagId,
                onAdd: () async {
                  final created = await _editOrigin(context, null, _attributeKeys);
                  if (created != null) setState(() => _origins = [..._origins, created]);
                },
                onEdit: (i) async {
                  final edited = await _editOrigin(context, _origins[i], _attributeKeys);
                  if (edited != null) {
                    setState(() => _origins = [..._origins]..[i] = edited);
                  }
                },
                onDelete: (i) => setState(() => _origins = [..._origins]..removeAt(i)),
              ),
              _ListSection<Vow>(
                title: 'Juramentos',
                items: _vows,
                itemTitle: (v) => v.text,
                onAdd: () async {
                  final created = await _editVow(context, null);
                  if (created != null) setState(() => _vows = [..._vows, created]);
                },
                onEdit: (i) async {
                  final edited = await _editVow(context, _vows[i]);
                  if (edited != null) setState(() => _vows = [..._vows]..[i] = edited);
                },
                onDelete: (i) => setState(() => _vows = [..._vows]..removeAt(i)),
              ),
              _ListSection<ToneOption>(
                title: 'Tonos narrativos',
                items: _tones,
                itemTitle: (t) => t.label,
                itemSubtitle: (t) => t.blurb,
                onAdd: () async {
                  final created = await _editTone(context, null);
                  if (created != null) setState(() => _tones = [..._tones, created]);
                },
                onEdit: (i) async {
                  final edited = await _editTone(context, _tones[i]);
                  if (edited != null) setState(() => _tones = [..._tones]..[i] = edited);
                },
                onDelete: (i) => setState(() => _tones = [..._tones]..removeAt(i)),
              ),
              const SizedBox(height: AetherSpace.md),
              _SectionHeader('Tema visual'),
              Row(
                children: [
                  Expanded(child: _textRow('Acento (#hex)', _themeAccentHex)),
                  const SizedBox(width: AetherSpace.md),
                  Expanded(child: _textRow('Base (#hex)', _themeBaseHex)),
                  const SizedBox(width: AetherSpace.md),
                  Expanded(child: _textRow('Secundario (#hex)', _themeSecondaryHex)),
                ],
              ),
              _label('Textura de fondo'),
              const SizedBox(height: 8),
              _TextureDropdown(
                value: _themeTexture,
                onChanged: (v) => setState(() => _themeTexture = v),
              ),
              const SizedBox(height: AetherSpace.lg),
              _SectionHeader('Reparto y objetos'),
              _ListSection<Npc>(
                title: 'Personajes (NPCs)',
                items: _npcs,
                itemTitle: (n) => n.displayName,
                itemSubtitle: (n) => n.role,
                onAdd: () async {
                  final created = await _editNpc(context, null);
                  if (created != null) setState(() => _npcs = [..._npcs, created]);
                },
                onEdit: (i) async {
                  final edited = await _editNpc(context, _npcs[i]);
                  if (edited != null) setState(() => _npcs = [..._npcs]..[i] = edited);
                },
                onDelete: (i) => setState(() => _npcs = [..._npcs]..removeAt(i)),
              ),
              _ListSection<ItemDefinition>(
                title: 'Objetos de inventario',
                items: _items,
                itemTitle: (it) => it.displayName,
                itemSubtitle: (it) => it.category.name,
                onAdd: () async {
                  final created = await _editItem(context, null);
                  if (created != null) setState(() => _items = [..._items, created]);
                },
                onEdit: (i) async {
                  final edited = await _editItem(context, _items[i]);
                  if (edited != null) setState(() => _items = [..._items]..[i] = edited);
                },
                onDelete: (i) => setState(() => _items = [..._items]..removeAt(i)),
              ),
              _ListSection<CodexPlace>(
                title: 'Códice — Lugares',
                items: _places,
                itemTitle: (p) => p.displayName,
                onAdd: () async {
                  final created = await _editCodexPlace(context, null);
                  if (created != null) setState(() => _places = [..._places, created]);
                },
                onEdit: (i) async {
                  final edited = await _editCodexPlace(context, _places[i]);
                  if (edited != null) setState(() => _places = [..._places]..[i] = edited);
                },
                onDelete: (i) => setState(() => _places = [..._places]..removeAt(i)),
              ),
              _ListSection<CodexTerm>(
                title: 'Códice — Términos',
                items: _terms,
                itemTitle: (t) => t.displayName,
                onAdd: () async {
                  final created = await _editCodexTerm(context, null);
                  if (created != null) setState(() => _terms = [..._terms, created]);
                },
                onEdit: (i) async {
                  final edited = await _editCodexTerm(context, _terms[i]);
                  if (edited != null) setState(() => _terms = [..._terms]..[i] = edited);
                },
                onDelete: (i) => setState(() => _terms = [..._terms]..removeAt(i)),
              ),
              _ListSection<CharacterTagRule>(
                title: 'Marcas de personaje',
                items: _characterTags,
                itemTitle: (t) => t.label,
                itemSubtitle: (t) => t.flagKey,
                onAdd: () async {
                  final created = await _editCharacterTag(context, null);
                  if (created != null) {
                    setState(() => _characterTags = [..._characterTags, created]);
                  }
                },
                onEdit: (i) async {
                  final edited = await _editCharacterTag(context, _characterTags[i]);
                  if (edited != null) {
                    setState(() => _characterTags = [..._characterTags]..[i] = edited);
                  }
                },
                onDelete: (i) => setState(() => _characterTags = [..._characterTags]..removeAt(i)),
              ),
              const SizedBox(height: AetherSpace.md),
              _SectionHeader('Avanzado'),
              _SwitchRow(
                label: 'Requiere narrador de IA en tiempo real',
                value: _aiRuntimeRequired,
                onChanged: (v) => setState(() => _aiRuntimeRequired = v),
              ),
              _SwitchRow(
                label: 'Permite acciones de texto libre',
                value: _allowFreeText,
                onChanged: (v) => setState(() => _allowFreeText = v),
              ),
              const SizedBox(height: AetherSpace.sm),
              _ListSection<RankDefinition>(
                title: 'Rangos con hito',
                items: _ranks,
                itemTitle: (r) => r.id,
                itemSubtitle: (r) => 'Nivel ${r.level} · ${r.expRequired} EXP',
                onAdd: () async {
                  final created = await _editRank(context, null);
                  if (created != null) setState(() => _ranks = [..._ranks, created]);
                },
                onEdit: (i) async {
                  final edited = await _editRank(context, _ranks[i]);
                  if (edited != null) setState(() => _ranks = [..._ranks]..[i] = edited);
                },
                onDelete: (i) => setState(() => _ranks = [..._ranks]..removeAt(i)),
              ),
              _ListSection<AbstractOpponent>(
                title: 'Oponentes abstractos',
                items: _opponents,
                itemTitle: (o) => o.displayName,
                itemSubtitle: (o) => 'Guardia ${o.maxGuard}',
                onAdd: () async {
                  final created = await _editOpponent(context, null);
                  if (created != null) setState(() => _opponents = [..._opponents, created]);
                },
                onEdit: (i) async {
                  final edited = await _editOpponent(context, _opponents[i]);
                  if (edited != null) setState(() => _opponents = [..._opponents]..[i] = edited);
                },
                onDelete: (i) => setState(() => _opponents = [..._opponents]..removeAt(i)),
              ),
              _ListSection<Technique>(
                title: 'Técnicas',
                items: _techniques,
                itemTitle: (t) => t.displayName,
                itemSubtitle: (t) => t.effect,
                onAdd: () async {
                  final created = await _editTechnique(context, null);
                  if (created != null) setState(() => _techniques = [..._techniques, created]);
                },
                onEdit: (i) async {
                  final edited = await _editTechnique(context, _techniques[i]);
                  if (edited != null) {
                    setState(() => _techniques = [..._techniques]..[i] = edited);
                  }
                },
                onDelete: (i) => setState(() => _techniques = [..._techniques]..removeAt(i)),
              ),
              const SizedBox(height: AetherSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared field widgets ─────────────────────────────────────────────────

Widget _label(String text) => Text(text, style: EditorType.overline);

Widget _textRow(String label, TextEditingController controller, {int? maxLines}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AetherSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines ?? 1,
          style: AetherType.body.copyWith(fontSize: 13),
          decoration: _fieldDecoration(),
        ),
      ],
    ),
  );
}

Widget _intRow(String label, int value, ValueChanged<int> onChanged) {
  final controller = TextEditingController(text: value.toString());
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: AetherType.body.copyWith(fontSize: 13),
        decoration: _fieldDecoration(),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
      ),
    ],
  );
}

InputDecoration _fieldDecoration() => InputDecoration(
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.md),
      child: Text(text,
          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 18, color: AetherColors.goldBright)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: EditorType.label)),
          Switch(value: value, activeThumbColor: AetherColors.gold, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _intRow('Duración estimada (minutos)', minutes, onChanged);
  }
}

class _TextureDropdown extends StatelessWidget {
  const _TextureDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          dropdownColor: AetherColors.surface,
          items: [
            for (final t in _textureOptions)
              DropdownMenuItem(
                value: t,
                child: Text(_textureLabel(t), style: AetherType.body.copyWith(fontSize: 13)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// A titled list of entities with add/edit/delete affordances — the one
/// generic building block behind every collection in [World] (origins,
/// vows, tones, ranks, opponents, npcs, techniques, items, places, terms,
/// character tags), since they all share the same "named things you add one
/// at a time" shape.
class _ListSection<T> extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.items,
    required this.itemTitle,
    this.itemSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemTitle;
  final String Function(T)? itemSubtitle;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label(title)),
              InkWell(
                onTap: onAdd,
                borderRadius: AetherRadius.allSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: AetherRadius.allSm,
                    border: Border.all(color: AetherColors.hairlineStrong),
                  ),
                  child: Text('+ añadir',
                      style: EditorType.pill.copyWith(color: AetherColors.parchmentFaint)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('Todavía no agregaste ninguno.', style: EditorType.hint)
          else
            for (final (i, item) in items.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2, vertical: 8),
                decoration: BoxDecoration(
                  color: AetherColors.surface,
                  borderRadius: AetherRadius.allSm,
                  border: Border.all(color: AetherColors.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(itemTitle(item).isEmpty ? '(sin nombre)' : itemTitle(item),
                              style: AetherType.body.copyWith(fontSize: 13)),
                          if (itemSubtitle != null && itemSubtitle!(item).isNotEmpty)
                            Text(itemSubtitle!(item), style: EditorType.hint),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => onEdit(i),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit_rounded, size: 15, color: AetherColors.parchmentFaint),
                      ),
                    ),
                    InkWell(
                      onTap: () => onDelete(i),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 15, color: AetherColors.parchmentFaint),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── Per-entity edit dialogs ──────────────────────────────────────────────

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AetherColors.surfaceRaised,
      title: Text(title,
          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 16, color: AetherColors.goldBright)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: fields),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<Npc?> _editNpc(BuildContext context, Npc? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final role = TextEditingController(text: existing?.role ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final voiceNotes = TextEditingController(text: existing?.voiceNotes ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo personaje' : 'Editar personaje',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        _textRow('Rol', role),
        _textRow('Descripción', description, maxLines: 3),
        _textRow('Notas de voz', voiceNotes, maxLines: 2),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return Npc(
    id: id.text.trim(),
    displayName: name.text.trim(),
    role: role.text.trim(),
    description: description.text.trim(),
    voiceNotes: voiceNotes.text.trim(),
  );
}

Future<ItemDefinition?> _editItem(BuildContext context, ItemDefinition? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  var category = existing?.category ?? ItemCategory.misc;
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo objeto' : 'Editar objeto',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        _textRow('Descripción', description, maxLines: 3),
        StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Categoría'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
                  decoration: BoxDecoration(
                    color: AetherColors.surface,
                    borderRadius: AetherRadius.allMd,
                    border: Border.all(color: AetherColors.hairline),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ItemCategory>(
                      value: category,
                      isExpanded: true,
                      dropdownColor: AetherColors.surface,
                      items: [
                        for (final c in ItemCategory.values)
                          DropdownMenuItem(
                              value: c, child: Text(c.name, style: AetherType.body.copyWith(fontSize: 13))),
                      ],
                      onChanged: (v) => setState(() => category = v ?? ItemCategory.misc),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return ItemDefinition(
    id: id.text.trim(),
    displayName: name.text.trim(),
    description: description.text.trim(),
    category: category,
  );
}

Future<CodexPlace?> _editCodexPlace(BuildContext context, CodexPlace? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo lugar' : 'Editar lugar',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        _textRow('Descripción', description, maxLines: 3),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return CodexPlace(id: id.text.trim(), displayName: name.text.trim(), description: description.text.trim());
}

Future<CodexTerm?> _editCodexTerm(BuildContext context, CodexTerm? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo término' : 'Editar término',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        _textRow('Descripción', description, maxLines: 3),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return CodexTerm(id: id.text.trim(), displayName: name.text.trim(), description: description.text.trim());
}

Future<CharacterTagRule?> _editCharacterTag(BuildContext context, CharacterTagRule? existing) async {
  final flag = TextEditingController(text: existing?.flagKey ?? '');
  final label = TextEditingController(text: existing?.label ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nueva marca' : 'Editar marca',
      fields: [
        _textRow('Flag que la activa', flag),
        _textRow('Texto de la marca', label),
      ]);
  if (!ok || flag.text.trim().isEmpty || label.text.trim().isEmpty) return null;
  return CharacterTagRule(flagKey: flag.text.trim(), label: label.text.trim());
}

Future<CharacterOrigin?> _editOrigin(
  BuildContext context,
  CharacterOrigin? existing,
  List<String> attributeKeys,
) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final tagId = TextEditingController(text: existing?.tagId ?? '');
  final narrativeConnection = TextEditingController(text: existing?.narrativeConnection ?? '');
  final attributeControllers = {
    for (final key in attributeKeys)
      key: TextEditingController(text: (existing?.baseAttributes[key] ?? 1).toString()),
  };
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo origen' : 'Editar origen',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        _textRow('Etiqueta que otorga', tagId),
        _textRow('Conexión narrativa', narrativeConnection, maxLines: 2),
        if (attributeKeys.isNotEmpty) ...[
          _label('Atributos base'),
          const SizedBox(height: 8),
          Wrap(
            spacing: AetherSpace.sm,
            runSpacing: AetherSpace.sm,
            children: [
              for (final key in attributeKeys)
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(key),
                      const SizedBox(height: 6),
                      TextField(
                        controller: attributeControllers[key],
                        keyboardType: TextInputType.number,
                        style: AetherType.body.copyWith(fontSize: 13),
                        decoration: _fieldDecoration(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return CharacterOrigin(
    id: id.text.trim(),
    displayName: name.text.trim(),
    tagId: tagId.text.trim(),
    narrativeConnection: narrativeConnection.text.trim(),
    baseAttributes: {
      for (final entry in attributeControllers.entries)
        entry.key: int.tryParse(entry.value.text) ?? 1,
    },
  );
}

Future<Vow?> _editVow(BuildContext context, Vow? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final text = TextEditingController(text: existing?.text ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo juramento' : 'Editar juramento',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Texto', text, maxLines: 2),
      ]);
  if (!ok || id.text.trim().isEmpty || text.text.trim().isEmpty) return null;
  return Vow(id: id.text.trim(), text: text.text.trim());
}

Future<ToneOption?> _editTone(BuildContext context, ToneOption? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final label = TextEditingController(text: existing?.label ?? '');
  final blurb = TextEditingController(text: existing?.blurb ?? '');
  final preview = TextEditingController(text: existing?.previewText ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo tono' : 'Editar tono',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', label),
        _textRow('Descriptor breve', blurb),
        _textRow('Texto de muestra', preview, maxLines: 3),
      ]);
  if (!ok || id.text.trim().isEmpty || label.text.trim().isEmpty) return null;
  return ToneOption(
    id: id.text.trim(),
    label: label.text.trim(),
    blurb: blurb.text.trim(),
    previewText: preview.text.trim(),
  );
}

Future<RankDefinition?> _editRank(BuildContext context, RankDefinition? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final level = TextEditingController(text: (existing?.level ?? 1).toString());
  final expRequired = TextEditingController(text: (existing?.expRequired ?? 0).toString());
  final milestoneFlag = TextEditingController(text: existing?.milestoneFlag ?? '');
  final reward = TextEditingController(text: existing?.reward ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo rango' : 'Editar rango',
      fields: [
        _textRow('Id (interno)', id),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Nivel'),
              const SizedBox(height: 8),
              TextField(
                  controller: level,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
          const SizedBox(width: AetherSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('EXP requerida'),
              const SizedBox(height: 8),
              TextField(
                  controller: expRequired,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
        ]),
        const SizedBox(height: AetherSpace.md),
        _textRow('Flag de hito (opcional)', milestoneFlag),
        _textRow('Recompensa', reward, maxLines: 2),
      ]);
  if (!ok || id.text.trim().isEmpty) return null;
  return RankDefinition(
    id: id.text.trim(),
    level: int.tryParse(level.text) ?? 1,
    expRequired: int.tryParse(expRequired.text) ?? 0,
    milestoneFlag: milestoneFlag.text.trim().isEmpty ? null : milestoneFlag.text.trim(),
    reward: reward.text.trim(),
  );
}

Future<AbstractOpponent?> _editOpponent(BuildContext context, AbstractOpponent? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final maxGuard = TextEditingController(text: (existing?.maxGuard ?? 3).toString());
  final typicalDamage = TextEditingController(text: (existing?.typicalDamage ?? 0).toString());
  final nonviolentAlternative = TextEditingController(text: existing?.nonviolentAlternative ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nuevo oponente' : 'Editar oponente',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Guardia máxima'),
              const SizedBox(height: 8),
              TextField(
                  controller: maxGuard,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
          const SizedBox(width: AetherSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Daño típico al fallar'),
              const SizedBox(height: 8),
              TextField(
                  controller: typicalDamage,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
        ]),
        const SizedBox(height: AetherSpace.md),
        _textRow('Alternativa no violenta', nonviolentAlternative, maxLines: 2),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return AbstractOpponent(
    id: id.text.trim(),
    displayName: name.text.trim(),
    maxGuard: int.tryParse(maxGuard.text) ?? 3,
    typicalDamage: int.tryParse(typicalDamage.text) ?? 0,
    nonviolentAlternative: nonviolentAlternative.text.trim(),
  );
}

Future<Technique?> _editTechnique(BuildContext context, Technique? existing) async {
  final id = TextEditingController(text: existing?.id ?? '');
  final name = TextEditingController(text: existing?.displayName ?? '');
  final costQi = TextEditingController(text: (existing?.costQi ?? 0).toString());
  final costLedgerDebt = TextEditingController(text: (existing?.costLedgerDebt ?? 0).toString());
  final primaryAttribute = TextEditingController(text: existing?.primaryAttribute ?? '');
  final effect = TextEditingController(text: existing?.effect ?? '');
  final mechanicalBonus = TextEditingController(text: existing?.mechanicalBonus ?? '');
  final restriction = TextEditingController(text: existing?.restriction ?? '');
  final ok = await _confirmDialog(context,
      title: existing == null ? 'Nueva técnica' : 'Editar técnica',
      fields: [
        _textRow('Id (interno)', id),
        _textRow('Nombre', name),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Costo en qi'),
              const SizedBox(height: 8),
              TextField(
                  controller: costQi,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
          const SizedBox(width: AetherSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Costo en deuda'),
              const SizedBox(height: 8),
              TextField(
                  controller: costLedgerDebt,
                  keyboardType: TextInputType.number,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: _fieldDecoration()),
            ]),
          ),
        ]),
        const SizedBox(height: AetherSpace.md),
        _textRow('Atributo primario (opcional)', primaryAttribute),
        _textRow('Efecto', effect, maxLines: 2),
        _textRow('Bonus mecánico', mechanicalBonus),
        _textRow('Restricción de uso', restriction),
      ]);
  if (!ok || id.text.trim().isEmpty || name.text.trim().isEmpty) return null;
  return Technique(
    id: id.text.trim(),
    displayName: name.text.trim(),
    costQi: int.tryParse(costQi.text) ?? 0,
    costLedgerDebt: int.tryParse(costLedgerDebt.text) ?? 0,
    primaryAttribute: primaryAttribute.text.trim().isEmpty ? null : primaryAttribute.text.trim(),
    effect: effect.text.trim(),
    mechanicalBonus: mechanicalBonus.text.trim(),
    restriction: restriction.text.trim(),
  );
}
