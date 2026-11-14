import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/data/json_cache_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'musorgram_cache_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists JSON responses between store instances', () async {
    final FileJsonCacheStore first = FileJsonCacheStore(
      namespace: 'https://example.test\u0000token-a',
      rootProvider: () async => temporaryDirectory,
    );
    await first.write('GET /api/me', <String, dynamic>{
      'ok': true,
      'user': <String, dynamic>{'id': 7, 'username': 'Reader'},
    });

    final FileJsonCacheStore second = FileJsonCacheStore(
      namespace: 'https://example.test\u0000token-a',
      rootProvider: () async => temporaryDirectory,
    );
    final Map<String, dynamic>? restored = await second.read('GET /api/me');

    expect(restored?['ok'], isTrue);
    expect((restored?['user'] as Map<String, dynamic>)['username'], 'Reader');
  });

  test('isolates cached data by account namespace', () async {
    final FileJsonCacheStore firstAccount = FileJsonCacheStore(
      namespace: 'https://example.test\u0000token-a',
      rootProvider: () async => temporaryDirectory,
    );
    final FileJsonCacheStore secondAccount = FileJsonCacheStore(
      namespace: 'https://example.test\u0000token-b',
      rootProvider: () async => temporaryDirectory,
    );
    await firstAccount.write('GET /api/me', <String, dynamic>{'ok': true});

    expect(await secondAccount.read('GET /api/me'), isNull);
  });

  test('clearAll removes every account cache', () async {
    final FileJsonCacheStore store = FileJsonCacheStore(
      namespace: 'account',
      rootProvider: () async => temporaryDirectory,
    );
    await store.write('GET /api/me', <String, dynamic>{'ok': true});

    await FileJsonCacheStore.clearAll(
      rootProvider: () async => temporaryDirectory,
    );

    expect(await store.read('GET /api/me'), isNull);
  });
}
