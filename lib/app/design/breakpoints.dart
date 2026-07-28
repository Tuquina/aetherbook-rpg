/// Width thresholds for the home dashboard's 3 chrome modes (V2 design
/// prototype §8a/§8b/§2a): phone gets no persistent nav chrome at all
/// (`< tablet`), tablet gets a bottom nav bar (`>= tablet, < desktop`), and
/// desktop gets a persistent sidebar (`>= desktop`). Not reused by
/// `game_screen.dart`'s `_ReadingFrame` — that's a different concern (an
/// in-story content-frame width), not a nav-chrome mode switch.
abstract final class AetherBreakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
}
