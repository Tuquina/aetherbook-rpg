import 'package:flutter/material.dart';

import '../core/engine/create_character.dart';
import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'widgets/atmosphere.dart';

/// Structured character creation (campaign-bible §5): name, origin, the free
/// `+1` point, vow and an optional personal item — meant to take under three
/// minutes. Only shown for a world that declares chargen origins; a world
/// without them (Fase 0 style) skips straight from [SplashScreen] to
/// [GameScreen] with `world.startingCharacter`.
class ChargenScreen extends StatefulWidget {
  const ChargenScreen({
    super.key,
    required this.controller,
    required this.worldSlug,
    required this.world,
  });

  final GameController controller;
  final String worldSlug;
  final World world;

  @override
  State<ChargenScreen> createState() => _ChargenScreenState();
}

class _ChargenScreenState extends State<ChargenScreen> {
  final _nameController = TextEditingController();
  final _personalItemController = TextEditingController();
  String? _originId;
  String? _freeAttributePoint;
  String? _vowId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _personalItemController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _nameController.text.trim().isNotEmpty &&
      _originId != null &&
      _freeAttributePoint != null &&
      _vowId != null &&
      !_submitting;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    await widget.controller.start(
      widget.worldSlug,
      chargenInput: CreateCharacterInput(
        name: _nameController.text.trim(),
        originId: _originId!,
        freeAttributePoint: _freeAttributePoint!,
        vowId: _vowId!,
        personalItem: _personalItemController.text.trim(),
      ),
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
        pageBuilder: (_, _, _) => GameScreen(controller: widget.controller),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(AetherSpace.xl),
                children: [
                  Text(world.name, style: AetherType.display),
                  const SizedBox(height: AetherSpace.xs),
                  Text('Creá tu personaje', style: AetherType.title),
                  const SizedBox(height: AetherSpace.xl),
                  Text('Nombre', style: AetherType.overline),
                  const SizedBox(height: AetherSpace.sm),
                  _NameField(controller: _nameController, onChanged: () => setState(() {})),
                  const SizedBox(height: AetherSpace.xl),
                  Text('Origen', style: AetherType.overline),
                  const SizedBox(height: AetherSpace.sm),
                  for (final origin in world.origins)
                    _SelectableCard(
                      title: origin.displayName,
                      subtitle: origin.narrativeConnection,
                      selected: _originId == origin.id,
                      onTap: () => setState(() => _originId = origin.id),
                    ),
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
                          selected: _freeAttributePoint == attribute,
                          onTap: () => setState(() => _freeAttributePoint = attribute),
                        ),
                    ],
                  ),
                  const SizedBox(height: AetherSpace.xl),
                  Text('Juramento', style: AetherType.overline),
                  const SizedBox(height: AetherSpace.sm),
                  for (final vow in world.vows)
                    _SelectableCard(
                      title: '"${vow.text}"',
                      selected: _vowId == vow.id,
                      onTap: () => setState(() => _vowId = vow.id),
                    ),
                  const SizedBox(height: AetherSpace.xl),
                  Text('Objeto personal (opcional)', style: AetherType.overline),
                  const SizedBox(height: AetherSpace.sm),
                  _NameField(
                    controller: _personalItemController,
                    hint: 'Algo que alguien importante te entregó',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: AetherSpace.xxl),
                  if (_error != null) ...[
                    Text(_error!,
                        style: AetherType.body.copyWith(color: AetherColors.failure)),
                    const SizedBox(height: AetherSpace.lg),
                  ],
                  _ConfirmButton(enabled: _canConfirm, onTap: _confirm, busy: _submitting),
                ],
              ),
            ),
          ),
        ),
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

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              color: selected ? AetherColors.gold : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AetherColors.gold : AetherColors.parchmentFaint,
              ),
              const SizedBox(width: AetherSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AetherType.label),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AetherType.caption),
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
  const _AttributeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AetherColors.goldGlow : AetherColors.surface,
          borderRadius: AetherRadius.allPill,
          border: Border.all(
            color: selected ? AetherColors.gold : AetherColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AetherType.label.copyWith(
            fontSize: 14,
            color: selected ? AetherColors.goldSoft : AetherColors.parchment,
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.enabled, required this.onTap, required this.busy});

  final bool enabled;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: [AetherColors.gold, AetherColors.goldBright])
              : null,
          color: enabled ? null : AetherColors.surfaceRaised,
          borderRadius: AetherRadius.allMd,
          boxShadow: enabled ? AetherShadow.glow(AetherColors.gold, strength: 0.35) : null,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AetherColors.void_),
                )
              : Text(
                  'Confirmar ficha',
                  style: TextStyle(
                    color: enabled ? AetherColors.void_ : AetherColors.parchmentFaint,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
