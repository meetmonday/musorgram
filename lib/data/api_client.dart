import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'json_cache_store.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApiClient {
  AuthApiClient({required String baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse('$baseUrl/api/auth/login');
    } on FormatException {
      throw const ApiException('Некорректный адрес сервера');
    }
    late http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'User-Agent': 'Musorgram/1.0 Flutter',
            },
            body: jsonEncode(<String, String>{
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('Сервер не ответил вовремя');
    } on http.ClientException {
      throw const ApiException('Не удалось связаться с MusorBox');
    } on Object {
      throw const ApiException('Не удалось связаться с MusorBox');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException('MusorBox вернул некорректный ответ');
      }
    }
    final JsonMap? data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = data?['error']?.toString().trim() ?? '';
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Ошибка сервера (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final String token = data?['token']?.toString().trim() ?? '';
    if (data?['ok'] != true || token.isEmpty) {
      throw const ApiException('MusorBox не вернул токен приложения');
    }
    return token;
  }

  void close() {
    _httpClient.close();
  }
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    http.Client? httpClient,
    JsonCacheStore? cacheStore,
  }) : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _cacheStore =
           cacheStore ??
           FileJsonCacheStore(namespace: '${baseUrl.trim()}\u0000$token');

  final String baseUrl;
  final String token;
  final http.Client _httpClient;
  final JsonCacheStore _cacheStore;

  Future<JsonMap> request(
    String method,
    String path, {
    JsonMap? payload,
    bool cacheResponse = false,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse('$baseUrl$path');
    } on FormatException {
      throw const ApiException('Некорректный адрес сервера');
    }

    final http.Request request = http.Request(method, uri)
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Musorgram/1.0 Flutter',
      });
    if (payload != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(payload);
    }

    late http.StreamedResponse response;
    String raw = '';
    try {
      response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 20));
      raw = await response.stream.bytesToString().timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      throw const ApiException('Сервер не ответил вовремя');
    } on http.ClientException {
      throw const ApiException('Не удалось связаться с MusorBox');
    } on Object {
      throw const ApiException('Не удалось связаться с MusorBox');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException('MusorBox вернул некорректный ответ');
      }
    }

    final JsonMap? data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = data?['error']?.toString().trim() ?? '';
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Ошибка сервера (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (data == null) {
      throw const ApiException('MusorBox вернул некорректный ответ');
    }
    if (data['ok'] != true) {
      final String message = data['error']?.toString().trim() ?? '';
      throw ApiException(
        message.isNotEmpty ? message : 'Запрос не выполнен',
        statusCode: response.statusCode,
      );
    }
    if (cacheResponse && method == 'GET') {
      try {
        await _cacheStore.write(_cacheKey(method, path), data);
      } on Object {
        // A full or unavailable cache must not turn a valid request into an error.
      }
    }
    return data;
  }

  Future<JsonMap?> readCached(String path) async {
    try {
      return await _cacheStore.read(_cacheKey('GET', path));
    } on Object {
      return null;
    }
  }

  Future<UserSummary> getMe() async {
    final JsonMap data = await request('GET', '/api/me', cacheResponse: true);
    final Object? user = data['user'];
    if (user is! Map) {
      throw const ApiException('В ответе сервера отсутствует профиль');
    }
    return UserSummary.fromJson(Map<String, dynamic>.from(user));
  }

  Future<List<UserSummary>> searchUsers(String query) async {
    final String encoded = Uri(
      queryParameters: <String, String>{'q': query, 'limit': '30'},
    ).query;
    final JsonMap data = await request('GET', '/api/messages/users?$encoded');
    return jsonMaps(data['items'])
        .map(UserSummary.fromJson)
        .toList(growable: false);
  }

  Future<int> createGroup({
    required String title,
    required List<String> members,
  }) async {
    final JsonMap data = await request(
      'POST',
      '/api/messages/groups',
      payload: <String, dynamic>{'title': title, 'members': members},
    );
    final Object? threadValue = data['thread'];
    final Object? groupValue = threadValue is Map ? threadValue['group'] : null;
    final int? groupId = groupValue is Map ? jsonInt(groupValue['id']) : null;
    if (groupId == null || groupId <= 0) {
      throw const ApiException('Сервер не вернул созданную группу');
    }
    return groupId;
  }

  Future<int> joinGroup(String token) async {
    final JsonMap data = await request(
      'POST',
      '/api/messages/groups/join',
      payload: <String, dynamic>{'token': token},
    );
    final int? groupId = jsonInt(data['groupId']);
    if (groupId == null || groupId <= 0) {
      throw const ApiException('Сервер не вернул номер группы');
    }
    return groupId;
  }

  Future<JsonMap> sendMessage({
    required String path,
    required String body,
    required List<OutgoingImage> images,
  }) async {
    if (images.isEmpty) {
      return request('POST', path, payload: <String, dynamic>{'body': body});
    }

    final Uri uri;
    try {
      uri = Uri.parse('$baseUrl$path');
    } on FormatException {
      throw const ApiException('Некорректный адрес сервера');
    }

    final http.MultipartRequest upload = http.MultipartRequest('POST', uri)
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Musorgram/1.0 Flutter',
      });
    if (body.isNotEmpty) {
      upload.fields['body'] = body;
    }
    try {
      for (final OutgoingImage image in images) {
        upload.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            filename: image.name,
            contentType: MediaType.parse(image.mimeType),
          ),
        );
      }
    } on Object {
      throw const ApiException('Не удалось прочитать выбранное изображение');
    }

    late http.StreamedResponse response;
    String raw = '';
    try {
      response = await _httpClient
          .send(upload)
          .timeout(const Duration(seconds: 60));
      raw = await response.stream.bytesToString().timeout(
        const Duration(seconds: 30),
      );
    } on TimeoutException {
      throw const ApiException('Сервер не ответил вовремя');
    } on http.ClientException {
      throw const ApiException('Не удалось связаться с MusorBox');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException('MusorBox вернул некорректный ответ');
      }
    }
    final JsonMap? data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = data?['error']?.toString().trim() ?? '';
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Ошибка сервера (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (data == null || data['ok'] != true) {
      final String message = data?['error']?.toString().trim() ?? '';
      throw ApiException(message.isNotEmpty ? message : 'Запрос не выполнен');
    }
    return data;
  }

  Future<void> revokeCurrentToken() async {
    await request('DELETE', '/api/auth/token');
  }

  void close() {
    _httpClient.close();
  }

  String _cacheKey(String method, String path) => '$method $path';
}

typedef SseStateCallback = void Function(bool connected);
typedef SseEventCallback = void Function(String name, JsonMap payload);
typedef SseErrorCallback = void Function(ApiException error);

class SseConnection {
  SseConnection({
    required this.baseUrl,
    required this.token,
    required this.onState,
    required this.onEvent,
    required this.onError,
  });

  final String baseUrl;
  final String token;
  final SseStateCallback onState;
  final SseEventCallback onEvent;
  final SseErrorCallback onError;

  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _disconnectGrace = Duration(seconds: 5);

  bool _closed = false;
  bool _reportedConnected = false;
  http.Client? _activeClient;
  Timer? _disconnectTimer;

  void start() {
    unawaited(_run());
  }

  Future<void> _run() async {
    bool reportedAuthorizationError = false;
    while (!_closed) {
      final http.Client client = http.Client();
      _activeClient = client;
      try {
        final http.Request request =
            http.Request(
                'GET',
                Uri.parse(
                  '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/messages/events',
                ),
              )
              ..headers.addAll(<String, String>{
                'Accept': 'text/event-stream',
                'Authorization': 'Bearer $token',
                'Cache-Control': 'no-cache',
                'User-Agent': 'Musorgram/1.0 Flutter',
              });
        final http.StreamedResponse response = await client
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (!reportedAuthorizationError || response.statusCode != 401) {
            onError(
              ApiException(
                'Realtime-соединение отклонено сервером '
                '(${response.statusCode})',
                statusCode: response.statusCode,
              ),
            );
          }
          reportedAuthorizationError = response.statusCode == 401;
        } else {
          reportedAuthorizationError = false;
          _markConnected();
          await _readEvents(response);
        }
      } on TimeoutException {
        // Reconnect below. A ping is expected every 15 seconds while connected.
      } on http.ClientException {
        // Closing the client is also how close() interrupts the active stream.
      } on FormatException {
        onError(const ApiException('Некорректный адрес realtime-сервера'));
      } on Object {
        // Transient network and TLS failures are handled by reconnecting.
      } finally {
        client.close();
        if (identical(_activeClient, client)) {
          _activeClient = null;
        }
        _scheduleDisconnected();
      }

      if (!_closed) {
        await Future<void>.delayed(_reconnectDelay);
      }
    }
  }

  void _markConnected() {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    if (_closed || _reportedConnected) {
      return;
    }
    _reportedConnected = true;
    onState(true);
  }

  void _scheduleDisconnected() {
    if (_closed || !_reportedConnected || _disconnectTimer != null) {
      return;
    }
    _disconnectTimer = Timer(_disconnectGrace, () {
      _disconnectTimer = null;
      _markDisconnected();
    });
  }

  void _markDisconnected() {
    if (!_reportedConnected) {
      return;
    }
    _reportedConnected = false;
    onState(false);
  }

  Future<void> _readEvents(http.StreamedResponse response) async {
    String eventName = 'message';
    bool hasExplicitEvent = false;
    final List<String> dataLines = <String>[];
    final Stream<String> lines = response.stream
        .timeout(const Duration(seconds: 45))
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final String line in lines) {
      if (_closed) {
        return;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        hasExplicitEvent = true;
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      } else if (line.isEmpty) {
        if (hasExplicitEvent || dataLines.isNotEmpty) {
          JsonMap payload = <String, dynamic>{};
          final String rawData = dataLines.join('\n').trim();
          if (rawData.isNotEmpty) {
            try {
              final Object? decoded = jsonDecode(rawData);
              if (decoded is Map) {
                payload = Map<String, dynamic>.from(decoded);
              }
            } on FormatException {
              // Event names are signals; malformed optional data must not hide
              // the signal from the controller.
            }
          }
          onEvent(eventName, payload);
        }
        eventName = 'message';
        hasExplicitEvent = false;
        dataLines.clear();
      }
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    _activeClient?.close();
    _activeClient = null;
    _markDisconnected();
  }
}
