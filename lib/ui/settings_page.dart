import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/cache_service.dart';
import '../state/musorgram_controller.dart';
import 'widgets/avatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.controller,
    required this.baseUrl,
    required this.onOpenProfile,
    required this.onEditConnection,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;
  final VoidCallback onOpenProfile;
  final VoidCallback onEditConnection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _clearingCache = false;

  Future<void> _clearCache() async {
    if (_clearingCache) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Очистить кэш?'),
        content: const Text(
          'Будут удалены сохранённые аватары и офлайн-копии переписок. '
          'Сообщения на сервере останутся без изменений.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _clearingCache = true);
    await clearApplicationCaches();
    if (!mounted) {
      return;
    }
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Кэш очищен')));
  }

  void _editConnection() {
    Navigator.of(context).pop();
    widget.onEditConnection();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = context.appPalette;
    final user = widget.controller.me;
    final Uri? server = Uri.tryParse(widget.baseUrl);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        toolbarHeight: 58,
        elevation: 0,
        backgroundColor: palette.header,
        foregroundColor: palette.onHeader,
      ),
      body: ListView(
        children: <Widget>[
          InkWell(
            onTap: widget.onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  AvatarView(
                    name: user?.displayName ?? 'Musorgram',
                    size: 64,
                    baseUrl: widget.baseUrl,
                    avatarPath: user?.avatarUrl,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          user?.displayName ?? 'Профиль',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user == null
                              ? 'Данные загружаются'
                              : '@${user.username}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const _SettingsSection('ПОДКЛЮЧЕНИЕ'),
          ListTile(
            leading: Icon(
              widget.controller.connected ? Icons.cloud_done : Icons.cloud_off,
              color: widget.controller.connected
                  ? const Color(0xFF4F9A58)
                  : colors.error,
            ),
            title: Text(
              server?.host.isNotEmpty == true ? server!.host : widget.baseUrl,
            ),
            subtitle: Text(
              widget.controller.connected
                  ? 'Realtime подключён'
                  : 'Realtime переподключается',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Сервер и аккаунт'),
            subtitle: const Text('Сменить сервер или войти другим аккаунтом'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editConnection,
          ),
          const _SettingsSection('УВЕДОМЛЕНИЯ'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Системные уведомления'),
            subtitle: const Text('Запросить разрешение на этом устройстве'),
            onTap: () async {
              await widget.controller.notifications.requestPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Проверьте разрешение в настройках системы'),
                  ),
                );
              }
            },
          ),
          const _SettingsSection('ОФОРМЛЕНИЕ И ДАННЫЕ'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Тема'),
            subtitle: const Text('Как в системе'),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Очистить кэш'),
            subtitle: const Text('Аватары и локальные копии сообщений'),
            trailing: _clearingCache
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _clearingCache ? null : _clearCache,
          ),
          const _SettingsSection('О ПРИЛОЖЕНИИ'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Musorgram'),
            subtitle: Text('Версия 0.1.0 · клиент сообщений MusorBox'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
            child: Text(
              'Вложения, голосовые сообщения и изменение профиля не '
              'поддерживаются публичным API.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
