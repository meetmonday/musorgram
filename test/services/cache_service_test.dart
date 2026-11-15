import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/services/cache_service.dart';

void main() {
  test('separates protected media cache entries by account', () {
    const String url = 'https://example.test/api/messages/media/31?size=thumb';
    const String token = 'very-secret-token';

    final String first = authenticatedMediaCacheKey(url, token);
    final String sameAccount = authenticatedMediaCacheKey(url, token);
    final String otherAccount = authenticatedMediaCacheKey(url, 'other-token');

    expect(first, sameAccount);
    expect(first, isNot(otherAccount));
    expect(first, isNot(contains(token)));
  });
}
