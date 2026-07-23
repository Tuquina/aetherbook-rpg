/// A chargen vow / juramento (campaign-bible §5.4): a stance the player
/// chooses for their character. Acting on it at a real cost can trigger a
/// [VowReward] (see `core/engine/vow_reward.dart`). Declarative and
/// per-world/campaign.
class Vow {
  const Vow({required this.id, required this.text});

  final String id;
  final String text;

  factory Vow.fromJson(Map<String, dynamic> json) {
    return Vow(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}
