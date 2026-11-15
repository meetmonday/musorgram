import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/data/models.dart';

void main() {
  test('parses a direct chat', () {
    final ChatSummary chat = ChatSummary.fromJson(<String, dynamic>{
      'kind': 'direct',
      'partner': <String, dynamic>{
        'id': 2,
        'username': 'Reader',
        'fullName': 'Читатель',
        'avatarUrl': '/uploads/reader.png',
      },
      'lastMessage': <String, dynamic>{
        'id': 12,
        'senderId': 2,
        'body': 'Привет',
      },
      'unreadCount': 1,
      'updatedAt': '2026-11-14T10:00:00Z',
    });

    expect(chat.kind, ChatKind.direct);
    expect(chat.key, 'direct:Reader');
    expect(chat.displayName, 'Читатель');
    expect(chat.address, ChatAddress.direct('Reader'));
    expect(chat.lastMessage?.body, 'Привет');
  });

  test('parses group thread metadata and messages', () {
    final ThreadData thread = ThreadData.fromJson(<String, dynamic>{
      'group': <String, dynamic>{
        'title': 'Редакция',
        'ownerId': 4,
        'inviteUrl': 'https://example.test/messages/groups/join/token',
      },
      'currentUserRole': 'owner',
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'senderId': 4,
          'senderUsername': 'Helper',
          'body': 'Готово',
        },
      ],
      'members': <Map<String, dynamic>>[
        <String, dynamic>{'id': 4, 'username': 'Helper'},
      ],
      'hasOlder': true,
      'olderBefore': 10,
      'readThroughId': 8,
    }, ownUserId: 9);

    expect(thread.groupTitle, 'Редакция');
    expect(thread.groupOwnerId, 4);
    expect(
      thread.groupInviteUrl,
      'https://example.test/messages/groups/join/token',
    );
    expect(thread.currentUserRole, 'owner');
    expect(thread.messages.single.authorName, 'Helper');
    expect(thread.members.single.username, 'Helper');
    expect(thread.hasOlder, isTrue);
    expect(thread.olderBefore, 10);
  });

  test('parses an image album and uses its caption as preview', () {
    final MessageItem message = MessageItem.fromJson(<String, dynamic>{
      'id': 15,
      'senderId': 7,
      'body': 'Две фотографии',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 31,
          'url': '/api/messages/media/31',
          'thumbnailUrl': '/api/messages/media/31?size=thumb',
          'width': 1600,
          'height': 900,
          'mimeType': 'image/jpeg',
          'sizeBytes': 120000,
        },
        <String, dynamic>{
          'id': 32,
          'url': '/api/messages/media/32',
          'width': 800,
          'height': 800,
          'mimeType': 'image/png',
          'sizeBytes': 240000,
        },
      ],
    });

    expect(message.images, hasLength(2));
    expect(message.images.first.id, 31);
    expect(message.images.first.width, 1600);
    expect(message.images.first.previewUrl, contains('size=thumb'));
    expect(message.previewText, 'Две фотографии');
  });

  test('uses a photo label when an image message has no caption', () {
    final MessageItem message = MessageItem.fromJson(<String, dynamic>{
      'id': 16,
      'senderId': 7,
      'body': '',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{'id': 33, 'url': '/api/messages/media/33'},
      ],
    });

    expect(message.previewText, 'Фотография');
  });
}
