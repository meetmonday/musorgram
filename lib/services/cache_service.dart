import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../data/json_cache_store.dart';

final CacheManager mediaCacheManager = CacheManager(
  Config(
    'musorgram_media',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
  ),
);

Future<void> clearApplicationCaches() async {
  await Future.wait<void>(<Future<void>>[
    _ignoreCacheError(FileJsonCacheStore.clearAll()),
    _ignoreCacheError(mediaCacheManager.emptyCache()),
  ]);
}

Future<void> _ignoreCacheError(Future<void> operation) async {
  try {
    await operation;
  } on Object {
    // Cache maintenance is best-effort and must not block signing out.
  }
}
