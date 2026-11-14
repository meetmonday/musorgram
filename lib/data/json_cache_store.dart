import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

typedef CacheRootProvider = Future<Directory> Function();

abstract interface class JsonCacheStore {
  Future<JsonMap?> read(String key);

  Future<void> write(String key, JsonMap value);
}

class FileJsonCacheStore implements JsonCacheStore {
  FileJsonCacheStore({
    required String namespace,
    CacheRootProvider? rootProvider,
    this.maxAge = const Duration(days: 30),
  }) : _namespace = _digest(namespace),
       _rootProvider = rootProvider ?? getApplicationCacheDirectory;

  static const int _formatVersion = 1;
  static const String _directoryName = 'musorgram_json_cache';

  final String _namespace;
  final CacheRootProvider _rootProvider;
  final Duration maxAge;

  @override
  Future<JsonMap?> read(String key) async {
    final File file = await _fileFor(key);
    if (!await file.exists()) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        await _delete(file);
        return null;
      }
      final JsonMap envelope = Map<String, dynamic>.from(decoded);
      final DateTime? savedAt = DateTime.tryParse(
        envelope['savedAt']?.toString() ?? '',
      );
      final Object? value = envelope['value'];
      if (envelope['version'] != _formatVersion ||
          savedAt == null ||
          DateTime.now().toUtc().difference(savedAt.toUtc()) > maxAge ||
          value is! Map) {
        await _delete(file);
        return null;
      }
      return Map<String, dynamic>.from(value);
    } on Object {
      await _delete(file);
      return null;
    }
  }

  @override
  Future<void> write(String key, JsonMap value) async {
    final File file = await _fileFor(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object>{
        'version': _formatVersion,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      }),
      flush: true,
    );
  }

  static Future<void> clearAll({CacheRootProvider? rootProvider}) async {
    try {
      final Directory root =
          await (rootProvider ?? getApplicationCacheDirectory)();
      final Directory cache = Directory('${root.path}/$_directoryName');
      if (await cache.exists()) {
        await cache.delete(recursive: true);
      }
    } on Object {
      // Cache cleanup must never prevent signing out.
    }
  }

  Future<File> _fileFor(String key) async {
    final Directory root = await _rootProvider();
    return File(
      '${root.path}/$_directoryName/$_namespace/${_digest(key)}.json',
    );
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // A corrupt cache can be ignored even if the OS refuses its deletion.
    }
  }

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
