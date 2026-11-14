import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../services/notification_service.dart';

class MusorgramController extends ChangeNotifier {
  MusorgramController({required this.api, required this.notifications});

  final ApiClient api;
  final AppNotificationService notifications;

  UserSummary? _me;
  List<ChatSummary> _chats = <ChatSummary>[];
  ConversationTarget? _current;
  List<MessageItem> _messages = <MessageItem>[];
  List<UserSummary> _members = <UserSummary>[];
  int? _groupOwnerId;
  String? _groupInviteUrl;
  String? _currentUserRole;
  bool _hasOlder = false;
  int? _olderBefore;
  int _readThroughId = 0;

  bool _initialLoading = true;
  bool _chatLoading = false;
  bool _olderLoading = false;
  bool _updatesLoading = false;
  bool _connected = false;
  bool _appActive = true;
  bool _disposed = false;
  bool _chatsInitialized = false;
  bool _eventsSeenReady = false;
  int _chatGeneration = 0;

  bool _refreshingChats = false;
  bool _refreshCurrentNotify = false;
  bool _refreshPending = false;
  bool _refreshPendingNotify = false;
  Timer? _refreshTimer;
  bool _scheduledRefreshNotify = false;
  Timer? _errorTimer;
  String? _errorMessage;
  SseConnection? _events;
  StreamSubscription<ChatAddress>? _notificationSubscription;
  ChatAddress? _pendingInitialChat;

  UserSummary? get me => _me;
  List<ChatSummary> get chats => _chats;
  ConversationTarget? get current => _current;
  List<MessageItem> get messages => _messages;
  List<UserSummary> get members => _members;
  int? get groupOwnerId => _groupOwnerId;
  String? get groupInviteUrl => _groupInviteUrl;
  bool get ownsCurrentGroup => _currentUserRole == 'owner';
  bool get hasOlder => _hasOlder;
  int get readThroughId => _readThroughId;
  bool get initialLoading => _initialLoading;
  bool get chatLoading => _chatLoading;
  bool get olderLoading => _olderLoading;
  bool get connected => _connected;
  String? get errorMessage => _errorMessage;

  int get unreadCount {
    return _chats.fold<int>(
      0,
      (int total, ChatSummary chat) => total + chat.unreadCount,
    );
  }

  String get currentTitle => _current?.title ?? '';

  String get currentSubtitle {
    final ConversationTarget? target = _current;
    if (target == null) {
      return '';
    }
    if (target.address.kind == ChatKind.direct) {
      final UserSummary? partner = target.partner;
      return lastSeenText(
        partner?.username ?? target.address.stringIdentifier,
        partner?.lastSeenAt,
      );
    }
    final int count = _members.isNotEmpty
        ? _members.length
        : target.memberCount;
    return count > 0 ? '$count ${memberWord(count)}' : 'групповой чат';
  }

  Future<void> bootstrap() async {
    _notificationSubscription = notifications.openedChats.listen(openAddress);
    _pendingInitialChat = notifications.takeInitialChat();
    unawaited(notifications.requestPermission());

    _events = SseConnection(
      baseUrl: api.baseUrl,
      token: api.token,
      onState: _setConnectionState,
      onEvent: _onEvent,
      onError: (ApiException error) => _showError(error),
    )..start();

    final bool restoredCache = await _restoreCachedOverview();
    if (_disposed) {
      return;
    }
    if (restoredCache) {
      _initialLoading = false;
      _notify();
    }

    await Future.wait<void>(<Future<void>>[_loadMe(), refreshChats()]);
    if (_disposed) {
      return;
    }
    _initialLoading = false;
    _notify();

    final ChatAddress? initialChat = _pendingInitialChat;
    _pendingInitialChat = null;
    if (initialChat != null) {
      openAddress(initialChat);
    }
  }

  Future<void> _loadMe() async {
    try {
      _me = await api.getMe();
      _notify();
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<bool> _restoreCachedOverview() async {
    bool restored = false;
    final JsonMap? profileData = await api.readCached('/api/me');
    if (_disposed) {
      return false;
    }
    final Object? userValue = profileData?['user'];
    if (userValue is Map) {
      _me = UserSummary.fromJson(Map<String, dynamic>.from(userValue));
      restored = true;
    }

    const String chatsPath = '/api/messages?limit=100';
    final JsonMap? chatsData = await api.readCached(chatsPath);
    if (_disposed) {
      return false;
    }
    if (chatsData != null && chatsData['items'] is List) {
      _chats = _chatsFromData(chatsData);
      _chatsInitialized = true;
      restored = true;
    }
    return restored;
  }

  Future<void> refreshChats({bool notifyIncoming = false}) async {
    if (_disposed) {
      return;
    }
    if (_refreshingChats) {
      _refreshPending = true;
      _refreshCurrentNotify = _refreshCurrentNotify || notifyIncoming;
      _refreshPendingNotify = _refreshPendingNotify || notifyIncoming;
      return;
    }

    _refreshingChats = true;
    _refreshCurrentNotify = notifyIncoming;
    final List<ChatSummary> previous = List<ChatSummary>.from(_chats);
    final bool wasInitialized = _chatsInitialized;
    try {
      const String path = '/api/messages?limit=100';
      final JsonMap data = await api.request('GET', path, cacheResponse: true);
      final List<ChatSummary> updated = _chatsFromData(data);
      _chats = updated;
      _chatsInitialized = true;

      final ConversationTarget? selected = _current;
      if (selected != null) {
        for (final ChatSummary chat in updated) {
          if (chat.key == selected.address.key) {
            _current =
                selected.address.kind == ChatKind.direct &&
                    selected.partner?.lastSeenAt != null &&
                    chat.partner?.lastSeenAt == null
                ? selected
                : selected.withChat(chat);
            break;
          }
        }
      }

      if (wasInitialized && _refreshCurrentNotify) {
        _notifyIncoming(previous, updated);
      }
      _withdrawReadNotifications(updated);
      _notify();
    } on Object catch (error) {
      _showError(error);
    } finally {
      _refreshingChats = false;
      _refreshCurrentNotify = false;
      final bool pending = _refreshPending;
      final bool pendingNotify = _refreshPendingNotify;
      _refreshPending = false;
      _refreshPendingNotify = false;
      if (pending && !_disposed) {
        unawaited(refreshChats(notifyIncoming: pendingNotify));
      }
    }
  }

  void openAddress(ChatAddress address) {
    ChatSummary? hint;
    for (final ChatSummary chat in _chats) {
      if (chat.key == address.key) {
        hint = chat;
        break;
      }
    }
    if (hint != null) {
      unawaited(openConversation(ConversationTarget.fromChat(hint)));
      return;
    }
    if (address.kind == ChatKind.direct) {
      unawaited(
        openConversation(
          ConversationTarget.directUser(
            UserSummary(
              id: null,
              username: address.stringIdentifier,
              fullName: null,
              avatarUrl: null,
              lastSeenAt: null,
            ),
          ),
        ),
      );
    } else {
      unawaited(openConversation(ConversationTarget(address: address)));
    }
  }

  void openChat(ChatSummary chat) {
    unawaited(openConversation(ConversationTarget.fromChat(chat)));
  }

  void openDirectUser(UserSummary user) {
    unawaited(openConversation(ConversationTarget.directUser(user)));
  }

  Future<void> openConversation(ConversationTarget target) async {
    if (_disposed || target.address.stringIdentifier.isEmpty) {
      return;
    }
    _chatGeneration += 1;
    final int generation = _chatGeneration;
    _current = target;
    _messages = <MessageItem>[];
    _members = <UserSummary>[];
    _groupOwnerId = null;
    _groupInviteUrl = null;
    _currentUserRole = null;
    _hasOlder = false;
    _olderBefore = null;
    _readThroughId = 0;
    _updatesLoading = false;
    _olderLoading = false;
    _chatLoading = true;
    _notify();
    unawaited(notifications.cancel(target.address));

    final String path = _threadPath(target.address);
    bool restoredCache = false;
    final JsonMap? cachedData = await api.readCached(path);
    if (_disposed || generation != _chatGeneration) {
      return;
    }
    final Object? cachedThreadValue = cachedData?['thread'];
    if (cachedThreadValue is Map) {
      final ThreadData cachedThread = ThreadData.fromJson(
        Map<String, dynamic>.from(cachedThreadValue),
        ownUserId: _me?.id,
      );
      _applyThread(target, cachedThread);
      _chatLoading = false;
      restoredCache = true;
      _notify();
    }

    try {
      final JsonMap data = await api.request('GET', path, cacheResponse: true);
      if (_disposed || generation != _chatGeneration) {
        return;
      }
      final Object? threadValue = data['thread'];
      if (threadValue is! Map) {
        throw const ApiException('В ответе сервера отсутствует переписка');
      }
      final ThreadData thread = ThreadData.fromJson(
        Map<String, dynamic>.from(threadValue),
        ownUserId: _me?.id,
      );
      _applyThread(target, thread);
      _chatLoading = false;
      _notify();
      unawaited(refreshChats());
    } on Object catch (error) {
      if (!_disposed && generation == _chatGeneration) {
        _chatLoading = false;
        if (!restoredCache || !_connected) {
          _showError(error);
        }
      }
    }
  }

  void closeConversation() {
    _chatGeneration += 1;
    _current = null;
    _messages = <MessageItem>[];
    _members = <UserSummary>[];
    _groupOwnerId = null;
    _groupInviteUrl = null;
    _currentUserRole = null;
    _hasOlder = false;
    _olderBefore = null;
    _readThroughId = 0;
    _chatLoading = false;
    _olderLoading = false;
    _updatesLoading = false;
    _notify();
  }

  Future<void> loadOlder() async {
    final ConversationTarget? selected = _current;
    final int? before = _olderBefore;
    if (selected == null || !_hasOlder || before == null || _olderLoading) {
      return;
    }
    final int generation = _chatGeneration;
    _olderLoading = true;
    _notify();
    try {
      final JsonMap data = await api.request(
        'GET',
        '${_threadPath(selected.address)}?before=$before',
      );
      if (_disposed || generation != _chatGeneration) {
        return;
      }
      final Object? threadValue = data['thread'];
      if (threadValue is! Map) {
        throw const ApiException('Не удалось загрузить историю');
      }
      final ThreadData thread = ThreadData.fromJson(
        Map<String, dynamic>.from(threadValue),
        ownUserId: _me?.id,
      );
      final Set<int> existing = _messages
          .map((MessageItem message) => message.id)
          .toSet();
      _messages = <MessageItem>[
        ...thread.messages.where(
          (MessageItem message) => !existing.contains(message.id),
        ),
        ..._messages,
      ];
      _hasOlder = thread.hasOlder;
      _olderBefore = thread.olderBefore;
      _olderLoading = false;
      _notify();
    } on Object catch (error) {
      if (!_disposed && generation == _chatGeneration) {
        _olderLoading = false;
        _showError(error);
      }
    }
  }

  Future<bool> sendMessage(String rawBody) async {
    final ConversationTarget? selected = _current;
    final String body = rawBody.trim();
    if (selected == null || body.isEmpty || _chatLoading) {
      return false;
    }
    final int generation = _chatGeneration;
    final int pendingId = -DateTime.now().microsecondsSinceEpoch;
    final MessageItem pending = MessageItem(
      id: pendingId,
      senderId: _me?.id ?? 0,
      senderUsername: _me?.username ?? 'Вы',
      senderName: _me?.displayName,
      senderAvatarUrl: _me?.avatarUrl,
      body: body,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      readAt: null,
      own: true,
      pending: true,
    );
    _messages = <MessageItem>[..._messages, pending];
    _notify();

    final String path = selected.address.kind == ChatKind.direct
        ? '/api/messages/direct/'
              '${Uri.encodeComponent(selected.address.stringIdentifier)}'
        : '/api/messages/groups/${selected.address.groupId}/messages';
    try {
      final JsonMap data = await api.request(
        'POST',
        path,
        payload: <String, dynamic>{'body': body},
      );
      if (_disposed) {
        return true;
      }
      if (generation != _chatGeneration) {
        unawaited(refreshChats());
        return true;
      }
      final Object? messageValue = data['message'];
      if (messageValue is! Map) {
        throw const ApiException('Сервер не вернул отправленное сообщение');
      }
      final MessageItem sent = MessageItem.fromJson(
        Map<String, dynamic>.from(messageValue),
        ownUserId: _me?.id,
      ).copyWith(own: true, pending: false);
      _messages = _messages
          .map(
            (MessageItem message) => message.id == pendingId ? sent : message,
          )
          .toList(growable: true);
      _notify();
      unawaited(refreshChats());
      return true;
    } on Object catch (error) {
      if (!_disposed && generation == _chatGeneration) {
        _messages = _messages
            .where((MessageItem message) => message.id != pendingId)
            .toList(growable: true);
        _showError(error);
      }
      return false;
    }
  }

  Future<void> fetchUpdates() async {
    final ConversationTarget? selected = _current;
    if (selected == null || _updatesLoading || _chatLoading) {
      return;
    }
    final int generation = _chatGeneration;
    final int after = _messages
        .where((MessageItem message) => message.id > 0)
        .fold<int>(
          0,
          (int value, MessageItem item) => item.id > value ? item.id : value,
        );
    _updatesLoading = true;
    final String path = selected.address.kind == ChatKind.direct
        ? '/api/messages/direct/'
              '${Uri.encodeComponent(selected.address.stringIdentifier)}'
              '/updates?after=$after'
        : '/api/messages/groups/${selected.address.groupId}'
              '/updates?after=$after';
    try {
      final JsonMap data = await api.request('GET', path);
      if (_disposed || generation != _chatGeneration) {
        return;
      }
      final List<MessageItem> incoming = jsonMaps(data['messages'])
          .map((JsonMap item) => MessageItem.fromJson(item, ownUserId: _me?.id))
          .toList(growable: false);
      final Set<int> existing = _messages
          .map((MessageItem message) => message.id)
          .toSet();
      final List<MessageItem> fresh = incoming
          .where((MessageItem message) => !existing.contains(message.id))
          .toList(growable: false);
      final int readThrough = jsonInt(data['readThroughId']) ?? _readThroughId;
      final bool readChanged = readThrough != _readThroughId;
      _readThroughId = readThrough;
      if (fresh.isNotEmpty || readChanged) {
        _messages = <MessageItem>[..._messages, ...fresh];
        _notify();
      }
      unawaited(refreshChats());
    } on Object {
      // Realtime updates are best-effort; reconnect and app activation retry.
    } finally {
      if (!_disposed && generation == _chatGeneration) {
        _updatesLoading = false;
      }
    }
  }

  Future<List<UserSummary>> searchUsers(String query) {
    return api.searchUsers(query);
  }

  Future<bool> createGroup(String rawTitle, List<UserSummary> members) async {
    final String title = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.runes.length < 2 || title.runes.length > 80) {
      _showError('Название группы должно содержать от 2 до 80 символов');
      return false;
    }
    try {
      final int groupId = await api.createGroup(
        title: title,
        members: members
            .map((UserSummary user) => user.username)
            .toList(growable: false),
      );
      await refreshChats();
      openAddress(ChatAddress.group(groupId));
      return true;
    } on Object catch (error) {
      _showError(error);
      return false;
    }
  }

  Future<bool> joinGroup(String rawInvite) async {
    final String value = rawInvite.trim();
    if (value.isEmpty) {
      _showError('Вставьте ссылку-приглашение или токен');
      return false;
    }
    final Uri? uri = Uri.tryParse(value);
    final List<String> parts =
        (uri != null && uri.hasScheme ? uri.pathSegments : value.split('/'))
            .where((String part) => part.isNotEmpty)
            .toList();
    final String token = parts.isEmpty ? '' : parts.last;
    if (token.isEmpty) {
      _showError('Не удалось прочитать приглашение');
      return false;
    }
    try {
      final int groupId = await api.joinGroup(token);
      await refreshChats();
      openAddress(ChatAddress.group(groupId));
      return true;
    } on Object catch (error) {
      _showError(error);
      return false;
    }
  }

  void setAppActive(bool active) {
    if (_appActive == active || _disposed) {
      return;
    }
    _appActive = active;
    if (active && _chatsInitialized) {
      final ConversationTarget? selected = _current;
      if (selected != null) {
        unawaited(notifications.cancel(selected.address));
        unawaited(fetchUpdates());
      }
      scheduleRefresh();
    }
  }

  void scheduleRefresh({bool notifyIncoming = false}) {
    _scheduledRefreshNotify = _scheduledRefreshNotify || notifyIncoming;
    if (_refreshTimer != null || _disposed) {
      return;
    }
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      _refreshTimer = null;
      final bool shouldNotify = _scheduledRefreshNotify;
      _scheduledRefreshNotify = false;
      unawaited(refreshChats(notifyIncoming: shouldNotify));
    });
  }

  void clearError() {
    _errorTimer?.cancel();
    _errorTimer = null;
    if (_errorMessage != null) {
      _errorMessage = null;
      _notify();
    }
  }

  void _onEvent(String name, JsonMap _) {
    if (_disposed) {
      return;
    }
    if (name == 'ready') {
      final bool notifyMissed = _eventsSeenReady && _chatsInitialized;
      _eventsSeenReady = true;
      scheduleRefresh(notifyIncoming: notifyMissed);
      if (_appActive && _current != null) {
        unawaited(fetchUpdates());
      }
    } else if (name == 'message') {
      scheduleRefresh(notifyIncoming: true);
      if (_appActive && _current != null) {
        unawaited(fetchUpdates());
      }
    } else if (name == 'read') {
      scheduleRefresh();
      if (_appActive && _current != null) {
        unawaited(fetchUpdates());
      }
    }
  }

  void _setConnectionState(bool connected) {
    if (_disposed || _connected == connected) {
      return;
    }
    _connected = connected;
    _notify();
  }

  void _notifyIncoming(List<ChatSummary> previous, List<ChatSummary> updated) {
    final int? ownId = _me?.id;
    if (ownId == null) {
      return;
    }
    for (final ChatSummary chat in incomingChatChanges(
      previous,
      updated,
      ownId,
    )) {
      if (_appActive && chat.key == _current?.address.key) {
        continue;
      }
      unawaited(notifications.showIncoming(chat));
    }
  }

  void _withdrawReadNotifications(List<ChatSummary> updated) {
    for (final ChatSummary chat in updated) {
      if (chat.unreadCount == 0) {
        unawaited(notifications.cancel(chat.address));
      }
    }
  }

  String _threadPath(ChatAddress address) {
    if (address.kind == ChatKind.direct) {
      return '/api/messages/direct/'
          '${Uri.encodeComponent(address.stringIdentifier)}';
    }
    return '/api/messages/groups/${address.groupId}';
  }

  List<ChatSummary> _chatsFromData(JsonMap data) {
    final int? ownId = _me?.id;
    return jsonMaps(data['items'])
        .map((JsonMap item) => ChatSummary.fromJson(item, ownUserId: ownId))
        .toList(growable: false);
  }

  void _applyThread(ConversationTarget target, ThreadData thread) {
    _messages = thread.messages;
    _members = thread.members;
    _groupOwnerId = thread.groupOwnerId;
    _groupInviteUrl = thread.groupInviteUrl;
    _currentUserRole = thread.currentUserRole;
    _hasOlder = thread.hasOlder;
    _olderBefore = thread.olderBefore;
    _readThroughId = thread.readThroughId;
    if (target.address.kind == ChatKind.direct && thread.partner != null) {
      _current = target.copyWith(partner: thread.partner);
    } else if (target.address.kind == ChatKind.group) {
      _current = target.copyWith(
        groupTitle: thread.groupTitle,
        memberCount: thread.members.length,
      );
    }
  }

  void _showError(Object error) {
    if (_disposed) {
      return;
    }
    _errorMessage = error.toString();
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 7), clearError);
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.close();
    _notificationSubscription?.cancel();
    _refreshTimer?.cancel();
    _errorTimer?.cancel();
    api.close();
    super.dispose();
  }
}

List<ChatSummary> incomingChatChanges(
  List<ChatSummary> previous,
  List<ChatSummary> current,
  int ownUserId,
) {
  final Map<String, ChatSummary> before = <String, ChatSummary>{
    for (final ChatSummary chat in previous) chat.key: chat,
  };
  final List<ChatSummary> changed = <ChatSummary>[];
  for (final ChatSummary chat in current) {
    final MessageItem? last = chat.lastMessage;
    if (last == null || last.senderId == ownUserId) {
      continue;
    }
    final ChatSummary? oldChat = before[chat.key];
    final int oldId = oldChat?.lastMessage?.id ?? 0;
    final int oldUnread = oldChat?.unreadCount ?? 0;
    if (last.id > oldId && chat.unreadCount > oldUnread) {
      changed.add(chat);
    }
  }
  return changed;
}
