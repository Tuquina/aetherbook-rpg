import '../../ports/image_generator_port.dart';

/// A fixed-response image generator — no network, no quota (CLAUDE.md §9).
/// Lets the whole loop, including the image-fetch side path, be played and
/// tested offline. [url] can be set to `null` to simulate "no image this
/// turn" (a provider hiccup) without needing a real failure.
class FakeImageGeneratorAdapter implements ImageGeneratorPort {
  const FakeImageGeneratorAdapter({
    this.url = 'https://example.com/fake-scene.jpg',
    this.latency = Duration.zero,
  });

  final String? url;
  final Duration latency;

  @override
  Future<String?> generateImage(String prompt) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    return url;
  }
}
