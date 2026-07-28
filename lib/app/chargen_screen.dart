import 'package:flutter/material.dart';

import '../core/engine/create_character.dart';
import '../core/state/character.dart';
import '../core/world/world.dart';
import 'design/breakpoints.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'widgets/atmosphere.dart';
import 'widgets/step_dots.dart';
import 'world_select_screen.dart';

/// Structured character creation (campaign-bible §5): name, origin, the free
/// `+1` point, vow and an optional personal item — meant to take under three
/// minutes. Only shown for a world that declares chargen origins; a world
/// without them (Fase 0 style) skips straight from [WorldSelectScreen] to
/// [GameScreen] with `world.startingCharacter`.
///
/// Reflowed (V2 design prototype §2c/§5b) into 3 steps rather than one long
/// scroll: "Nombre y origen", "Tu voz" (tone + vow), "Últimos detalles"
/// (personal item + a live-updating character-sheet preview). The world
/// itself is never a step here — unlike the prototype's own mockup, which
/// bundles world selection into chargen, this app always picks the world
/// first (`WorldSelectScreen`/`CreateStoryScreen`), so by the time a player
/// reaches this screen the world is already fixed.
class ChargenScreen extends StatefulWidget {
  const ChargenScreen({
    super.key,
    required this.controller,
    required this.worldSlug,
    required this.world,
    this.forceNew = false,
    this.alwaysCreateNew = false,
  });

  final GameController controller;
  final String worldSlug;
  final World world;

  /// Passed through to `GameController.start` — true when this chargen was
  /// reached via "reiniciar historia" and any existing session for this
  /// world should be abandoned rather than resumed.
  final bool forceNew;

  /// Passed through to `GameController.start` — true when this chargen was
  /// reached by picking a genre on `CreateStoryScreen` ("crea tu propia
  /// historia"): that flow always creates one more story rather than
  /// resuming or abandoning an existing one, since a player can have several
  /// active sessions for the same freeform world at once (CLAUDE.md Fase 2).
  final bool alwaysCreateNew;

  @override
  State<ChargenScreen> createState() => _ChargenScreenState();
}

const _stepCount = 3;
const _stepTitles = ['Nombre y origen', 'Tu voz', 'Últimos detalles'];

class _ChargenScreenState extends State<ChargenScreen> {
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _personalItemController = TextEditingController();
  String? _originId;
  String? _freeAttributePoint;
  String? _vowId;
  String? _chosenTone;
  int _step = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _personalItemController.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      (!widget.world.hasCustomizableName || _nameController.text.trim().isNotEmpty) &&
      _originId != null &&
      (!widget.world.hasFreeAttributePoint || _freeAttributePoint != null);

  bool get _step2Valid => _vowId != null;

  bool get _canConfirm => _step1Valid && _step2Valid && !_submitting;

  bool get _canAdvance => switch (_step) {
        0 => _step1Valid,
        1 => _step2Valid,
        _ => _canConfirm,
      };

  /// A live preview of the character these choices would build, via the same
  /// pure domain call [_confirm] eventually makes for real — shown on the
  /// last step (V2 prototype's "Así entras al mundo"). `null` until both an
  /// origin and a vow are chosen, which step gating already guarantees by
  /// the time step 2 (the last one) is reachable.
  Character? get _preview {
    final originId = _originId;
    final vowId = _vowId;
    if (originId == null || vowId == null) return null;
    return const CreateCharacter().call(
      widget.world,
      CreateCharacterInput(
        name: widget.world.hasCustomizableName
            ? _nameController.text.trim()
            : widget.world.startingCharacter.name,
        originId: originId,
        freeAttributePoint: _freeAttributePoint,
        vowId: vowId,
        personalItem: _personalItemController.text.trim(),
        chosenTone: _chosenTone,
      ),
    );
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => WorldSelectScreen(controller: widget.controller),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _advance() {
    if (!_canAdvance) return;
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
    } else {
      _confirm();
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final world = widget.world;
    await widget.controller.start(
      widget.worldSlug,
      chargenInput: CreateCharacterInput(
        name: world.hasCustomizableName
            ? _nameController.text.trim()
            : world.startingCharacter.name,
        originId: _originId!,
        freeAttributePoint: _freeAttributePoint,
        vowId: _vowId!,
        personalItem: _personalItemController.text.trim(),
        chosenTone: _chosenTone,
      ),
      forceNew: widget.forceNew,
      alwaysCreateNew: widget.alwaysCreateNew,
      title: widget.alwaysCreateNew && _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
    );

    if (!mounted) return;
    if (widget.controller.error != null) {
      setState(() {
        _submitting = false;
        _error = widget.controller.error;
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) =>
            GameScreen(controller: widget.controller, worldSlug: widget.worldSlug),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Widget _stepContent(BuildContext context, {required bool wide}) {
    return AnimatedSwitcher(
      duration: AetherMotion.base,
      switchInCurve: AetherMotion.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        key: ValueKey(_step),
        padding: const EdgeInsets.fromLTRB(
            AetherSpace.xl, AetherSpace.lg, AetherSpace.xl, AetherSpace.xl),
        child: switch (_step) {
          0 => _StepOne(
              world: widget.world,
              alwaysCreateNew: widget.alwaysCreateNew,
              titleController: _titleController,
              nameController: _nameController,
              originId: _originId,
              freeAttributePoint: _freeAttributePoint,
              onOriginTap: (id) => setState(() => _originId = id),
              onFreePointTap: (attr) => setState(() => _freeAttributePoint = attr),
              onFieldChanged: () => setState(() {}),
            ),
          1 => _StepTwo(
              world: widget.world,
              vowId: _vowId,
              chosenTone: _chosenTone,
              onVowTap: (id) => setState(() => _vowId = id),
              onToneTap: (id) =>
                  setState(() => _chosenTone = _chosenTone == id ? null : id),
            ),
          _ => _StepThree(
              personalItemController: _personalItemController,
              // The wide layout's `_SidePanel` already shows the live
              // preview alongside every step -- showing it a second time
              // inline here would just duplicate it.
              preview: wide ? null : _preview,
              world: widget.world,
              onFieldChanged: () => setState(() {}),
              error: _error,
            ),
        },
      ),
    );
  }

  Widget _cta() => Padding(
        padding: const EdgeInsets.all(AetherSpace.xl),
        child: _StepCta(
          enabled: _canAdvance,
          busy: _submitting,
          label: _step < _stepCount - 1 ? 'Siguiente' : 'Confirmar ficha',
          accent: WorldTheme.forWorld(widget.world).accent,
          onTap: _advance,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AetherBreakpoints.tablet;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 980 : 560),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _SidePanel(
                                world: widget.world,
                                step: _step,
                                preview: _preview,
                              ),
                            ),
                            const SizedBox(width: AetherSpace.xl),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _StepHeader(step: _step, onBack: _goBack),
                                  Expanded(child: _stepContent(context, wide: true)),
                                  _cta(),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StepHeader(step: _step, onBack: _goBack),
                            Expanded(child: _stepContent(context, wide: false)),
                            _cta(),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The wide-layout companion column (V2 §1c's general pattern: wide screens
/// get more context, not more steps) — the world's name, a checklist of the
/// 3 steps so progress stays visible while the right column swaps content,
/// and — once there's enough chosen to build one — the same live
/// `_CharacterPreview` step 3 already showed, surfaced earlier instead of
/// only at the end.
class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.world, required this.step, required this.preview});

  final World world;
  final int step;
  final Character? preview;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, AetherSpace.xl, 0, AetherSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(world.name, style: AetherType.display.copyWith(fontSize: 22)),
          const SizedBox(height: AetherSpace.xl),
          for (var i = 0; i < _stepCount; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.md),
              child: Row(
                children: [
                  Icon(
                    i < step
                        ? Icons.check_circle_rounded
                        : (i == step
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    size: 18,
                    color: i <= step ? AetherColors.gold : AetherColors.parchmentFaint,
                  ),
                  const SizedBox(width: AetherSpace.sm),
                  // Expanded + ellipsis: at a large OS text-scale setting,
                  // a step title's single-line intrinsic width can exceed
                  // this side panel's own fixed column width (V2 Stage 8) --
                  // without a flexible wrapper, a bare `Text` ignores that
                  // limit instead of wrapping/shrinking into it.
                  Expanded(
                    child: Text(
                      _stepTitles[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AetherType.label.copyWith(
                        color: i == step
                            ? AetherColors.goldBright
                            : (i < step ? AetherColors.parchment : AetherColors.parchmentFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (preview != null) ...[
            const SizedBox(height: AetherSpace.lg),
            _CharacterPreview(world: world, character: preview!),
          ],
        ],
      ),
    );
  }
}

/// Back arrow + step title + progress pips — the only chrome shared by every
/// step (V2 prototype §2c's `cgBack`/`cgStepLabel`/pip row). The back arrow
/// steps backward, or leaves chargen entirely from step 0.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AetherSpace.md, AetherSpace.lg, AetherSpace.xl, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Atrás',
            icon: const Icon(Icons.arrow_back_rounded,
                color: AetherColors.goldSoft, size: 22),
          ),
          const SizedBox(width: AetherSpace.xs),
          Expanded(
            child: Text(
              'Paso ${step + 1} de $_stepCount · ${_stepTitles[step]}',
              style: AetherType.overline.copyWith(color: AetherColors.parchmentFaint),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StepDots(count: _stepCount, current: step),
        ],
      ),
    );
  }
}

class _StepOne extends StatelessWidget {
  const _StepOne({
    required this.world,
    required this.alwaysCreateNew,
    required this.titleController,
    required this.nameController,
    required this.originId,
    required this.freeAttributePoint,
    required this.onOriginTap,
    required this.onFreePointTap,
    required this.onFieldChanged,
  });

  final World world;
  final bool alwaysCreateNew;
  final TextEditingController titleController;
  final TextEditingController nameController;
  final String? originId;
  final String? freeAttributePoint;
  final ValueChanged<String> onOriginTap;
  final ValueChanged<String> onFreePointTap;
  final VoidCallback onFieldChanged;

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(world).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(world.name, style: AetherType.display),
        const SizedBox(height: AetherSpace.xl),
        if (alwaysCreateNew) ...[
          Text('Título de tu historia (opcional)', style: AetherType.overline),
          const SizedBox(height: AetherSpace.sm),
          _NameField(
            controller: titleController,
            hint: 'Cómo quieres llamar a esta historia',
            onChanged: onFieldChanged,
          ),
          const SizedBox(height: AetherSpace.xl),
        ],
        if (world.hasCustomizableName) ...[
          Text('Nombre', style: AetherType.overline),
          const SizedBox(height: AetherSpace.sm),
          _NameField(controller: nameController, onChanged: onFieldChanged),
          const SizedBox(height: AetherSpace.xl),
        ] else ...[
          Text('Protagonista', style: AetherType.overline),
          const SizedBox(height: AetherSpace.sm),
          Text(world.startingCharacter.name, style: AetherType.title),
          const SizedBox(height: 4),
          Text(
            'Esta historia sigue a un personaje ya definido — tú eliges cómo llegó hasta acá y qué hace de ahora en más.',
            style: AetherType.caption,
          ),
          const SizedBox(height: AetherSpace.xl),
        ],
        Text('Origen', style: AetherType.overline),
        const SizedBox(height: AetherSpace.sm),
        for (final origin in world.origins)
          _SelectableCard(
            title: origin.displayName,
            subtitle: origin.narrativeConnection,
            selected: originId == origin.id,
            accent: accent,
            onTap: () => onOriginTap(origin.id),
          ),
        if (world.hasFreeAttributePoint) ...[
          const SizedBox(height: AetherSpace.xl),
          Text('Punto libre (+1 a un atributo)', style: AetherType.overline),
          const SizedBox(height: AetherSpace.sm),
          Wrap(
            spacing: AetherSpace.sm,
            runSpacing: AetherSpace.sm,
            children: [
              for (final attribute in world.attributeKeys)
                _AttributeChip(
                  label: attribute,
                  selected: freeAttributePoint == attribute,
                  accent: accent,
                  onTap: () => onFreePointTap(attribute),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepTwo extends StatelessWidget {
  const _StepTwo({
    required this.world,
    required this.vowId,
    required this.chosenTone,
    required this.onVowTap,
    required this.onToneTap,
  });

  final World world;
  final String? vowId;
  final String? chosenTone;
  final ValueChanged<String> onVowTap;
  final ValueChanged<String> onToneTap;

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(world).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (world.tones.isNotEmpty) ...[
          Text('Tono de la narración (opcional)', style: AetherType.overline),
          const SizedBox(height: AetherSpace.sm),
          for (final tone in world.tones)
            _SelectableCard(
              title: tone.label,
              subtitle: tone.blurb,
              selected: chosenTone == tone.id,
              accent: accent,
              onTap: () => onToneTap(tone.id),
            ),
          if (chosenTone != null) ...[
            const SizedBox(height: AetherSpace.sm),
            Container(
              padding: const EdgeInsets.all(AetherSpace.md),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AetherRadius.allSm,
              ),
              child: Text(
                world.toneByIdOrNull(chosenTone)!.previewText,
                style: AetherType.caption
                    .copyWith(fontStyle: FontStyle.italic, color: AetherColors.parchment),
              ),
            ),
          ],
          const SizedBox(height: AetherSpace.xl),
        ],
        Text(world.chargenVowLabel, style: AetherType.overline),
        const SizedBox(height: AetherSpace.sm),
        for (final vow in world.vows)
          _SelectableCard(
            title: '"${vow.text}"',
            selected: vowId == vow.id,
            accent: accent,
            onTap: () => onVowTap(vow.id),
          ),
      ],
    );
  }
}

class _StepThree extends StatelessWidget {
  const _StepThree({
    required this.personalItemController,
    required this.preview,
    required this.world,
    required this.onFieldChanged,
    required this.error,
  });

  final TextEditingController personalItemController;
  final Character? preview;
  final World world;
  final VoidCallback onFieldChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Objeto personal (opcional)', style: AetherType.overline),
        const SizedBox(height: AetherSpace.sm),
        _NameField(
          controller: personalItemController,
          hint: 'Algo que alguien importante te entregó',
          onChanged: onFieldChanged,
        ),
        const SizedBox(height: AetherSpace.xl),
        if (preview != null) _CharacterPreview(world: world, character: preview!),
        if (error != null) ...[
          const SizedBox(height: AetherSpace.lg),
          Text(error!, style: AetherType.body.copyWith(color: AetherColors.failure)),
        ],
      ],
    );
  }
}

/// A live-updating summary of the character these choices would build (V2
/// prototype §2c: "Así entras al mundo") — every field on it already exists
/// on [Character]; this just surfaces it before the player commits, instead
/// of finding out for the first time on the game screen.
class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({required this.world, required this.character});

  final World world;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final vow = world.vowById(character.vowId!);
    final accent = WorldTheme.forWorld(world).accent;
    return Container(
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Así entras al mundo',
              style: AetherType.overline.copyWith(color: accent)),
          const SizedBox(height: AetherSpace.md),
          Text(
            character.name.isEmpty ? world.startingCharacter.name : character.name,
            style: AetherType.title,
          ),
          if (world.attributeKeys.isNotEmpty) ...[
            const SizedBox(height: AetherSpace.md),
            Wrap(
              spacing: AetherSpace.sm,
              runSpacing: AetherSpace.sm,
              children: [
                for (final key in world.attributeKeys)
                  _StatPill(label: key, value: character.attributes[key] ?? 1),
              ],
            ),
          ],
          if ((character.personalItem ?? '').isNotEmpty) ...[
            const SizedBox(height: AetherSpace.md),
            Text(character.personalItem!, style: AetherType.caption),
          ],
          const SizedBox(height: AetherSpace.md),
          Container(height: 1, color: AetherColors.hairline),
          const SizedBox(height: AetherSpace.md),
          Text('"${vow.text}"',
              style: AetherType.body.copyWith(fontStyle: FontStyle.italic, color: accent)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: AetherColors.void_,
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AetherType.caption.copyWith(color: AetherColors.parchmentDim)),
          const SizedBox(width: 6),
          Text('$value',
              style: const TextStyle(
                  color: AetherColors.parchment,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged, this.hint});

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: AetherType.body.copyWith(fontSize: 15),
      cursorColor: AetherColors.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        hintText: hint,
        hintStyle:
            AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 15),
        filled: true,
        fillColor: AetherColors.void_,
        enabledBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.gold),
        ),
      ),
    );
  }
}

/// Splits an origin's flavor text from its mechanical "Pasiva: ..." clause
/// (campaign-bible convention — see `assets/worlds/*.json`'s
/// `narrative_connection` fields) so the two render as visually distinct
/// blocks instead of one run-on paragraph. Origins that declare no passive
/// (e.g. `xianxia_lianshu`'s) just get a null [passive].
({String description, String? passive}) _splitPassive(String? text) {
  if (text == null || text.isEmpty) return (description: '', passive: null);
  const marker = 'Pasiva:';
  final index = text.indexOf(marker);
  if (index == -1) return (description: text, passive: null);
  return (
    description: text.substring(0, index).trim(),
    passive: text.substring(index + marker.length).trim(),
  );
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.title,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = _splitPassive(subtitle);
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AetherMotion.fast,
          padding: const EdgeInsets.all(AetherSpace.md),
          decoration: BoxDecoration(
            color: selected ? AetherColors.surfaceRaised : AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(
              color: selected ? accent : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? accent : AetherColors.parchmentFaint,
              ),
              const SizedBox(width: AetherSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AetherType.label),
                    if (parts.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(parts.description, style: AetherType.caption),
                    ],
                    if (parts.passive != null) ...[
                      const SizedBox(height: AetherSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AetherSpace.sm, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: AetherRadius.allSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PASIVA',
                                style: AetherType.overline
                                    .copyWith(fontSize: 9.5, color: accent)),
                            const SizedBox(height: 2),
                            Text(parts.passive!,
                                style: AetherType.caption
                                    .copyWith(color: AetherColors.parchment)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  const _AttributeChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.sm),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AetherColors.surface,
          borderRadius: AetherRadius.allPill,
          border: Border.all(
            color: selected ? accent : AetherColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AetherType.label.copyWith(
            fontSize: 14,
            color: selected ? accent : AetherColors.parchment,
          ),
        ),
      ),
    );
  }
}

class _StepCta extends StatelessWidget {
  const _StepCta({
    required this.enabled,
    required this.onTap,
    required this.busy,
    required this.label,
    required this.accent,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool busy;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.white, 0.3) ?? accent])
              : null,
          color: enabled ? null : AetherColors.surfaceRaised,
          borderRadius: AetherRadius.allMd,
          boxShadow: enabled ? AetherShadow.glow(accent, strength: 0.35) : null,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AetherColors.void_),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? AetherColors.void_ : AetherColors.parchmentFaint,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: AetherSpace.sm),
                    Icon(Icons.east_rounded,
                        size: 19,
                        color: enabled ? AetherColors.void_ : AetherColors.parchmentFaint),
                  ],
                ),
        ),
      ),
    );
  }
}
