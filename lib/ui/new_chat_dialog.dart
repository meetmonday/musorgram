import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import '../state/musorgram_controller.dart';
import 'widgets/avatar.dart';

Future<void> showNewChatDialog({
  required BuildContext context,
  required MusorgramController controller,
  required String baseUrl,
}) async {
  final bool compact = MediaQuery.sizeOf(context).width < 600;
  await showDialog<void>(
    context: context,
    barrierDismissible: !compact,
    builder: (BuildContext dialogContext) {
      final Widget content = NewChatDialog(
        controller: controller,
        baseUrl: baseUrl,
      );
      if (compact) {
        return Dialog.fullscreen(child: content);
      }
      return Dialog(
        insetPadding: const EdgeInsets.all(28),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 430, height: 500, child: content),
      );
    },
  );
}

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({
    required this.controller,
    required this.baseUrl,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  int _searchSerial = 0;
  bool _loading = false;
  List<UserSummary> _users = <UserSummary>[];
  String _hint = 'Начните вводить логин пользователя';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _searchSerial += 1;
    final int serial = _searchSerial;
    final String query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _users = <UserSummary>[];
        _hint = 'Начните вводить логин пользователя';
      });
      return;
    }
    setState(() {
      _loading = true;
      _hint = '';
    });
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final List<UserSummary> users = await widget.controller.searchUsers(
          query,
        );
        if (!mounted || serial != _searchSerial) {
          return;
        }
        setState(() {
          _loading = false;
          _users = users;
          _hint = users.isEmpty ? 'Никого не найдено' : '';
        });
      } on Object catch (error) {
        if (!mounted || serial != _searchSerial) {
          return;
        }
        setState(() {
          _loading = false;
          _users = <UserSummary>[];
          _hint = error.toString();
        });
      }
    });
  }

  void _selectUser(UserSummary user) {
    Navigator.of(context).pop();
    widget.controller.openDirectUser(user);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppPalette palette = context.appPalette;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            ColoredBox(
              color: palette.header,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Новое сообщение',
                        style: TextStyle(
                          color: palette.onHeader,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).pop(),
                      color: palette.onHeader,
                      splashRadius: 19,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Введите имя или логин',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34),
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
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _users.length,
                    itemBuilder: (BuildContext context, int index) {
                      final UserSummary user = _users[index];
                      return Material(
                        color: colors.surface,
                        child: InkWell(
                          onTap: () => _selectUser(user),
                          hoverColor: theme.hoverColor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            child: SizedBox(
                              height: 44,
                              child: Row(
                                children: <Widget>[
                                  AvatarView(
                                    name: user.displayName,
                                    size: 42,
                                    baseUrl: widget.baseUrl,
                                    avatarPath: user.avatarUrl,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          user.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '@${user.username}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_hint.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
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
