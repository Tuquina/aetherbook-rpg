import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HubActivity — unconditional (no check)', () {
    test('requiresCheck is false when checkAttribute is unset', () {
      const activity = HubActivity(id: 'a', label: 'Descansar');
      expect(activity.requiresCheck, isFalse);
    });

    test('outcomeFor falls back to the activity\'s own effects, no target node', () {
      const activity = HubActivity(
        id: 'a',
        label: 'Descansar',
        effects: [StateDelta(type: StateDeltaType.resource, key: 'vitality', value: 20)],
      );
      for (final outcome in ActionOutcome.values) {
        final resolved = activity.outcomeFor(outcome);
        expect(resolved.targetNodeId, isNull);
        expect(resolved.effects, activity.effects);
      }
    });
  });

  group('HubActivity — checked', () {
    const activity = HubActivity(
      id: 'examinar_tablilla',
      label: 'Examinar la tablilla en blanco',
      checkAttribute: 'agudeza',
      checkDifficulty: 12,
      onSuccess: ChoiceOutcome(
        effects: [StateDelta(type: StateDeltaType.flag, key: 'evidence_forged_seal', value: true)],
      ),
    );

    test('requiresCheck is true once checkAttribute is set', () {
      expect(activity.requiresCheck, isTrue);
    });

    test('success resolves to onSuccess', () {
      final resolved = activity.outcomeFor(ActionOutcome.success);
      expect(resolved.effects.single.key, 'evidence_forged_seal');
    });

    test('failure with no onFailure falls back to the base (no) effects', () {
      final resolved = activity.outcomeFor(ActionOutcome.failure);
      expect(resolved.effects, isEmpty);
    });
  });

  group('HubActivity.fromJson — check fields', () {
    test('parses check_attribute, check_difficulty and onSuccess', () {
      final activity = HubActivity.fromJson({
        'id': 'examinar_tablilla',
        'label': 'Examinar la tablilla en blanco',
        'check_attribute': 'agudeza',
        'check_difficulty': 12,
        'on_success': {
          'effects': [
            {'type': 'flag', 'key': 'evidence_forged_seal', 'value': true},
          ],
        },
      });

      expect(activity.checkAttribute, 'agudeza');
      expect(activity.checkDifficulty, 12);
      expect(activity.onSuccess!.effects.single.key, 'evidence_forged_seal');
    });

    test('leaves check fields null when omitted', () {
      final activity = HubActivity.fromJson({'id': 'a', 'label': 'x'});
      expect(activity.checkAttribute, isNull);
      expect(activity.onSuccess, isNull);
    });
  });
}
