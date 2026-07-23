/// Computes a resource's value from a character's attributes, e.g. a
/// campaign bible's `"vitality: 8 + (cuerpo * 2)"`. Deliberately a small
/// structured formula — base + a linear coefficient per attribute — rather
/// than a string-expression parser: every formula in the campaign-bible
/// format (CLAUDE.md's reusable-format convention) is linear, and a tiny
/// declarative shape is safer and easier to validate than parsing arbitrary
/// math text.
class ResourceFormula {
  const ResourceFormula({this.base = 0, this.perAttribute = const {}});

  final int base;

  /// Attribute key -> coefficient, e.g. `{'cuerpo': 2}` for `cuerpo * 2`.
  final Map<String, int> perAttribute;

  int evaluate(Map<String, int> attributes) {
    var total = base;
    for (final entry in perAttribute.entries) {
      total += (attributes[entry.key] ?? 0) * entry.value;
    }
    return total;
  }

  /// Accepts either a flat number (a world with no formula, just a starting
  /// value) or a structured `{"base": 8, "per_attribute": {"cuerpo": 2}}`.
  factory ResourceFormula.fromJson(Object? json) {
    if (json is num) {
      return ResourceFormula(base: json.toInt());
    }
    if (json is Map) {
      final map = json.cast<String, dynamic>();
      return ResourceFormula(
        base: (map['base'] as num?)?.toInt() ?? 0,
        perAttribute: _perAttributeFromJson(map['per_attribute']),
      );
    }
    return const ResourceFormula();
  }

  static Map<String, int> _perAttributeFromJson(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(key as String, (v as num).toInt()),
      );
    }
    return const {};
  }
}
