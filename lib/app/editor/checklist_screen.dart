import 'package:flutter/material.dart';

import '../../core/authoring/campaign_checklist.dart';
import '../../core/authoring/campaign_draft.dart';
import '../../core/narrative/story_node.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';

/// "Antes de publicar" (V2 design prototype §9i) — every [ChecklistIssue]
/// [CampaignChecklist] finds, split into what blocks publishing and what's
/// merely worth a look. Tapping an issue with a `nodeId` closes the screen
/// and hands that id back, so the caller (the map screen) can select it —
/// the mockup's "va directo ahí" affordance.
class ChecklistScreen {
  const ChecklistScreen._();

  static Future<String?> open(BuildContext context, {required CampaignDraft draft}) {
    final desktop = MediaQuery.sizeOf(context).width >= AetherBreakpoints.desktop;
    final blocking = CampaignChecklist.blocking(draft);
    final advisory = CampaignChecklist.advisory(draft);
    final endingCount = _endingCount(draft);
    if (desktop) {
      return showDialog<String>(
        context: context,
        builder: (_) => _ChecklistDialog(
          draft: draft,
          blocking: blocking,
          advisory: advisory,
          endingCount: endingCount,
        ),
      );
    }
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ChecklistPage(
          draft: draft,
          blocking: blocking,
          advisory: advisory,
          endingCount: endingCount,
        ),
      ),
    );
  }

  static int _endingCount(CampaignDraft draft) {
    var count = 0;
    for (final node in draft.graph.nodes.values) {
      if (node is ResolutionNode) count += node.endings.length;
    }
    return count;
  }
}

class _ChecklistDialog extends StatelessWidget {
  const _ChecklistDialog({
    required this.draft,
    required this.blocking,
    required this.advisory,
    required this.endingCount,
  });

  final CampaignDraft draft;
  final List<ChecklistIssue> blocking;
  final List<ChecklistIssue> advisory;
  final int endingCount;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AetherSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
        child: Container(
          decoration: BoxDecoration(
            color: AetherColors.ink,
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: AetherColors.hairlineStrong),
          ),
          child: Column(
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
                    const Icon(Icons.fact_check_rounded, size: 19, color: AetherColors.goldBright),
                    const SizedBox(width: AetherSpace.sm),
                    const Text('Antes de publicar',
                        style: TextStyle(
                            fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
                    const Spacer(),
                    Text('${draft.graph.nodes.length} escenas · $endingCount finales',
                        style: EditorType.meta),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AetherSpace.lg),
                  child: _ChecklistBody(blocking: blocking, advisory: advisory),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistPage extends StatelessWidget {
  const _ChecklistPage({
    required this.draft,
    required this.blocking,
    required this.advisory,
    required this.endingCount,
  });

  final CampaignDraft draft;
  final List<ChecklistIssue> blocking;
  final List<ChecklistIssue> advisory;
  final int endingCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      appBar: AppBar(
        backgroundColor: AetherColors.ink,
        iconTheme: const IconThemeData(color: AetherColors.goldSoft),
        title: const Text('Antes de publicar',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.huge),
        child: _ChecklistBody(blocking: blocking, advisory: advisory),
      ),
    );
  }
}

class _ChecklistBody extends StatelessWidget {
  const _ChecklistBody({required this.blocking, required this.advisory});

  final List<ChecklistIssue> blocking;
  final List<ChecklistIssue> advisory;

  @override
  Widget build(BuildContext context) {
    if (blocking.isEmpty && advisory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AetherSpace.lg),
        decoration: BoxDecoration(
          color: AetherColors.success.withValues(alpha: 0.05),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: AetherColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 22, color: AetherColors.success),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Text('No encontramos nada que arreglar. Lista para publicar.',
                  style: AetherType.body.copyWith(fontSize: 13.5)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blocking.isNotEmpty) ...[
          _Banner(
            icon: Icons.block_rounded,
            color: AetherColors.failure,
            title: '${blocking.length} cosa${blocking.length == 1 ? '' : 's'} '
                'impide${blocking.length == 1 ? '' : 'n'} publicar',
            subtitle: 'Un lector se quedaría sin saber qué pasa.',
          ),
          const SizedBox(height: AetherSpace.md),
          for (final issue in blocking)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.sm),
              child: _IssueRow(issue: issue, color: AetherColors.failure),
            ),
          const SizedBox(height: AetherSpace.lg),
        ],
        if (advisory.isNotEmpty) ...[
          _Banner(
            icon: Icons.visibility_rounded,
            color: const Color(0xFFD8B65E),
            title: '${advisory.length} cosa${advisory.length == 1 ? '' : 's'} '
                'para mirar, si querés',
            subtitle: 'La historia funciona igual, pero puede no ser lo que querías.',
          ),
          const SizedBox(height: AetherSpace.md),
          for (final issue in advisory)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.sm),
              child: _IssueRow(issue: issue, color: const Color(0xFFD8B65E)),
            ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AetherSpace.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: EditorType.label.copyWith(fontSize: 12.5, color: AetherColors.goldSoft)),
                const SizedBox(height: 2),
                Text(subtitle, style: AetherType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.color});

  final ChecklistIssue issue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final canJump = issue.nodeId != null;
    return InkWell(
      onTap: canJump ? () => Navigator.of(context).pop(issue.nodeId) : null,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 2),
        decoration: BoxDecoration(
          color: AetherColors.surface,
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.message,
                      style: AetherType.body.copyWith(fontSize: 12.5, color: AetherColors.parchment)),
                  if (issue.detail != null) ...[
                    const SizedBox(height: 3),
                    Text(issue.detail!, style: EditorType.hint),
                  ],
                ],
              ),
            ),
            if (canJump) ...[
              const SizedBox(width: AetherSpace.sm),
              Text('Ir ahí', style: EditorType.button.copyWith(color: color, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
