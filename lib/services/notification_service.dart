import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models.dart';

abstract interface class AppNotificationService {
  Stream<ChatAddress> get openedChats;

  ChatAddress? takeInitialChat();

  Future<void> requestPermission();

  Future<void> showIncoming(ChatSummary chat);

  Future<void> cancel(ChatAddress address);

  Future<void> cancelAll();

  Future<void> dispose();
}

class LocalNotificationService implements AppNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ChatAddress> _openedChats =
      StreamController<ChatAddress>.broadcast();

  bool _ready = false;
  ChatAddress? _initialChat;

  Future<void> initialize() async {
    try {
      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_musorgram'),
        linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onResponse,
      );
      _ready = true;

      final NotificationAppLaunchDetails? launch = await _plugin
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _initialChat = _decodeAddress(launch?.notificationResponse?.payload);
      }
    } on Object {
      // Notifications are optional: unsupported desktop sessions should not
      // prevent messages from loading.
      _ready = false;
    }
  }

  @override
  Stream<ChatAddress> get openedChats => _openedChats.stream;

  @override
  ChatAddress? takeInitialChat() {
    final ChatAddress? result = _initialChat;
    _initialChat = null;
    return result;
  }

  @override
  Future<void> requestPermission() async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } on Object {
      // The user can keep using the client without notifications.
    }
  }

  @override
  Future<void> showIncoming(ChatSummary chat) async {
    if (!_ready || chat.lastMessage == null) {
      return;
    }
    String title = chat.displayName;
    if (chat.unreadCount > 1) {
      title = '$title · ${chat.unreadCount} непрочитанных';
    }
    String body = chat.lastMessage!.body.replaceAll('\n', ' ');
    if (chat.kind == ChatKind.group) {
      final String sender = chat.lastMessage!.senderName?.trim() ?? '';
      if (sender.isNotEmpty) {
        body = '$sender: $body';
      }
    }
    if (body.length > 220) {
      body = '${body.substring(0, 217)}…';
    }

    try {
      await _plugin.show(
        id: _notificationId(chat.key),
        title: title,
        body: body.isEmpty ? 'Новое сообщение' : body,
        payload: jsonEncode(<String, Object>{
          'kind': chat.kind.apiValue,
          'id': chat.address.stringIdentifier,
        }),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'musorgram_messages',
            'Сообщения',
            channelDescription: 'Новые личные и групповые сообщения',
            category: AndroidNotificationCategory.message,
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF5682A3),
          ),
          linux: LinuxNotificationDetails(
            category: LinuxNotificationCategory.imReceived,
            urgency: LinuxNotificationUrgency.normal,
            defaultActionName: 'Открыть',
          ),
        ),
      );
    } on Object {
      // Notification servers are not guaranteed to be available on Linux.
    }
  }

  @override
  Future<void> cancel(ChatAddress address) async {
    if (!_ready) {
      return;
    }
    try {
      await _plugin.cancel(id: _notificationId(address.key));
    } on Object {
      // No-op on platforms that already removed the notification.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) {
      return;
    }
    try {
      await _plugin.cancelAll();
    } on Object {
      // Optional platform integration.
    }
  }

  void _onResponse(NotificationResponse response) {
    final ChatAddress? address = _decodeAddress(response.payload);
    if (address != null && !_openedChats.isClosed) {
      _openedChats.add(address);
    }
  }

  ChatAddress? _decodeAddress(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
      if (data['kind'] == 'group') {
        final int? id = int.tryParse(data['id']?.toString() ?? '');
        return id == null ? null : ChatAddress.group(id);
      }
      if (data['kind'] == 'direct') {
        final String username = data['id']?.toString() ?? '';
        return username.isEmpty ? null : ChatAddress.direct(username);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await _openedChats.close();
  }
}

int _notificationId(String key) {
  // Stable 31-bit FNV-1a hash so the same chat replaces its prior alert.
  int hash = 0x811c9dc5;
  for (final int byte in utf8.encode(key)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
