typedef JsonMap = Map<String, dynamic>;

int? jsonInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

enum ChatKind {
  direct,
  group;

  static ChatKind fromJson(Object? value) {
    return value == 'group' ? ChatKind.group : ChatKind.direct;
  }

  String get apiValue => name;
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.lastSeenAt,
  });

  factory UserSummary.fromJson(JsonMap json) {
    return UserSummary(
      id: jsonInt(json['id']),
      username: (json['username'] ?? '').toString(),
      fullName: _nullableString(json['fullName']),
      avatarUrl: _nullableString(json['avatarUrl']),
      lastSeenAt: _nullableString(json['lastSeenAt']),
    );
  }

  final int? id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? lastSeenAt;

  String get displayName {
    final String name = fullName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return username.isNotEmpty ? username : 'Без имени';
  }
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.own,
    this.pending = false,
  });

  factory MessageItem.fromJson(JsonMap json, {int? ownUserId}) {
    final int senderId = jsonInt(json['senderId']) ?? 0;
    return MessageItem(
      id: jsonInt(json['id']) ?? 0,
      senderId: senderId,
      senderUsername: (json['senderUsername'] ?? '').toString(),
      senderName: _nullableString(json['senderName']),
      senderAvatarUrl: _nullableString(json['senderAvatarUrl']),
      body: (json['body'] ?? '').toString(),
      createdAt: _nullableString(json['createdAt']),
      readAt: _nullableString(json['readAt']),
      own: json['own'] == true || (ownUserId != null && senderId == ownUserId),
      pending: json['_pending'] == true,
    );
  }

  final int id;
  final int senderId;
  final String senderUsername;
  final String? senderName;
  final String? senderAvatarUrl;
  final String body;
  final String? createdAt;
  final String? readAt;
  final bool own;
  final bool pending;

  String get authorName {
    if (senderUsername.isNotEmpty) {
      return senderUsername;
    }
    final String name = senderName?.trim() ?? '';
    return name.isNotEmpty ? name : 'Участник';
  }

  MessageItem copyWith({bool? own, bool? pending}) {
    return MessageItem(
      id: id,
      senderId: senderId,
      senderUsername: senderUsername,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      body: body,
      createdAt: createdAt,
      readAt: readAt,
      own: own ?? this.own,
      pending: pending ?? this.pending,
    );
  }
}

class ChatSummary {
  const ChatSummary({
    required this.kind,
    required this.groupId,
    required this.title,
    required this.partner,
    required this.memberCount,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ChatSummary.fromJson(JsonMap json, {int? ownUserId}) {
    final ChatKind kind = ChatKind.fromJson(json['kind']);
    final Object? partnerValue = json['partner'];
    final Object? lastMessageValue = json['lastMessage'];
    return ChatSummary(
      kind: kind,
      groupId: kind == ChatKind.group ? jsonInt(json['id']) : null,
      title: _nullableString(json['title']),
      partner: partnerValue is Map
          ? UserSummary.fromJson(Map<String, dynamic>.from(partnerValue))
          : null,
      memberCount: jsonInt(json['memberCount']) ?? 0,
      lastMessage: lastMessageValue is Map
          ? MessageItem.fromJson(
              Map<String, dynamic>.from(lastMessageValue),
              ownUserId: ownUserId,
            )
          : null,
      unreadCount: jsonInt(json['unreadCount']) ?? 0,
      updatedAt: _nullableString(json['updatedAt']),
    );
  }

  final ChatKind kind;
  final int? groupId;
  final String? title;
  final UserSummary? partner;
  final int memberCount;
  final MessageItem? lastMessage;
  final int unreadCount;
  final String? updatedAt;

  String get key {
    if (kind == ChatKind.direct) {
      return 'direct:${partner?.username ?? ''}';
    }
    return 'group:${groupId ?? 0}';
  }

  String get displayName {
    if (kind == ChatKind.direct) {
      return partner?.displayName ?? 'Без имени';
    }
    final String value = title?.trim() ?? '';
    return value.isNotEmpty ? value : 'Группа';
  }

  String? get avatarUrl {
    return kind == ChatKind.direct ? partner?.avatarUrl : null;
  }

  ChatAddress get address {
    if (kind == ChatKind.direct) {
      return ChatAddress.direct(partner?.username ?? '');
    }
    return ChatAddress.group(groupId ?? 0);
  }
}

class ChatAddress {
  const ChatAddress._(this.kind, this.identifier);

  factory ChatAddress.direct(String username) {
    return ChatAddress._(ChatKind.direct, username);
  }

  factory ChatAddress.group(int id) {
    return ChatAddress._(ChatKind.group, id);
  }

  final ChatKind kind;
  final Object identifier;

  String get key => '${kind.apiValue}:$identifier';

  String get stringIdentifier => identifier.toString();

  int get groupId => identifier is int
      ? identifier as int
      : int.tryParse(identifier.toString()) ?? 0;

  @override
  bool operator ==(Object other) {
    return other is ChatAddress && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

class ConversationTarget {
  const ConversationTarget({
    required this.address,
    this.partner,
    this.groupTitle,
    this.memberCount = 0,
  });

  factory ConversationTarget.fromChat(ChatSummary chat) {
    return ConversationTarget(
      address: chat.address,
      partner: chat.partner,
      groupTitle: chat.title,
      memberCount: chat.memberCount,
    );
  }

  factory ConversationTarget.directUser(UserSummary user) {
    return ConversationTarget(
      address: ChatAddress.direct(user.username),
      partner: user,
    );
  }

  final ChatAddress address;
  final UserSummary? partner;
  final String? groupTitle;
  final int memberCount;

  String get title {
    if (address.kind == ChatKind.direct) {
      return partner?.displayName ?? address.stringIdentifier;
    }
    final String value = groupTitle?.trim() ?? '';
    return value.isNotEmpty ? value : 'Группа';
  }

  String? get avatarUrl => partner?.avatarUrl;

  int? get partnerId => partner?.id;

  ConversationTarget withChat(ChatSummary chat) {
    return ConversationTarget.fromChat(chat);
  }

  ConversationTarget copyWith({
    UserSummary? partner,
    String? groupTitle,
    int? memberCount,
  }) {
    return ConversationTarget(
      address: address,
      partner: partner ?? this.partner,
      groupTitle: groupTitle ?? this.groupTitle,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class ThreadData {
  const ThreadData({
    required this.messages,
    required this.hasOlder,
    required this.olderBefore,
    required this.readThroughId,
    required this.members,
    required this.partner,
    required this.groupTitle,
    required this.groupOwnerId,
    required this.groupInviteUrl,
    required this.currentUserRole,
  });

  factory ThreadData.fromJson(JsonMap json, {int? ownUserId}) {
    final Object? partnerValue = json['partner'];
    final Object? groupValue = json['group'];
    final JsonMap? group = groupValue is Map
        ? Map<String, dynamic>.from(groupValue)
        : null;
    return ThreadData(
      messages: _jsonMaps(json['messages'])
          .map(
            (JsonMap item) => MessageItem.fromJson(item, ownUserId: ownUserId),
          )
          .toList(growable: true),
      hasOlder: json['hasOlder'] == true,
      olderBefore: jsonInt(json['olderBefore']),
      readThroughId: jsonInt(json['readThroughId']) ?? 0,
      members: _jsonMaps(json['members'])
          .map(UserSummary.fromJson)
          .toList(growable: false),
      partner: partnerValue is Map
          ? UserSummary.fromJson(Map<String, dynamic>.from(partnerValue))
          : null,
      groupTitle: group == null ? null : _nullableString(group['title']),
      groupOwnerId: group == null ? null : jsonInt(group['ownerId']),
      groupInviteUrl: group == null
          ? null
          : _nullableString(group['inviteUrl']),
      currentUserRole: _nullableString(json['currentUserRole']),
    );
  }

  final List<MessageItem> messages;
  final bool hasOlder;
  final int? olderBefore;
  final int readThroughId;
  final List<UserSummary> members;
  final UserSummary? partner;
  final String? groupTitle;
  final int? groupOwnerId;
  final String? groupInviteUrl;
  final String? currentUserRole;
}

List<JsonMap> jsonMaps(Object? value) => _jsonMaps(value);

List<JsonMap> _jsonMaps(Object? value) {
  if (value is! List) {
    return const <JsonMap>[];
  }
  return value
      .whereType<Map>()
      .map((Map<Object?, Object?> item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final String result = value.toString();
  return result.isEmpty ? null : result;
}
