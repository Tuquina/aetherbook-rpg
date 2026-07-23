import 'package:aetherbook/core/engine/vow_reward.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vowReward = VowReward();

  group('VowReward.decide', () {
    test('restores qi when it is below the known maximum', () {
      final offer = vowReward.decide(
        currentQi: 3,
        maxQi: 10,
        expAlreadyGrantedThisAction: false,
      );
      expect(offer.kind, VowRewardKind.restoreQi);
      expect(offer.amount, 2);
    });

    test('restores qi when no maximum is known (safe default)', () {
      final offer = vowReward.decide(
        currentQi: 999,
        maxQi: null,
        expAlreadyGrantedThisAction: false,
      );
      expect(offer.kind, VowRewardKind.restoreQi);
    });

    test('grants exp when qi is already full and exp was not yet granted', () {
      final offer = vowReward.decide(
        currentQi: 10,
        maxQi: 10,
        expAlreadyGrantedThisAction: false,
      );
      expect(offer.kind, VowRewardKind.grantExp);
      expect(offer.amount, 1);
    });

    test('offers advantage when qi is full and exp was already granted', () {
      final offer = vowReward.decide(
        currentQi: 10,
        maxQi: 10,
        expAlreadyGrantedThisAction: true,
      );
      expect(offer.kind, VowRewardKind.grantAdvantage);
    });

    test('amounts are configurable', () {
      const custom = VowReward(qiRestoreAmount: 5, expGrantAmount: 3);
      final offer = custom.decide(
        currentQi: 0,
        maxQi: 10,
        expAlreadyGrantedThisAction: false,
      );
      expect(offer.amount, 5);
    });
  });
}
