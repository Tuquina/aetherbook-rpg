import '../state/character.dart';
import '../world/meter_definition.dart';
import 'exp_progression.dart';
import 'rank_progression.dart';
import 'state_delta.dart';

/// Outcome of applying a batch of proposed deltas: the resulting character and
/// which deltas were accepted vs. rejected by validation.
class DeltaApplication {
  const DeltaApplication({
    required this.character,
    required this.applied,
    required this.rejected,
  });

  final Character character;
  final List<StateDelta> applied;
  final List<StateDelta> rejected;
}

/// Validates narrator-proposed [StateDelta]s against simple rules and applies
/// only the valid ones. The AI proposes; the engine disposes (CLAUDE.md §2.3).
/// Invalid or unknown deltas are rejected, never applied blindly.
class ApplyStateDeltas {
  const ApplyStateDeltas({
    ExpProgression? progression,
    this.meterDefinitions = const {},
    this.rankProgression,
  }) : _progression = progression ?? const ExpProgression();

  final ExpProgression _progression;

  /// World/campaign-declared bounds (and derived-meter markers) for the
  /// `meter` delta type. Rebuilt per world, same as [_progression].
  final Map<String, MeterDefinition> meterDefinitions;

  /// When set (campaign-bible worlds, §7.1), EXP accumulates as a running
  /// total and rank promotion is milestone-gated instead of the simpler
  /// linear [_progression]. Rebuilt per world, same as [_progression].
  final RankProgression? rankProgression;

  DeltaApplication call(Character character, List<StateDelta> deltas) {
    var current = character;
    final applied = <StateDelta>[];
    final rejected = <StateDelta>[];

    for (final delta in deltas) {
      final updated = _applyOne(current, delta);
      if (updated == null) {
        rejected.add(delta);
      } else {
        current = updated;
        applied.add(delta);
      }
    }

    // Re-check rank promotion once per turn, after every delta in the batch
    // has landed — not just when an `exp` delta happens to be present. A
    // `flag` delta that completes a milestone must promote a character whose
    // EXP was already banked from earlier turns, even with no EXP gained
    // this turn; likewise an EXP delta shouldn't need to guess whether a
    // flag delta later in the same batch will unlock it.
    final rankProg = rankProgression;
    if (rankProg != null) {
      final result = rankProg.applyExp(
        currentLevel: current.level,
        currentExp: current.exp,
        gainedExp: 0,
        hasFlag: current.flag,
      );
      current = current.copyWith(level: result.level);
    }

    // Keep derived meters (e.g. `evidence_count`) synced onto the character
    // once per turn, from whatever flags just changed. This is engine-owned
    // synchronization, not a delta — `Gate`/`MinMeterGate` can then read a
    // derived meter with a plain `character.meter(key)`, without needing the
    // `World`/`MeterDefinition` that computed it.
    if (meterDefinitions.isNotEmpty) {
      final derived = {
        for (final entry in meterDefinitions.entries)
          if (entry.value.isDerived)
            entry.key: entry.value.resolve(current, entry.key),
      };
      if (derived.isNotEmpty) {
        current = current.copyWith(meters: {...current.meters, ...derived});
      }
    }

    return DeltaApplication(
      character: current,
      applied: applied,
      rejected: rejected,
    );
  }

  /// Returns the updated character, or `null` if the delta is invalid.
  Character? _applyOne(Character c, StateDelta delta) {
    switch (delta.type) {
      case StateDeltaType.flag:
        final value = delta.value;
        if (value is! bool) return null;
        return c.copyWith(flags: {...c.flags, delta.key: value});

      case StateDeltaType.exp:
        final gained = _asInt(delta.value);
        if (gained == null || gained < 0) return null;
        if (rankProgression != null) {
          // Milestone-gated worlds: EXP is a cumulative running total, never
          // rolled over. Promotion itself is (re)computed once per turn in
          // `call` above, using the fully-updated character.
          return c.copyWith(exp: c.exp + gained);
        }
        final progress = _progression.applyExp(
          level: c.level,
          exp: c.exp,
          gainedExp: gained,
        );
        return c.copyWith(level: progress.level, exp: progress.exp);

      case StateDeltaType.resource:
        final change = _asInt(delta.value);
        if (change == null) return null;
        final next = (c.resource(delta.key) + change).clamp(0, 1 << 30);
        return c.copyWith(resources: {...c.resources, delta.key: next});

      case StateDeltaType.meter:
        final change = _asInt(delta.value);
        if (change == null) return null;
        final definition = meterDefinitions[delta.key];
        // A derived meter (e.g. evidence_count) only ever changes because the
        // flags it counts changed — never by a direct delta (campaign-bible
        // rule: "no se edita de forma independiente").
        if (definition != null && definition.isDerived) return null;
        final raw = c.meter(delta.key) + change;
        final next = definition?.clamp(raw) ?? raw;
        return c.copyWith(meters: {...c.meters, delta.key: next});

      case StateDeltaType.relationship:
        final change = _asInt(delta.value);
        // Campaign-bible §19.3: a single proposed relationship delta is
        // capped at ±1 magnitude; the stored value is separately clamped to
        // [-2, 3]. "One per node per NPC" is a per-visit de-dup rule that
        // needs the current node context `ApplyStateDeltas` doesn't have —
        // deferred to Fase 8, once `GameController` tracks that.
        if (change == null || change.abs() > 1) return null;
        final next =
            (c.relationship(delta.key) + change).clamp(-2, 3);
        return c.copyWith(
          relationships: {...c.relationships, delta.key: next},
        );

      case StateDeltaType.unknown:
        return null;
    }
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
