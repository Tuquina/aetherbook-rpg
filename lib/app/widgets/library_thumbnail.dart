import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A small square scene-image thumbnail for a story-library row
/// (`MyStoriesScreen`'s `_LibraryCard`, `WorldSelectScreen`'s
/// `_LibraryListTile`) — the latest turn's generated image
/// (`SessionLibraryEntry.imageUrl`) when there is one; otherwise a soft
/// gradient wash in the world's own accent (your call: no placeholder icon
/// — same "just the color" language the rest of the library already uses
/// for an unstarted world).
class LibraryThumbnail extends StatelessWidget {
  const LibraryThumbnail({
    super.key,
    required this.imageUrl,
    required this.accent,
    this.size = 44,
    this.borderRadius = AetherRadius.allSm,
  });

  final String? imageUrl;
  final Color accent;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Fallback(accent: accent),
              )
            : _Fallback(accent: accent),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.4), accent.withValues(alpha: 0.1)],
        ),
      ),
    );
  }
}
