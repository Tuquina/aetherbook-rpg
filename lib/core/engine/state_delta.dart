/// The kinds of state change the narrator may propose. Anything the parser
/// does not recognise maps to [unknown] and is rejected by the engine.
enum StateDeltaType { flag, exp, resource, unknown }

/// A single proposed change to game state, as suggested by the narrator
/// (CLAUDE.md §5). These are **proposals**: the engine validates them before
/// applying (Golden rule §2.3). The AI never mutates authoritative state.
class StateDelta {
  const StateDelta({
    required this.type,
    required this.key,
    required this.value,
  });

  final StateDeltaType type;
  final String key;
  final Object? value;

  static StateDeltaType typeFromString(String raw) {
    switch (raw) {
      case 'flag':
        return StateDeltaType.flag;
      case 'exp':
        return StateDeltaType.exp;
      case 'resource':
        return StateDeltaType.resource;
      default:
        return StateDeltaType.unknown;
    }
  }

  @override
  String toString() => 'StateDelta($type, $key, $value)';
}
