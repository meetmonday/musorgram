import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import '../state/musorgram_controller.dart';
import 'widgets/avatar.dart';

Future<void> showCreateGroupDialog({
  required BuildContext context,
  required MusorgramController controller,
  required String baseUrl,
}) async {
  final bool compact = MediaQuery.sizeOf(context).width < 600;
  await showDialog<void>(
    context: context,
    barrierDismissible: !compact,
    builder: (BuildContext dialogContext) {
      final Widget content = CreateGroupDialog(
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
        child: SizedBox(width: 450, height: 610, child: content),
      );
    },
  );
}

Future<void> showJoinGroupDialog({
  required BuildContext context,
  required MusorgramController controller,
}) async {
  final TextEditingController inviteController = TextEditingController();
  bool submitting = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        Future<void> submit() async {
          if (submitting) {
            return;
          }
          setState(() {
            submitting = true;
            error = null;
          });
          final bool joined = await controller.joinGroup(inviteController.text);
          if (!context.mounted) {
            return;
          }
          if (joined) {
            Navigator.of(context).pop();
            return;
          }
          setState(() {
            submitting = false;
            error = controller.errorMessage ?? 'Не удалось вступить в группу';
          });
        }

        final ColorScheme colors = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Вступить в группу'),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Вставьте ссылку вида …/messages/groups/join/… '
                  'или только токен приглашения.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: inviteController,
                  autofocus: true,
                  enabled: !submitting,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'Ссылка или токен',
                    prefixIcon: Icon(Icons.link, size: 19),
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Вступить'),
            ),
          ],
        );
      },
    ),
  );
  inviteController.dispose();
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({
    required this.controller,
    required this.baseUrl,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final Map<String, UserSummary> _selected = <String, UserSummary>{};
  Timer? _debounce;
  int _searchSerial = 0;
  bool _searching = false;
  bool _submitting = false;
  String? _error;
  List<UserSummary> _results = <UserSummary>[];

  bool get _validTitle {
    final int length = _titleController.text.trim().runes.length;
    return length >= 2 && length <= 80;
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
      }
    });
  }

  void _onTitleChanged() => setState(() {});

  void _search(String rawQuery) {
    _debounce?.cancel();
    _searchSerial += 1;
    final int serial = _searchSerial;
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _results = <UserSummary>[];
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final List<UserSummary> users = await widget.controller.searchUsers(
          query,
        );
        if (!mounted || serial != _searchSerial) {
          return;
        }
        setState(() {
          _searching = false;
          _results = users
              .where(
                (UserSummary user) =>
                    !_selected.containsKey(user.username) &&
                    user.id != widget.controller.me?.id,
              )
              .toList(growable: false);
        });
      } on Object catch (caught) {
        if (!mounted || serial != _searchSerial) {
          return;
        }
        setState(() {
          _searching = false;
          _results = <UserSummary>[];
          _error = caught.toString();
        });
      }
    });
  }

  void _add(UserSummary user) {
    if (_selected.length >= 49) {
      setState(() => _error = 'В группе может быть не более 50 участников');
      return;
    }
    setState(() {
      _selected[user.username] = user;
      _results.removeWhere(
        (UserSummary result) => result.username == user.username,
      );
      _error = null;
    });
  }

  Future<void> _create() async {
    if (!_validTitle || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final bool created = await widget.controller.createGroup(
      _titleController.text,
      _selected.values.toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (created) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = widget.controller.errorMessage ?? 'Не удалось создать группу';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    _searchController.dispose();
    _titleFocus.dispose();
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
                height: 54,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      color: palette.onHeader,
                      icon: const Icon(Icons.arrow_back, size: 21),
                    ),
                    Expanded(
                      child: Text(
                        'Новая группа',
                        style: TextStyle(
                          color: palette.onHeader,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _validTitle && !_submitting ? _create : null,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.onHeader,
                        disabledForegroundColor: palette.headerMuted.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      child: const Text(
                        'СОЗДАТЬ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                enabled: !_submitting,
                maxLength: 80,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(80),
                ],
                decoration: const InputDecoration(
                  labelText: 'Название группы',
                  prefixIcon: Icon(Icons.group_outlined, size: 20),
                  counterText: '',
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (BuildContext context, int index) {
                    final UserSummary user = _selected.values.elementAt(index);
                    return InputChip(
                      avatar: AvatarView(
                        name: user.displayName,
                        size: 24,
                        baseUrl: widget.baseUrl,
                        avatarPath: user.avatarUrl,
                      ),
                      label: Text(user.displayName),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() {
                              _selected.remove(user.username);
                            }),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                enabled: !_submitting,
                decoration: InputDecoration(
                  hintText: 'Добавить участников по логину',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ),
              ),
            Expanded(
              child: _results.isEmpty && !_searching
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'Группу можно создать без участников, а затем '
                                    'поделиться ссылкой-приглашением.'
                              : 'Пользователи не найдены',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      itemExtent: 58,
                      itemBuilder: (BuildContext context, int index) {
                        final UserSummary user = _results[index];
                        return ListTile(
                          leading: AvatarView(
                            name: user.displayName,
                            size: 40,
                            baseUrl: widget.baseUrl,
                            avatarPath: user.avatarUrl,
                          ),
                          title: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '@${user.username}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.add, size: 20),
                          onTap: () => _add(user),
                        );
                      },
                    ),
            ),
            if (_submitting) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
