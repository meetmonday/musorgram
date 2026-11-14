import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/models.dart';
import '../state/musorgram_controller.dart';
import 'widgets/avatar.dart';

class ChatInfoPage extends StatelessWidget {
  const ChatInfoPage({
    required this.controller,
    required this.baseUrl,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Скопировано')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConversationTarget? target = controller.current;
    if (target == null) {
      return const SizedBox.shrink();
    }
    final bool group = target.address.kind == ChatKind.group;
    final AppPalette palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(
        title: Text(group ? 'Информация о группе' : 'Информация'),
        toolbarHeight: 58,
        elevation: 0,
        backgroundColor: palette.header,
        foregroundColor: palette.onHeader,
      ),
      body: group
          ? _GroupInfo(
              controller: controller,
              baseUrl: baseUrl,
              onCopy: (String value) => _copy(context, value),
            )
          : _DirectInfo(
              target: target,
              baseUrl: baseUrl,
              onCopy: (String value) => _copy(context, value),
            ),
    );
  }
}

class _DirectInfo extends StatelessWidget {
  const _DirectInfo({
    required this.target,
    required this.baseUrl,
    required this.onCopy,
  });

  final ConversationTarget target;
  final String baseUrl;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final UserSummary? user = target.partner;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = context.appPalette;
    final String username = user?.username ?? target.address.stringIdentifier;
    return ListView(
      children: <Widget>[
        ColoredBox(
          color: palette.header,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 27),
            child: Column(
              children: <Widget>[
                AvatarView(
                  name: target.title,
                  size: 96,
                  baseUrl: baseUrl,
                  avatarPath: target.avatarUrl,
                ),
                const SizedBox(height: 14),
                Text(
                  target.title,
                  style: TextStyle(
                    color: palette.onHeader,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastSeenText(username, user?.lastSeenAt),
                  style: TextStyle(color: palette.headerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const _InfoSection('КОНТАКТ'),
        ListTile(
          leading: const Icon(Icons.alternate_email),
          title: Text(username),
          subtitle: const Text('Логин MusorBox'),
          trailing: const Icon(Icons.copy_outlined, size: 18),
          onTap: () => onCopy(username),
        ),
        if (user?.id != null)
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(user!.id.toString()),
            subtitle: const Text('ID пользователя'),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Общие файлы и медиа не отображаются: API сообщений передаёт '
            'только текст.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupInfo extends StatelessWidget {
  const _GroupInfo({
    required this.controller,
    required this.baseUrl,
    required this.onCopy,
  });

  final MusorgramController controller;
  final String baseUrl;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    final String invite = controller.groupInviteUrl ?? '';
    return ListView(
      children: <Widget>[
        ColoredBox(
          color: palette.header,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
            child: Column(
              children: <Widget>[
                AvatarView(
                  name: controller.currentTitle,
                  size: 96,
                  baseUrl: baseUrl,
                ),
                const SizedBox(height: 14),
                Text(
                  controller.currentTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.onHeader,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.currentSubtitle,
                  style: TextStyle(color: palette.headerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (invite.isNotEmpty) ...<Widget>[
          const _InfoSection('ПРИГЛАШЕНИЕ'),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Ссылка-приглашение'),
            subtitle: Text(
              invite,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.copy_outlined, size: 18),
            onTap: () => onCopy(invite),
          ),
        ],
        _InfoSection(
          '${controller.members.length} ${memberWord(controller.members.length)}',
        ),
        for (final UserSummary member in controller.members)
          ListTile(
            leading: AvatarView(
              name: member.displayName,
              size: 42,
              baseUrl: baseUrl,
              avatarPath: member.avatarUrl,
            ),
            title: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text('@${member.username}'),
            trailing: member.id == controller.groupOwnerId
                ? Tooltip(
                    message: 'Владелец группы',
                    child: Icon(
                      Icons.star,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
            onTap: () => onCopy(member.username),
          ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 7),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
