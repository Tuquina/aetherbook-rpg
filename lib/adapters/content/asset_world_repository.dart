import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/world/world.dart';
import '../../ports/world_repository_port.dart';

/// Loads world packages from the app's bundled assets (CLAUDE.md §8). This is
/// the infra edge, so depending on Flutter (`rootBundle`) is fine here — the
/// domain in `core/` stays pure.
class AssetWorldRepository implements WorldRepositoryPort {
  const AssetWorldRepository({this.basePath = 'assets/worlds'});

  final String basePath;

  @override
  Future<World> loadWorld(String slug) async {
    final raw = await rootBundle.loadString('$basePath/$slug.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return World.fromJson(json);
  }
}
