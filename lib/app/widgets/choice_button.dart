import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// A large, tactile decision button (GDD §9: "decisiones como botones grandes
/// al pie"). A gold accent rail on the left, the choice text, and a chevron;
/// it presses in and brightens on touch so choosing *feels* like an act.
class ChoiceButton extends StatefulWidget {
  const ChoiceButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pressed ? AetherColors.goldBright : AetherColors.gold;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: AetherMotion.fast,
        curve: AetherMotion.standard,
        child: AnimatedContainer(
          duration: AetherMotion.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: AetherSpace.lg, vertical: AetherSpace.lg),
          decoration: BoxDecoration(
            color: _pressed
                ? AetherColors.surfaceRaised
                : AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(
              color: _pressed
                  ? AetherColors.gold.withValues(alpha: 0.7)
                  : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AetherRadius.allPill,
                ),
              ),
              const SizedBox(width: AetherSpace.md),
              Expanded(child: Text(widget.label, style: AetherType.label)),
              const SizedBox(width: AetherSpace.sm),
              Icon(Icons.chevron_right,
                  size: 20, color: accent.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The free-action input (freeform mode): the player writes their own action.
class FreeActionField extends StatelessWidget {
  const FreeActionField({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
      style: AetherType.body.copyWith(fontSize: 15),
      cursorColor: AetherColors.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        hintText: 'O escribí tu propia acción…',
        hintStyle: AetherType.caption
            .copyWith(color: AetherColors.parchmentFaint, fontSize: 15),
        filled: true,
        fillColor: AetherColors.void_,
        suffixIcon: IconButton(
          icon: const Icon(Icons.send_rounded,
              color: AetherColors.gold, size: 20),
          onPressed: onSubmit,
        ),
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
