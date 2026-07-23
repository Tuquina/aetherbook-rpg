import '../state/character.dart';
import '../world/meter_definition.dart';
import 'exp_progression.dart';
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
  }) : _progression = progression ?? const ExpProgression();

  final ExpProgression _progression;

  /// World/campaign-declared bounds (and derived-meter markers) for the
  /// `meter` delta type. Rebuilt per world, same as [_progression].
  final Map<String, MeterDefinition> meterDefinitions;

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
