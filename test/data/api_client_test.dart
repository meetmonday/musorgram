import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musorgram/data/api_client.dart';

void main() {
  test('sends bearer token and decodes a successful response', () async {
    final ApiClient api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'secret-token',
      httpClient: MockClient((http.Request request) async {
        expect(request.url.path, '/api/me');
        expect(request.headers['Authorization'], 'Bearer secret-token');
        return http.Response(
          jsonEncode(<String, Object>{
            'ok': true,
            'user': <String, Object>{'id': 7, 'username': 'Reader'},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final user = await api.getMe();
    expect(user.id, 7);
    expect(user.username, 'Reader');
    api.close();
  });

  test('uses server error text', () async {
    final ApiClient api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'bad-token',
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, Object>{
            'ok': false,
            'error': 'Токен недействителен',
          }),
          401,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );

    await expectLater(
      api.getMe(),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'status', 401)
            .having(
              (ApiException error) => error.message,
              'message',
              'Токен недействителен',
            ),
      ),
    );
    api.close();
  });

  test('creates a group and returns its id', () async {
    late http.Request sentRequest;
    final ApiClient api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'secret-token',
      httpClient: MockClient((http.Request request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'ok': true,
            'thread': <String, Object>{
              'group': <String, Object>{'id': 42, 'title': 'Редакция'},
            },
          }),
          201,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );

    final int groupId = await api.createGroup(
      title: 'Редакция',
      members: <String>['Reader'],
    );
    expect(groupId, 42);
    expect(sentRequest.method, 'POST');
    expect(sentRequest.url.path, '/api/messages/groups');
    expect(jsonDecode(sentRequest.body), <String, Object>{
      'title': 'Редакция',
      'members': <String>['Reader'],
    });
    api.close();
  });

  test('joins a group using an invite token', () async {
    late http.Request sentRequest;
    final ApiClient api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'secret-token',
      httpClient: MockClient((http.Request request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode(<String, Object>{'ok': true, 'groupId': 17}),
          200,
        );
      }),
    );

    expect(await api.joinGroup('invite'), 17);
    expect(sentRequest.method, 'POST');
    expect(sentRequest.url.path, '/api/messages/groups/join');
    expect(jsonDecode(sentRequest.body), <String, Object>{'token': 'invite'});
    api.close();
  });

  test('dispatches payload-free SSE events as signals', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final Completer<void> requestHandled = Completer<void>();
    unawaited(
      server.first.then((HttpRequest request) async {
        expect(request.uri.path, '/api/messages/events');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          )
          ..write('event: message\ndata:\n\n');
        await request.response.flush();
        await request.response.close();
        requestHandled.complete();
      }),
    );

    final Completer<String> eventReceived = Completer<String>();
    late final SseConnection connection;
    connection = SseConnection(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'test-token',
      onState: (_) {},
      onEvent: (String name, _) {
        if (!eventReceived.isCompleted) {
          eventReceived.complete(name);
        }
      },
      onError: (_) {},
    )..start();

    try {
      await requestHandled.future.timeout(const Duration(seconds: 1));
      expect(
        await eventReceived.future.timeout(const Duration(milliseconds: 250)),
        'message',
      );
    } finally {
      connection.close();
      await server.close(force: true);
    }
  });
}
