import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/musorgram_controller.dart';
import 'avatar.dart';

class ChatSidebar extends StatelessWidget {
  const ChatSidebar({
    required this.controller,
    required this.baseUrl,
    required this.compact,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onOpenMenu,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;
  final bool compact;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewChat;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String query = searchController.text.trim().toLowerCase();
    final List<ChatSummary> visibleChats = controller.chats
        .where((ChatSummary chat) {
          if (query.isEmpty) {
            return true;
          }
          final MessageItem? last = chat.lastMessage;
          final String haystack = <String>[
            chat.displayName,
            chat.partner?.username ?? '',
            last?.previewText ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);

    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: <Widget>[
          _SidebarHeader(
            controller: controller,
            compact: compact,
            onOpenMenu: onOpenMenu,
            onSearch: () => searchFocusNode.requestFocus(),
            onNewChat: onNewChat,
          ),
          _SearchBox(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: visibleChats.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(26),
                              child: Text(
                                query.isEmpty
                                    ? 'Здесь пока нет чатов'
                                    : 'Чаты не найдены',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: compact ? 82 : 0),
                            itemCount: visibleChats.length,
                            itemExtent: 68,
                            itemBuilder: (BuildContext context, int index) {
                              final ChatSummary chat = visibleChats[index];
                              return ChatListRow(
                                chat: chat,
                                ownUserId: controller.me?.id,
                                baseUrl: baseUrl,
                                selected:
                                    controller.current?.address.key == chat.key,
                                onTap: () => controller.openChat(chat),
                              );
                            },
                          ),
                  ),
                ),
                if (compact)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: FloatingActionButton(
                      tooltip: 'Новое сообщение',
                      onPressed: onNewChat,
                      backgroundColor: context.appPalette.header,
                      foregroundColor: context.appPalette.onHeader,
                      child: const Icon(Icons.edit, size: 21),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.controller,
    required this.compact,
    required this.onOpenMenu,
    required this.onSearch,
    required this.onNewChat,
  });

  final MusorgramController controller;
  final bool compact;
  final VoidCallback onOpenMenu;
  final VoidCallback onSearch;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    final UserSummary? me = controller.me;
    return Material(
      color: palette.header,
      child: SizedBox(
        height: 58,
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Меню',
              onPressed: onOpenMenu,
              splashRadius: 20,
              color: palette.onHeader,
              icon: const Icon(Icons.menu, size: 22),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Musorgram',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.onHeader,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      controller.connected
                          ? (me == null ? 'подключено' : '@${me.username}')
                          : 'нет соединения',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller.connected
                            ? palette.headerMuted
                            : const Color(0xFFFFD0C7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Поиск (Ctrl+K)',
              onPressed: onSearch,
              splashRadius: 20,
              color: palette.onHeader,
              icon: const Icon(Icons.search, size: 21),
            ),
            if (!compact)
              IconButton(
                tooltip: 'Новое сообщение (Ctrl+N)',
                onPressed: onNewChat,
                splashRadius: 20,
                color: palette.onHeader,
                icon: const Icon(Icons.edit_square, size: 20),
              ),
            const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          maxLines: 1,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: colors.onSurface, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: TextStyle(color: colors.onSurfaceVariant),
            prefixIcon: Icon(
              Icons.search,
              size: 17,
              color: colors.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить поиск',
                    padding: EdgeInsets.zero,
                    splashRadius: 15,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            contentPadding: const EdgeInsets.only(right: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatListRow extends StatelessWidget {
  const ChatListRow({
    required this.chat,
    required this.ownUserId,
    required this.baseUrl,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ChatSummary chat;
  final int? ownUserId;
  final String baseUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppPalette palette = context.appPalette;
    final MessageItem? last = chat.lastMessage;
    String preview = last?.previewText ?? 'Нет сообщений';
    final bool own =
        last != null &&
        (last.own || (ownUserId != null && last.senderId == ownUserId));
    if (chat.kind == ChatKind.group && !own) {
      final String sender = last?.senderName?.trim() ?? '';
      if (sender.isNotEmpty) {
        preview = '$sender: $preview';
      }
    } else if (own && preview != 'Нет сообщений') {
      preview = 'Вы: $preview';
    }

    final Color primary = selected ? palette.onHeader : colors.onSurface;
    final Color secondary = selected
        ? palette.onHeader
        : colors.onSurfaceVariant;
    return Material(
      color: selected ? palette.selectedChat : colors.surface,
      child: InkWell(
        onTap: onTap,
        hoverColor: selected
            ? palette.onHeader.withValues(alpha: 0.12)
            : theme.hoverColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: <Widget>[
              AvatarView(
                name: chat.displayName,
                size: 46,
                baseUrl: baseUrl,
                avatarPath: chat.avatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      chat.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatListTime(chat.updatedAt),
                    style: TextStyle(
                      color: selected
                          ? palette.onHeader
                          : colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (chat.unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? palette.onHeader : colors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        chat.unreadCount > 99
                            ? '99+'
                            : chat.unreadCount.toString(),
                        style: TextStyle(
                          color: selected
                              ? palette.selectedChat
                              : colors.onSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
