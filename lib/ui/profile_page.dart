import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import 'widgets/avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.user, required this.baseUrl, super.key});

  final UserSummary? user;
  final String baseUrl;

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label скопирован')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserSummary? profile = user;
    final String username = profile?.username ?? '';
    final String name = profile?.displayName ?? 'Профиль';
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = context.appPalette;
    final Uri? server = Uri.tryParse(baseUrl);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        toolbarHeight: 58,
        elevation: 0,
        backgroundColor: palette.header,
        foregroundColor: palette.onHeader,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ColoredBox(
            color: palette.header,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              child: Column(
                children: <Widget>[
                  AvatarView(
                    name: name,
                    size: 96,
                    baseUrl: baseUrl,
                    avatarPath: profile?.avatarUrl,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.onHeader,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (username.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: palette.headerMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const _SectionLabel('УЧЁТНАЯ ЗАПИСЬ'),
          if (username.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.alternate_email, size: 21),
              title: const Text('Логин'),
              subtitle: Text(username),
              trailing: const Icon(Icons.copy_outlined, size: 18),
              onTap: () => _copy(context, username, 'Логин'),
            ),
          if (profile?.id != null)
            ListTile(
              leading: const Icon(Icons.badge_outlined, size: 21),
              title: const Text('ID пользователя'),
              subtitle: Text(profile!.id.toString()),
              trailing: const Icon(Icons.copy_outlined, size: 18),
              onTap: () =>
                  _copy(context, profile.id.toString(), 'ID пользователя'),
            ),
          ListTile(
            leading: const Icon(Icons.dns_outlined, size: 21),
            title: const Text('Сервер MusorBox'),
            subtitle: Text(
              server?.host.isNotEmpty == true ? server!.host : baseUrl,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Профиль доступен только для просмотра: публичное API '
                    'MusorBox пока не позволяет менять имя или аватар.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 7),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
