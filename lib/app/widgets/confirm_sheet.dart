import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// V2 reusable destructive/irreversible-action confirmation, as a bottom
/// sheet instead of an `AlertDialog` (V2 design prototype: abandon-story
/// state in §1a). Returns `true` only if the player tapped [confirmLabel];
/// `false` for cancel, dismiss-by-tapping-outside, or swipe-to-close.
///
/// Not yet wired into any call site — the app's 4 existing confirmation
/// dialogs (`world_select_screen.dart`'s abandon/restart,
/// `game_screen.dart`'s story-choice/ending confirms) still use
/// `showDialog`/`AlertDialog` and keep working exactly as before. Migrating
/// them to this widget is Stage 2/4/5 work (V2 Implementation Plan), done
/// call-site by call-site, not as part of introducing the component itself.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = true,
  IconData icon = Icons.local_fire_department_rounded,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (sheetContext) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AetherColors.failure : AetherColors.gold;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AetherSpace.lg, AetherSpace.xl, AetherSpace.lg, AetherSpace.md),
        child: Container(
          padding: const EdgeInsets.all(AetherSpace.xl),
          decoration: BoxDecoration(
            color: AetherColors.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: AetherRadius.lg),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
            boxShadow: AetherShadow.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: AetherSpace.lg),
              Text(title, style: AetherType.title),
              const SizedBox(height: AetherSpace.sm),
              Text(message, style: AetherType.body),
              const SizedBox(height: AetherSpace.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    side: BorderSide(color: accent.withValues(alpha: 0.55)),
                    foregroundColor: accent,
                    padding:
                        const EdgeInsets.symmetric(vertical: AetherSpace.md),
                    shape:
                        RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                  ),
                  child: Text(confirmLabel,
                      style: AetherType.label.copyWith(color: accent)),
                ),
              ),
              const SizedBox(height: AetherSpace.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AetherColors.goldSoft,
                    padding:
                        const EdgeInsets.symmetric(vertical: AetherSpace.md),
                  ),
                  child: Text(cancelLabel, style: AetherType.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
