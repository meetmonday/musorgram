import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../data/json_cache_store.dart';

final CacheManager mediaCacheManager = CacheManager(
  Config(
    'musorgram_media',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
  ),
);

String authenticatedMediaCacheKey(String url, String token) {
  return sha256.convert(utf8.encode('$url\u0000$token')).toString();
}

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
