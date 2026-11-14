import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musorgram/data/api_client.dart';
import 'package:musorgram/data/json_cache_store.dart';
import 'package:musorgram/data/models.dart';
import 'package:musorgram/services/notification_service.dart';
import 'package:musorgram/state/musorgram_controller.dart';

void main() {
  test('detects only newly unread incoming chats', () {
    final List<ChatSummary> before = <ChatSummary>[
      _chat(lastId: 10, senderId: 2, unread: 1),
    ];
    final List<ChatSummary> after = <ChatSummary>[
      _chat(lastId: 11, senderId: 2, unread: 2),
      _chat(username: 'Own', lastId: 5, senderId: 7, unread: 0),
    ];

    final List<ChatSummary> changed = incomingChatChanges(before, after, 7);
    expect(changed, hasLength(1));
    expect(changed.single.partner?.username, 'Reader');
  });

  test(
    'notifies when a notifying refresh overlaps an active refresh',
    () async {
      final Completer<void> secondRequestStarted = Completer<void>();
      final Completer<void> releaseSecondRequest = Completer<void>();
      final Completer<void> thirdRequestCompleted = Completer<void>();
      int chatRequests = 0;
      final _FakeNotifications notifications = _FakeNotifications();
      final ApiClient api = ApiClient(
        baseUrl: 'http://127.0.0.1:1',
        token: 'test-token',
        cacheStore: _MemoryCacheStore(),
        httpClient: MockClient((http.Request request) async {
          if (request.url.path == '/api/me') {
            return _jsonResponse(<String, Object>{
              'ok': true,
              'user': <String, Object>{'id': 7, 'username': 'Me'},
            });
          }
          if (request.url.path == '/api/messages') {
            chatRequests += 1;
            if (chatRequests == 2) {
              secondRequestStarted.complete();
              await releaseSecondRequest.future;
            }
            final bool hasIncoming = chatRequests >= 2;
            final http.Response response = _jsonResponse(<String, Object>{
              'ok': true,
              'items': <Object>[
                _chatJson(
                  lastId: hasIncoming ? 11 : 10,
                  unread: hasIncoming ? 2 : 1,
                ),
              ],
            });
            if (chatRequests == 3) {
              thirdRequestCompleted.complete();
            }
            return response;
          }
          return _jsonResponse(<String, Object>{'ok': false}, 404);
        }),
      );
      final MusorgramController controller = MusorgramController(
        api: api,
        notifications: notifications,
      );

      await controller.bootstrap();
      final Future<void> activeRefresh = controller.refreshChats();
      await secondRequestStarted.future.timeout(const Duration(seconds: 1));
      await controller.refreshChats(notifyIncoming: true);
      releaseSecondRequest.complete();
      await activeRefresh;
      await thirdRequestCompleted.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.lastMessage?.id, 11);

      controller.dispose();
      await notifications.dispose();
    },
  );
}

http.Response _jsonResponse(Map<String, Object> body, [int statusCode = 200]) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object> _chatJson({required int lastId, required int unread}) {
  return <String, Object>{
    'kind': 'direct',
    'partner': <String, Object>{'id': 2, 'username': 'Reader'},
    'lastMessage': <String, Object>{
      'id': lastId,
      'senderId': 2,
      'senderUsername': 'Reader',
      'body': 'Сообщение',
    },
    'unreadCount': unread,
  };
}

class _MemoryCacheStore implements JsonCacheStore {
  @override
  Future<JsonMap?> read(String key) async => null;

  @override
  Future<void> write(String key, JsonMap value) async {}
}

class _FakeNotifications implements AppNotificationService {
  final StreamController<ChatAddress> _opened =
      StreamController<ChatAddress>.broadcast();
  final List<ChatSummary> shown = <ChatSummary>[];

  @override
  Stream<ChatAddress> get openedChats => _opened.stream;

  @override
  Future<void> cancel(ChatAddress address) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> dispose() => _opened.close();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> showIncoming(ChatSummary chat) async {
    shown.add(chat);
  }

  @override
  ChatAddress? takeInitialChat() => null;
}

ChatSummary _chat({
  String username = 'Reader',
  required int lastId,
  required int senderId,
  required int unread,
}) {
  return ChatSummary(
    kind: ChatKind.direct,
    groupId: null,
    title: null,
    partner: UserSummary(
      id: senderId,
      username: username,
      fullName: null,
      avatarUrl: null,
      lastSeenAt: null,
    ),
    memberCount: 0,
    lastMessage: MessageItem(
      id: lastId,
      senderId: senderId,
      senderUsername: username,
      senderName: null,
      senderAvatarUrl: null,
      body: 'Сообщение',
      createdAt: null,
      readAt: null,
      own: false,
    ),
    unreadCount: unread,
    updatedAt: null,
  );
}
