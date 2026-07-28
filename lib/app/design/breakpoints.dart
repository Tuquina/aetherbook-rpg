/// Width thresholds for the home dashboard's 3 chrome modes (V2 design
/// prototype §8a/§8b/§2a): phone gets no persistent nav chrome at all
/// (`< tablet`), tablet gets a bottom nav bar (`>= tablet, < desktop`), and
/// desktop gets a persistent sidebar (`>= desktop`). `game_screen.dart` also
/// reuses `tablet` as its own mobile/split-view switch (V2 §1c) — the same
/// "phone vs. not-phone" boundary, just for a different screen's chrome.
abstract final class AetherBreakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
}
