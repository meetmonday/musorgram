import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../state/musorgram_controller.dart';
import 'avatar.dart';
import 'wallpaper.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    required this.controller,
    required this.baseUrl,
    required this.onNewChat,
    required this.onNewGroup,
    required this.onJoinGroup,
    required this.onOpenProfile,
    required this.onOpenSettings,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;
  final VoidCallback onNewChat;
  final VoidCallback onNewGroup;
  final VoidCallback onJoinGroup;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  void _runAfterClose(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = context.appPalette;
    final UserSummary? me = controller.me;
    final String name = me?.displayName ?? 'Musorgram';
    return Drawer(
      width: 300,
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Material(
              color: palette.headerDark,
              child: InkWell(
                onTap: () => _runAfterClose(context, onOpenProfile),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Wallpaper(
                    child: ColoredBox(
                      color: palette.header.withValues(alpha: 0.88),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AvatarView(
                              name: name,
                              size: 64,
                              baseUrl: baseUrl,
                              avatarPath: me?.avatarUrl,
                            ),
                            const Spacer(),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.onHeader,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              me == null
                                  ? 'Подключение к MusorBox'
                                  : '@${me.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.headerMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _DrawerItem(
              icon: Icons.edit_outlined,
              label: 'Новое сообщение',
              onTap: () => _runAfterClose(context, onNewChat),
            ),
            _DrawerItem(
              icon: Icons.group_add_outlined,
              label: 'Новая группа',
              onTap: () => _runAfterClose(context, onNewGroup),
            ),
            _DrawerItem(
              icon: Icons.link,
              label: 'Вступить в группу',
              onTap: () => _runAfterClose(context, onJoinGroup),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Настройки',
              onTap: () => _runAfterClose(context, onOpenSettings),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'API MusorBox поддерживает только текстовые сообщения.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 49,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: Icon(icon, size: 21, color: colors.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
