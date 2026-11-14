import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String defaultBaseUrl = 'https://nasralbox.randomshit.icu';

class AppSettings {
  const AppSettings({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  bool get isConfigured => token.trim().isNotEmpty;

  AppSettings normalized() {
    return AppSettings(
      baseUrl: baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      token: token.trim(),
    );
  }
}

class SettingsStore {
  SettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'musorbox_api_token';
  static const String _baseUrlKey = 'musorbox_base_url';

  final FlutterSecureStorage _storage;

  Future<AppSettings> load() async {
    String? storedToken;
    String? storedBaseUrl;
    try {
      storedToken = await _storage.read(key: _tokenKey);
      storedBaseUrl = await _storage.read(key: _baseUrlKey);
    } on Object {
      // A Linux keyring may be unavailable in a minimal desktop session. The
      // environment and compile-time values still make the client usable.
    }

    const String compiledToken = String.fromEnvironment('MB_TOKEN');
    const String compiledBaseUrl = String.fromEnvironment('MB_BASE_URL');
    final String environmentToken = Platform.environment['MB_TOKEN'] ?? '';
    final String environmentBaseUrl = Platform.environment['MB_BASE_URL'] ?? '';

    return AppSettings(
      token: _firstNonEmpty(<String?>[
        storedToken,
        compiledToken,
        environmentToken,
      ]),
      baseUrl: _firstNonEmpty(<String?>[
        storedBaseUrl,
        compiledBaseUrl,
        environmentBaseUrl,
        defaultBaseUrl,
      ]),
    ).normalized();
  }

  Future<void> save(AppSettings settings) async {
    final AppSettings value = settings.normalized();
    await _storage.write(key: _tokenKey, value: value.token);
    await _storage.write(key: _baseUrlKey, value: value.baseUrl);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _baseUrlKey);
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    final String result = value?.trim() ?? '';
    if (result.isNotEmpty) {
      return result;
    }
  }
  return '';
}
