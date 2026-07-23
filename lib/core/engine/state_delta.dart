/// The kinds of state change the narrator may propose. Anything the parser
/// does not recognise maps to [unknown] and is rejected by the engine.
enum StateDeltaType {
  flag,
  exp,
  resource,
  meter,
  relationship,

  /// Adds an id to a named string list on the character (e.g.
  /// `lists['inventory']`, `lists['selected_passengers']`) — a curated
  /// campaign's generic replacement for "add_item"/"append_passenger": one
  /// mechanism, addressed by list key, instead of a bespoke delta per list.
  listAdd,

  /// Removes an id from a named string list, no-op if absent.
  listRemove,

  /// Sets a named free-form id/enum-like value on the character (e.g.
  /// `vars['passenger_policy']`) — for state that isn't boolean (flag),
  /// numeric (resource/meter) or a per-NPC score (relationship).
  varSet,

  unknown,
}

/// A single proposed change to game state, as suggested by the narrator
/// (CLAUDE.md §5) or declared directly by curated content. These are
/// **proposals**: the engine validates them before applying (Golden rule
/// §2.3). The AI never mutates authoritative state.
class StateDelta {
  const StateDelta({
    required this.type,
    required this.key,
    required this.value,
    this.operation,
  });

  final StateDeltaType type;
  final String key;
  final Object? value;

  /// How a `resource`/`meter` delta combines with the current value:
  /// `'increment'` (default when `null`) adds [value] to the current value;
  /// `'set'` replaces it outright — needed for curated content that fixes a
  /// counter to an exact number (e.g. `hours_remaining` after a time skip)
  /// rather than nudging it. Ignored by every other [type].
  final String? operation;

  static StateDeltaType typeFromString(String raw) {
    switch (raw) {
      case 'flag':
        return StateDeltaType.flag;
      case 'exp':
        return StateDeltaType.exp;
      case 'resource':
        return StateDeltaType.resource;
      case 'meter':
        return StateDeltaType.meter;
      case 'relationship':
        return StateDeltaType.relationship;
      case 'list_add':
        return StateDeltaType.listAdd;
      case 'list_remove':
        return StateDeltaType.listRemove;
      case 'var_set':
        return StateDeltaType.varSet;
      default:
        return StateDeltaType.unknown;
    }
  }

  @override
  String toString() => 'StateDelta($type, $key, $value, op: $operation)';
}

/// A state delta as it arrives on the narrator's wire (campaign-bible
/// §18.5/§19.3): unlike [StateDelta], it carries `operation`/`reason` for
/// validation and observability before the engine ever applies it.
class ProposedStateDelta {
  const ProposedStateDelta({
    required this.type,
    required this.key,
    required this.value,
    this.operation,
    this.reason,
  });

  final StateDeltaType type;
  final String key;
  final Object? value;

  /// How the narrator says this delta should apply, e.g. `"increment"`. The
  /// engine only supports increments today — no campaign-bible example needs
  /// anything else — so [toStateDelta] rejects any other declared operation
  /// rather than silently reinterpreting it.
  final String? operation;

  /// Why the narrator proposed this change, kept for observability/audit
  /// (campaign-bible §19.3 "registrar rechazos"). Never affects validation.
  final String? reason;

  /// The delta as `ApplyStateDeltas` applies it, or `null` if [operation] is
  /// declared as something the engine doesn't support.
  StateDelta? toStateDelta() {
    if (operation != null && operation != 'increment') return null;
    return StateDelta(type: type, key: key, value: value);
  }
}
