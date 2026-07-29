import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';

/// Publish-rights notice (V2 design prototype §10c) — shown once, right
/// before publishing, never earlier. Returns `true` if the author checked
/// the acknowledgement and tapped "Publicar", `null`/`false` otherwise. Pure
/// presentation: the caller decides what accepting actually does
/// (`CampaignDraftRepositoryPort.publishDraft`).
class RightsNoticeDialog extends StatefulWidget {
  const RightsNoticeDialog({super.key, required this.storyTitle});

  final String storyTitle;

  static Future<bool> open(BuildContext context, {required String storyTitle}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RightsNoticeDialog(storyTitle: storyTitle),
    );
    return result ?? false;
  }

  @override
  State<RightsNoticeDialog> createState() => _RightsNoticeDialogState();
}

class _RightsNoticeDialogState extends State<RightsNoticeDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AetherSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF100E0C),
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: AetherColors.hairlineStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                decoration: const BoxDecoration(
                  color: AetherColors.surface,
                  borderRadius: BorderRadius.vertical(top: AetherRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.publish_rounded, size: 19, color: AetherColors.goldBright),
                    const SizedBox(width: AetherSpace.sm),
                    Expanded(
                      child: Text('Publicar «${widget.storyTitle}»',
                          style: const TextStyle(
                              fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AetherSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuando publiques, cualquiera podrá jugarla desde la biblioteca. '
                      'Antes, esto en claro:',
                      style: AetherType.body.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: AetherSpace.lg),
                    const _RightsPoint(
                      icon: Icons.person_rounded,
                      color: AetherColors.success,
                      title: 'La historia sigue siendo tuya',
                      body:
                          'Conservas la autoría. Puedes despublicarla o borrarla cuando quieras, y tu nombre aparece en su ficha.',
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    const _RightsPoint(
                      icon: Icons.handshake_rounded,
                      color: AetherColors.goldBright,
                      title: 'Nos das permiso para usarla dentro de Aetherbook',
                      body:
                          'Una licencia mundial, gratuita y no exclusiva para alojarla, mostrarla, traducirla, adaptarla al formato de la app y enseñarla en material de difusión. Sólo para que la app funcione y se dé a conocer.',
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    const _RightsPoint(
                      icon: Icons.history_rounded,
                      color: AetherColors.parchmentDim,
                      title: 'Si la borras, dejamos de mostrarla',
                      body:
                          'Las partidas ya empezadas por otros lectores pueden terminarse, y las copias en material ya publicado siguen existiendo.',
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    const _RightsPoint(
                      icon: Icons.gavel_rounded,
                      color: AetherColors.failure,
                      title: 'Y confirmas que es tuya',
                      body:
                          'Que la escribiste tú y que no usa personajes ni mundos de nadie con derechos sobre ellos.',
                    ),
                    const SizedBox(height: AetherSpace.lg),
                    InkWell(
                      onTap: () => setState(() => _accepted = !_accepted),
                      borderRadius: AetherRadius.allMd,
                      child: Container(
                        padding: const EdgeInsets.all(AetherSpace.sm + 3),
                        decoration: BoxDecoration(
                          color: AetherColors.goldBright.withValues(alpha: 0.04),
                          borderRadius: AetherRadius.allMd,
                          border: Border.all(color: AetherColors.goldBright.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 19,
                              height: 19,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: _accepted ? AetherColors.goldBright : null,
                                borderRadius: AetherRadius.allSm,
                                border: Border.all(
                                    color: AetherColors.goldBright.withValues(alpha: _accepted ? 1 : 0.6)),
                              ),
                              child: _accepted
                                  ? const Icon(Icons.check_rounded, size: 14, color: AetherColors.void_)
                                  : null,
                            ),
                            const SizedBox(width: AetherSpace.sm + 2),
                            Expanded(
                              child: Text(
                                'He leído esto y publico «${widget.storyTitle}» bajo estas condiciones.',
                                style: AetherType.body.copyWith(fontSize: 12.5, color: AetherColors.parchment),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AetherSpace.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Resumen en claro. El texto que manda son las condiciones para autores.',
                            style: EditorType.meta,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Ahora no',
                              style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
                        ),
                        const SizedBox(width: AetherSpace.sm),
                        FilledButton(
                          onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AetherColors.goldBright,
                            foregroundColor: AetherColors.void_,
                            disabledBackgroundColor: AetherColors.surfaceRaised,
                            shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                          ),
                          child: Text('Publicar',
                              style: EditorType.button.copyWith(
                                  color: _accepted ? AetherColors.void_ : AetherColors.parchmentFaint)),
                        ),
                      ],
                    ),
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

class _RightsPoint extends StatelessWidget {
  const _RightsPoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.sm + 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: AetherSpace.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: EditorType.label.copyWith(color: AetherColors.goldSoft)),
                const SizedBox(height: 4),
                Text(body, style: AetherType.caption.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
