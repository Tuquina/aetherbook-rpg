import 'package:flutter/material.dart';

import '../core/state/game_session.dart';
import '../core/world/world.dart';
import '../ports/auth_port.dart';
import '../ports/settings_port.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'settings_screen.dart';
import 'widgets/atmosphere.dart';

const _monthNames = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Perfil (V2 design prototype §6a) — not an account settings panel, a
/// reading history: how many tomos, how many turns, which worlds, and what
/// happened to the vow chosen at chargen for each one. Everything here is
/// computed from real play data (`GameController.readingStats`), not a
/// mock — a brand-new account simply shows all zeros/empty sections rather
/// than the mockup's placeholder numbers.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    required this.authPort,
    required this.settingsPort,
  });

  final GameController controller;
  final AuthPort authPort;
  final SettingsPort settingsPort;

  static Route<void> route({
    required GameController controller,
    required AuthPort authPort,
    required SettingsPort settingsPort,
  }) =>
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          controller: controller,
          authPort: authPort,
          settingsPort: settingsPort,
        ),
      );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileData {
  const _ProfileData({required this.stats, required this.worlds});

  final List<SessionReadingStat> stats;
  final Map<String, World> worlds;
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<_ProfileData> _future = _load();

  Future<_ProfileData> _load() async {
    final stats = await widget.controller.readingStats();
    final worlds = <String, World>{};
    for (final slug in stats.map((s) => s.worldSlug).toSet()) {
      try {
        worlds[slug] = await widget.controller.loadWorldInfo(slug);
      } catch (_) {
        // A world whose content JSON no longer loads (renamed/removed slug)
        // just falls back to the raw slug in the breakdown below — never
        // crashes Perfil over one bad entry.
      }
    }
    return _ProfileData(stats: stats, worlds: worlds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FutureBuilder<_ProfileData>(
                future: _future,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.all(AetherSpace.xl),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: AetherColors.goldSoft),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).push(SettingsScreen.route(
                              controller: widget.controller,
                              settingsPort: widget.settingsPort,
                              authPort: widget.authPort,
                            )),
                            icon: const Icon(Icons.settings_outlined, color: AetherColors.parchmentDim),
                          ),
                        ],
                      ),
                      _Header(authPort: widget.authPort),
                      const SizedBox(height: AetherSpace.xl),
                      if (data == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AetherSpace.xxl),
                          child: Center(
                            child: CircularProgressIndicator(color: AetherColors.gold),
                          ),
                        )
                      else ...[
                        _StatsRow(stats: data.stats),
                        const SizedBox(height: AetherSpace.xl),
                        _SectionLabel('Dónde has estado'),
                        _WorldBreakdown(stats: data.stats, worlds: data.worlds),
                        const SizedBox(height: AetherSpace.xl),
                        _SectionLabel('Juramentos'),
                        _VowHistory(stats: data.stats, worlds: data.worlds),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.authPort});

  final AuthPort authPort;

  @override
  Widget build(BuildContext context) {
    final email = authPort.email;
    final initial = (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';
    final createdAt = authPort.accountCreatedAt;
    final since = createdAt == null ? null : _monthNames[createdAt.month - 1];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: AetherRadius.allLg,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AetherColors.surfaceRaised, AetherColors.ink],
            ),
            border: Border.all(color: AetherColors.gold.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text(initial,
              style: AetherType.display.copyWith(fontSize: 26, height: 1)),
        ),
        const SizedBox(width: AetherSpace.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email ?? 'Jugador', style: AetherType.title, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  since == null ? 'Lector' : 'Lector desde $since',
                  style: AetherType.caption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<SessionReadingStat> stats;

  @override
  Widget build(BuildContext context) {
    final live = stats.where((s) => s.status != 'abandoned').toList();
    final tomos = live.length;
    final turnos = live.fold<int>(0, (sum, s) => sum + s.turnCount);
    final terminadas = live.where((s) => s.status == 'completed').length;

    return Row(
      children: [
        Expanded(child: _StatTile(value: '$tomos', label: 'Tomos')),
        const SizedBox(width: AetherSpace.sm),
        Expanded(child: _StatTile(value: '$turnos', label: 'Turnos')),
        const SizedBox(width: AetherSpace.sm),
        Expanded(child: _StatTile(value: '$terminadas', label: 'Terminada${terminadas == 1 ? '' : 's'}')),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AetherSpace.md, horizontal: AetherSpace.sm),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Column(
        children: [
          Text(value, style: AetherType.display.copyWith(fontSize: 22)),
          const SizedBox(height: 3),
          Text(label.toUpperCase(),
              style: AetherType.overline.copyWith(fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _WorldBreakdown extends StatelessWidget {
  const _WorldBreakdown({required this.stats, required this.worlds});

  final List<SessionReadingStat> stats;
  final Map<String, World> worlds;

  @override
  Widget build(BuildContext context) {
    final turnsByWorld = <String, int>{};
    for (final s in stats) {
      if (s.status == 'abandoned') continue;
      turnsByWorld.update(s.worldSlug, (v) => v + s.turnCount, ifAbsent: () => s.turnCount);
    }
    final entries = turnsByWorld.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Text('Todavía no empezaste ninguna historia.', style: AetherType.caption);
    }
    final maxTurns = entries.first.value.clamp(1, 1 << 30);

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: _WorldBar(
              name: worlds[entry.key]?.name ?? entry.key,
              color: worlds[entry.key] != null
                  ? WorldTheme.forWorld(worlds[entry.key]!).accent
                  : AetherColors.gold,
              turns: entry.value,
              fraction: entry.value / maxTurns,
            ),
          ),
      ],
    );
  }
}

class _WorldBar extends StatelessWidget {
  const _WorldBar({
    required this.name,
    required this.color,
    required this.turns,
    required this.fraction,
  });

  final String name;
  final Color color;
  final int turns;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AetherSpace.sm),
        SizedBox(
          width: 108,
          child: Text(name,
              style: AetherType.label.copyWith(fontSize: 12, color: AetherColors.goldSoft),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: AetherRadius.allSm,
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AetherSpace.sm),
        SizedBox(
          width: 34,
          child: Text('$turns t',
              textAlign: TextAlign.right,
              style: AetherType.caption.copyWith(fontSize: 10.5)),
        ),
      ],
    );
  }
}

class _VowHistory extends StatelessWidget {
  const _VowHistory({required this.stats, required this.worlds});

  final List<SessionReadingStat> stats;
  final Map<String, World> worlds;

  @override
  Widget build(BuildContext context) {
    final entries = stats.where((s) => s.vowStatus != null && s.vowId != null).toList();
    if (entries.isEmpty) {
      return Text('Todavía ningún juramento fue puesto a prueba.', style: AetherType.caption);
    }
    return Column(
      children: [
        for (final s in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: _VowCard(
              vowText: worlds[s.worldSlug]?.vowByIdOrNull(s.vowId)?.text ?? s.vowId!,
              status: s.vowStatus!,
              testedCount: s.vowTestedCount,
              title: s.title ?? worlds[s.worldSlug]?.name ?? s.worldSlug,
              completed: s.status == 'completed',
            ),
          ),
      ],
    );
  }
}

class _VowCard extends StatelessWidget {
  const _VowCard({
    required this.vowText,
    required this.status,
    required this.testedCount,
    required this.title,
    required this.completed,
  });

  final String vowText;
  final String status;
  final int testedCount;
  final String title;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      'roto' => (AetherColors.failure, Icons.warning_rounded, 'Roto'),
      'sostenido' => (AetherColors.success, Icons.check_circle_rounded, 'Sostenido hasta el final'),
      _ => (
          AetherColors.failure,
          Icons.warning_rounded,
          'Puesto a prueba ${testedCount == 1 ? "una vez" : "$testedCount veces"}',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('«$vowText»',
              style: AetherType.body.copyWith(
                  fontStyle: FontStyle.italic, color: AetherColors.parchment, fontSize: 13)),
          const SizedBox(height: AetherSpace.sm),
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: AetherSpace.xs),
              Expanded(
                child: Text('$label · $title',
                    style: AetherType.label.copyWith(fontSize: 10.5, color: color),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.md),
      child: Text(label, style: AetherType.overline),
    );
  }
}
