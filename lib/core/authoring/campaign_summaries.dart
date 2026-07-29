import '../engine/state_delta.dart';
import '../narrative/gate.dart';

/// Human-readable (Spanish, tuteo — `NARRATIVE_VOICE.md`) summaries of
/// domain objects the campaign editor's forms need to describe back to the
/// author (V2 design prototype §9b/§9c/§9g/§9h: "Sólo aparece si…", the
/// effect chips under each outcome band). Pure string functions — no
/// author-facing catalog of pretty names exists for a flag/meter/list key
/// (unlike a curated campaign's own copy_key text), so these are templated
/// from the raw key, not hand-authored prose.
abstract final class CampaignSummaries {
  static String gate(Gate gate) => switch (gate) {
        AlwaysGate() => 'Siempre',
        FlagGate(:final key, :final expected) =>
          expected ? 'Tiene la bandera "$key"' : 'No tiene la bandera "$key"',
        MinLevelGate(:final minLevel) => 'Nivel $minLevel o más',
        MinAttributeGate(:final key, :final minValue) => '$key es $minValue o más',
        MinResourceGate(:final key, :final minValue) => '$key es $minValue o más',
        MinMeterGate(:final key, :final minValue) => '$key es $minValue o más',
        MaxMeterGate(:final key, :final maxValue) => '$key es $maxValue o menos',
        MinRelationshipGate(:final key, :final minValue) => '$key te aprecia $minValue o más',
        MaxRelationshipGate(:final key, :final maxValue) => '$key te aprecia $maxValue o menos',
        VarGate(:final key, :final equals) => '$key es "$equals"',
        ListContainsGate(:final key, :final value, :final expected) =>
          expected ? '$key incluye "$value"' : '$key no incluye "$value"',
        AllOfGate() => 'Condición combinada',
        AnyOfGate() => 'Condición combinada (cualquiera)',
        _ => 'Condición avanzada',
      };

  static String stateDelta(StateDelta delta) {
    final sign = _sign(delta.value);
    return switch (delta.type) {
      StateDeltaType.flag => 'Marca "${delta.key}"',
      StateDeltaType.exp => '$sign${delta.value} de experiencia',
      StateDeltaType.resource => '$sign${delta.value} de ${delta.key}',
      StateDeltaType.meter => '$sign${delta.value} de ${delta.key}',
      StateDeltaType.relationship => '${delta.key} te aprecia $sign${delta.value}',
      StateDeltaType.listAdd => 'Añade "${delta.value}" a ${delta.key}',
      StateDeltaType.listRemove => 'Quita "${delta.value}" de ${delta.key}',
      StateDeltaType.varSet => '${delta.key} = "${delta.value}"',
      StateDeltaType.vowStatus => 'Juramento: ${delta.value}',
      StateDeltaType.unknown => 'Efecto desconocido',
    };
  }

  static String _sign(Object? value) {
    if (value is num && value > 0) return '+';
    return '';
  }
}

/// The 5 named difficulties every check picks from (campaign-bible §6.3),
/// shown as buttons in the editor (§9b: "Fácil 9 / Normal 12 / Difícil 15 /
/// Muy difícil 18 / Casi imposible 21") instead of a raw number field.
enum DifficultyPreset {
  facil(9),
  normal(12),
  dificil(15),
  muyDificil(18),
  casiImposible(21);

  const DifficultyPreset(this.value);

  final int value;

  String get label => switch (this) {
        DifficultyPreset.facil => 'Fácil',
        DifficultyPreset.normal => 'Normal',
        DifficultyPreset.dificil => 'Difícil',
        DifficultyPreset.muyDificil => 'Muy difícil',
        DifficultyPreset.casiImposible => 'Casi imposible',
      };

  /// The preset matching [value] exactly, or `null` for a non-standard
  /// difficulty (content authored outside the editor, e.g. hand-written
  /// JSON) — callers fall back to showing the raw number in that case.
  static DifficultyPreset? forValue(int value) {
    for (final preset in DifficultyPreset.values) {
      if (preset.value == value) return preset;
    }
    return null;
  }
}
