import 'free_action_classification.dart';
import 'infer_action_attribute.dart';

/// Deterministically classifies a free-typed action into the vector the
/// campaign-bible narrator contract needs (§18.7): intent, attribute, a
/// known target if any, risk, and canon compatibility. Same spirit as
/// `InferActionAttribute` (Fase 1): keyword-vote per world, in code — the AI
/// never decides this, whether or not it also happens to narrate the result.
///
/// One of the five fields is only partially solved here, deliberately:
/// [CanonCompatibility.needsReframing] isn't inferred — telling "this needs
/// reframing" apart from "this is invalid" requires narrative judgement this
/// deterministic classifier doesn't have. Only the two mechanical cases are
/// covered: a self-granting attempt is `invalid`, everything else is `valid`.
///
/// `targetId` resolves via [knownNpcAliases] (campaign content, Fase 7's
/// `World.npcs`) the same keyword-vote way as everything else — `null` when
/// nothing matches, same as an undeclared world.
class ClassifyFreeAction {
  const ClassifyFreeAction({
    this.inferAttribute = const InferActionAttribute(),
  });

  final InferActionAttribute inferAttribute;

  FreeActionClassification call({
    required String action,
    required Map<String, List<String>> attributeKeywords,
    required String fallbackAttribute,
    Map<String, List<String>> intentKeywords = const {},
    Map<String, List<String>> riskKeywords = const {},
    List<String> selfGrantPatterns = const [],
    Map<String, List<String>> knownNpcAliases = const {},
  }) {
    final normalized = action.toLowerCase();

    final attributeKey = inferAttribute(
      action: action,
      attributeKeywords: attributeKeywords,
      fallback: fallbackAttribute,
    );

    final isSelfGrant = selfGrantPatterns
        .any((pattern) => normalized.contains(pattern.toLowerCase()));

    return FreeActionClassification(
      intent: _classifyIntent(normalized, intentKeywords),
      attributeKey: attributeKey,
      targetId: _classifyTarget(normalized, knownNpcAliases),
      risk: _classifyRisk(normalized, riskKeywords),
      canonCompatibility:
          isSelfGrant ? CanonCompatibility.invalid : CanonCompatibility.valid,
    );
  }

  ActionIntent _classifyIntent(
    String normalized,
    Map<String, List<String>> intentKeywords,
  ) {
    ActionIntent? best;
    var bestScore = 0;
    for (final entry in intentKeywords.entries) {
      final intent = ActionIntent.fromWire(entry.key);
      if (intent == null) continue;
      final score = entry.value
          .where((keyword) => normalized.contains(keyword.toLowerCase()))
          .length;
      if (score > bestScore) {
        bestScore = score;
        best = intent;
      }
    }
    return best ?? ActionIntent.investigate;
  }

  String? _classifyTarget(
    String normalized,
    Map<String, List<String>> knownNpcAliases,
  ) {
    String? best;
    var bestScore = 0;
    for (final entry in knownNpcAliases.entries) {
      final score = entry.value
          .where((alias) => normalized.contains(alias.toLowerCase()))
          .length;
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }

  RiskLevel _classifyRisk(
    String normalized,
    Map<String, List<String>> riskKeywords,
  ) {
    RiskLevel? best;
    var bestScore = 0;
    for (final entry in riskKeywords.entries) {
      final score = entry.value
          .where((keyword) => normalized.contains(keyword.toLowerCase()))
          .length;
      if (score > bestScore) {
        bestScore = score;
        best = RiskLevel.fromWire(entry.key);
      }
    }
    return best ?? RiskLevel.standard;
  }
}
