import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoryChoice — unconditional (no check)', () {
    test('requiresCheck is false when checkAttribute is unset', () {
      const choice = StoryChoice(label: 'x', targetNodeId: 'n2');
      expect(choice.requiresCheck, isFalse);
    });

    test('outcomeFor falls back to the choice\'s own target/effects for any band', () {
      const choice = StoryChoice(
        label: 'x',
        targetNodeId: 'n2',
        effects: [StateDelta(type: StateDeltaType.flag, key: 'k', value: true)],
      );
      for (final outcome in ActionOutcome.values) {
        final resolved = choice.outcomeFor(outcome);
        expect(resolved.targetNodeId, 'n2');
        expect(resolved.effects, choice.effects);
      }
    });
  });

  group('StoryChoice — checked, with distinct outcomes', () {
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

    test('requiresCheck is true once checkAttribute is set', () {
      expect(choice.requiresCheck, isTrue);
    });

    test('success resolves to onSuccess, keeping the choice\'s own target', () {
      final resolved = choice.outcomeFor(ActionOutcome.success);
      expect(resolved.targetNodeId, isNull);
      expect(resolved.effects.single.type, StateDeltaType.exp);
    });

    test('failure resolves to onFailure, overriding the target node', () {
      final resolved = choice.outcomeFor(ActionOutcome.failure);
      expect(resolved.targetNodeId, 'volcada');
      expect(resolved.effects.single.key, 'vitality');
    });

    test('criticalSuccess falls back to onSuccess when onCriticalSuccess is unset', () {
      final resolved = choice.outcomeFor(ActionOutcome.criticalSuccess);
      expect(resolved.effects.single.type, StateDeltaType.exp);
    });

    test('an explicit onCriticalSuccess overrides the onSuccess fallback', () {
      const withCritical = StoryChoice(
        label: 'x',
        targetNodeId: 'n',
        checkAttribute: 'espiritu',
        checkDifficulty: 15,
        onSuccess: ChoiceOutcome(effects: []),
        onCriticalSuccess: ChoiceOutcome(
          effects: [StateDelta(type: StateDeltaType.meter, key: 'karma', value: 1)],
        ),
      );
      final resolved = withCritical.outcomeFor(ActionOutcome.criticalSuccess);
      expect(resolved.effects.single.key, 'karma');
    });
  });

  group('StoryChoice.fromJson — check fields', () {
    test('parses check_attribute, check_difficulty and outcome branches', () {
      final choice = StoryChoice.fromJson({
        'label': 'Empujar la tapa',
        'target': 'default_next',
        'check_attribute': 'cuerpo',
        'check_difficulty': 12,
        'on_success': {
          'effects': [
            {'type': 'exp', 'key': 'exp', 'value': 1},
          ],
        },
        'on_failure': {
          'target': 'volcada',
          'effects': [
            {'type': 'resource', 'key': 'vitality', 'value': -2},
          ],
        },
      });

      expect(choice.checkAttribute, 'cuerpo');
      expect(choice.checkDifficulty, 12);
      expect(choice.onSuccess!.effects.single.type, StateDeltaType.exp);
      expect(choice.onFailure!.targetNodeId, 'volcada');
    });

    test('leaves check fields null when omitted (unconditional choice)', () {
      final choice = StoryChoice.fromJson({'label': 'x', 'target': 'y'});
      expect(choice.checkAttribute, isNull);
      expect(choice.checkDifficulty, isNull);
      expect(choice.onSuccess, isNull);
      expect(choice.onCriticalSuccess, isNull);
      expect(choice.onFailure, isNull);
    });
  });

  group('StoryChoice.resultText — unconditional choices (curated content)', () {
    test('an unconditional choice\'s own resultText flows through outcomeFor', () {
      const choice = StoryChoice(
        label: 'Continuar',
        targetNodeId: 'p1_alarm_close',
        resultText: 'Saúl marca la pérdida en la libreta sin decir una palabra.',
      );
      for (final outcome in ActionOutcome.values) {
        expect(
          choice.outcomeFor(outcome).resultText,
          'Saúl marca la pérdida en la libreta sin decir una palabra.',
        );
      }
    });

    test('fromJson parses the top-level result_text field', () {
      final choice = StoryChoice.fromJson({
        'label': 'Continuar',
        'target': 'y',
        'result_text': 'Texto autorado.',
      });
      expect(choice.resultText, 'Texto autorado.');
      expect(choice.outcomeFor(ActionOutcome.success).resultText, 'Texto autorado.');
    });
  });

  group('ChoiceOutcome — resultText (curated, AI-free content)', () {
    test('fromJson parses result_text as authored literal prose', () {
      final outcome = ChoiceOutcome.fromJson({
        'target': 'p2',
        'result_text': 'Damián empuja la puerta y la cadena cede.',
      });
      expect(outcome.resultText, 'Damián empuja la puerta y la cadena cede.');
    });

    test('resultText defaults to null for hybrid/freeform content', () {
      final outcome = ChoiceOutcome.fromJson({'target': 'p2'});
      expect(outcome.resultText, isNull);
    });

    test('a checked StoryChoice carries a distinct resultText per outcome band', () {
      final choice = StoryChoice.fromJson({
        'label': 'Ayudar a Ramiro en la puerta norte',
        'target': 'p1_alarm_close',
        'check_attribute': 'cuerpo',
        'check_difficulty': 12,
        'on_success': {'result_text': 'La puerta sigue cerrada.'},
        'on_failure': {'result_text': 'Los dientes cierran sobre la manga.'},
      });
      expect(choice.onSuccess!.resultText, 'La puerta sigue cerrada.');
      expect(choice.onFailure!.resultText, 'Los dientes cierran sobre la manga.');
    });
  });

  group('StoryChoice — confirmation (irreversible choices)', () {
    test('defaults to no confirmation required', () {
      const choice = StoryChoice(label: 'x', targetNodeId: 'y');
      expect(choice.requiresConfirmation, isFalse);
      expect(choice.confirmationText, isNull);
    });

    test('fromJson parses requires_confirmation and confirmation_text', () {
      final choice = StoryChoice.fromJson({
        'label': 'Matarlo',
        'target': 'siguiente',
        'requires_confirmation': true,
        'confirmation_text':
            'Yago está herido y no puede perseguirlos. ¿Confirmás?',
      });
      expect(choice.requiresConfirmation, isTrue);
      expect(
        choice.confirmationText,
        'Yago está herido y no puede perseguirlos. ¿Confirmás?',
      );
    });
  });
}
