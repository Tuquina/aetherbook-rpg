import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/engine/resolve_player_action.dart';
import 'package:aetherbook/core/engine/resolve_story_choice.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

Character _character({Map<String, int> attributes = const {}}) => Character(
      name: 'Discípulo',
      level: 1,
      exp: 0,
      attributes: attributes,
      resources: const {},
    );

void main() {
  group('ResolveStoryChoice — unconditional choices', () {
    test('never rolls and resolves as the base outcome', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(1)));
      const choice = StoryChoice(
        label: 'x',
        targetNodeId: 'next',
        effects: [StateDelta(type: StateDeltaType.flag, key: 'k', value: true)],
      );

      final result = resolve(choice: choice, character: _character());

      expect(result.actionResolution, isNull);
      expect(result.outcome.targetNodeId, 'next');
      expect(result.outcome.effects.single.key, 'k');
      expect(result.advances, isTrue);
      expect(result.updatedConflictProgress, isNull);
    });
  });

  group('ResolveStoryChoice — checked choices', () {
    const choice = StoryChoice(
      label: 'Empujar la tapa',
      targetNodeId: 'default_next',
      checkAttribute: 'cuerpo',
      checkDifficulty: 12,
      onSuccess: ChoiceOutcome(
        effects: [StateDelta(type: StateDeltaType.exp, key: 'exp', value: 1)],
      ),
      onFailure: ChoiceOutcome(
        targetNodeId: 'volcada',
        effects: [StateDelta(type: StateDeltaType.resource, key: 'vitality', value: -2)],
      ),
    );

    test('rolls against the choice\'s own attribute and difficulty, not a world default', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(15)));
      final result = resolve(
        choice: choice,
        character: _character(attributes: {'cuerpo': 2}),
      );

      expect(result.actionResolution!.attributeKey, 'cuerpo');
      expect(result.actionResolution!.attribute, 2);
      expect(result.actionResolution!.difficulty, 12);
      expect(result.actionResolution!.isSuccess, isTrue);
      expect(result.outcome.effects.single.type, StateDeltaType.exp);
      expect(result.advances, isTrue);
    });

    test('a failed roll resolves to onFailure, including its target override', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(1)));
      final result = resolve(
        choice: choice,
        character: _character(attributes: {'cuerpo': 0}),
      );

      expect(result.actionResolution!.isSuccess, isFalse);
      expect(result.outcome.targetNodeId, 'volcada');
      expect(result.outcome.effects.single.key, 'vitality');
    });
  });

  group('ResolveStoryChoice — extended conflict', () {
    const conflict = ExtendedConflict(successesRequired: 2, failuresAllowed: 2);
    const choiceA = StoryChoice(
      label: 'Contener',
      targetNodeId: 'next',
      checkAttribute: 'cuerpo',
      checkDifficulty: 12,
    );
    const choiceB = StoryChoice(
      label: 'Escuchar',
      targetNodeId: 'next',
      checkAttribute: 'espiritu',
      checkDifficulty: 12,
    );

    test('does not advance while the conflict is still undecided', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(15)));
      final result = resolve(
        choice: choiceA,
        character: _character(attributes: {'cuerpo': 2}),
        extendedConflict: conflict,
      );

      expect(result.advances, isFalse);
      expect(result.updatedConflictProgress!.successes, 1);
      expect(result.updatedConflictProgress!.failures, 0);
    });

    test('advances once the conflict is decided (successesRequired reached)', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(15)));
      final afterFirst = resolve(
        choice: choiceA,
        character: _character(attributes: {'cuerpo': 2}),
        extendedConflict: conflict,
      );
      final afterSecond = resolve(
        choice: choiceB,
        character: _character(attributes: {'espiritu': 2}),
        extendedConflict: conflict,
        conflictProgress: afterFirst.updatedConflictProgress!,
      );

      expect(afterSecond.advances, isTrue);
      expect(afterSecond.updatedConflictProgress!.successes, 2);
    });

    test('advances on failedForward once failuresAllowed is reached', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(1)));
      final afterFirst = resolve(
        choice: choiceA,
        character: _character(attributes: {'cuerpo': 0}),
        extendedConflict: conflict,
      );
      final afterSecond = resolve(
        choice: choiceB,
        character: _character(attributes: {'espiritu': 0}),
        extendedConflict: conflict,
        conflictProgress: afterFirst.updatedConflictProgress!,
      );

      expect(afterSecond.advances, isTrue);
      expect(afterSecond.updatedConflictProgress!.failures, 2);
    });

    test('applies the repeat-attribute penalty on the next attempt', () {
      const resolve = ResolveStoryChoice(ResolvePlayerAction(FixedDice(11)));
      // cuerpo 2 + roll 11 = 13, would succeed at DC12 without penalty.
      final afterFirst = resolve(
        choice: choiceA,
        character: _character(attributes: {'cuerpo': 2}),
        extendedConflict: conflict,
      );
      final repeated = resolve(
        choice: choiceA,
        character: _character(attributes: {'cuerpo': 2}),
        extendedConflict: conflict,
        conflictProgress: afterFirst.updatedConflictProgress!,
      );

      // Repeating "cuerpo" applies the -2 penalty: 2 + 11 - 2 = 11 < DC12.
      expect(repeated.actionResolution!.isSuccess, isFalse);
    });
  });
}
