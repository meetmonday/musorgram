import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/api_client.dart';
import '../data/settings_store.dart';
import '../services/notification_service.dart';
import '../state/musorgram_controller.dart';
import 'group_dialogs.dart';
import 'new_chat_dialog.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'widgets/app_navigation_drawer.dart';
import 'widgets/chat_pane.dart';
import 'widgets/sidebar.dart';

class MusorgramHome extends StatefulWidget {
  const MusorgramHome({
    required this.settings,
    required this.notifications,
    required this.onEditSettings,
    super.key,
  });

  final AppSettings settings;
  final AppNotificationService notifications;
  final VoidCallback onEditSettings;

  @override
  State<MusorgramHome> createState() => _MusorgramHomeState();
}

class _MusorgramHomeState extends State<MusorgramHome>
    with WidgetsBindingObserver {
  late final MusorgramController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _autoOpenScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MusorgramController(
      api: ApiClient(
        baseUrl: widget.settings.baseUrl,
        token: widget.settings.token,
      ),
      notifications: widget.notifications,
    );
    _controller.bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setAppActive(state == AppLifecycleState.resumed);
  }

  void _openSearch() {
    if (_controller.current != null && MediaQuery.sizeOf(context).width < 760) {
      _controller.closeConversation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else {
      _searchFocusNode.requestFocus();
    }
  }

  void _openNewChat() {
    showNewChatDialog(
      context: context,
      controller: _controller,
      baseUrl: widget.settings.baseUrl,
    );
  }

  void _openNewGroup() {
    showCreateGroupDialog(
      context: context,
      controller: _controller,
      baseUrl: widget.settings.baseUrl,
    );
  }

  void _openJoinGroup() {
    showJoinGroupDialog(context: context, controller: _controller);
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProfilePage(user: _controller.me, baseUrl: widget.settings.baseUrl),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          controller: _controller,
          baseUrl: widget.settings.baseUrl,
          onOpenProfile: _openProfile,
          onEditConnection: widget.onEditSettings,
        ),
      ),
    );
  }

  void _scheduleFirstChat(bool wide) {
    if (!wide ||
        _controller.current != null ||
        _controller.chats.isEmpty ||
        _autoOpenScheduled) {
      return;
    }
    _autoOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoOpenScheduled = false;
      if (mounted &&
          _controller.current == null &&
          _controller.chats.isNotEmpty &&
          MediaQuery.sizeOf(context).width >= 760) {
        _controller.openChat(_controller.chats.first);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _openNewChat,
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 760;
              _scheduleFirstChat(wide);
              final bool canPop = wide || _controller.current == null;
              return PopScope<Object?>(
                canPop: canPop,
                onPopInvokedWithResult: (bool didPop, Object? result) {
                  if (!didPop && _controller.current != null) {
                    _controller.closeConversation();
                  }
                },
                child: Scaffold(
                  key: _scaffoldKey,
                  drawer: AppNavigationDrawer(
                    controller: _controller,
                    baseUrl: widget.settings.baseUrl,
                    onNewChat: _openNewChat,
                    onNewGroup: _openNewGroup,
                    onJoinGroup: _openJoinGroup,
                    onOpenProfile: _openProfile,
                    onOpenSettings: _openSettings,
                  ),
                  body: SafeArea(
                    child: Column(
                      children: <Widget>[
                        _ErrorBanner(
                          message: _controller.errorMessage,
                          onClose: _controller.clearError,
                        ),
                        Expanded(
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: wide
                                    ? Row(
                                        children: <Widget>[
                                          SizedBox(
                                            width: 318,
                                            child: _buildSidebar(
                                              compact: false,
                                            ),
                                          ),
                                          Expanded(
                                            child: _controller.current == null
                                                ? const EmptyConversation()
                                                : ChatPane(
                                                    controller: _controller,
                                                    baseUrl:
                                                        widget.settings.baseUrl,
                                                    compact: false,
                                                    onBack: _controller
                                                        .closeConversation,
                                                  ),
                                          ),
                                        ],
                                      )
                                    : (_controller.current == null
                                          ? _buildSidebar(compact: true)
                                          : ChatPane(
                                              controller: _controller,
                                              baseUrl: widget.settings.baseUrl,
                                              compact: true,
                                              onBack:
                                                  _controller.closeConversation,
                                            )),
                              ),
                              if (_controller.initialLoading)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: ColoredBox(
                                      color: context.appPalette.loadingOverlay,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSidebar({required bool compact}) {
    return ChatSidebar(
      controller: _controller,
      baseUrl: widget.settings.baseUrl,
      compact: compact,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      onSearchChanged: (_) => setState(() {}),
      onNewChat: _openNewChat,
      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String? message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              key: ValueKey<String>(message!),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.only(left: 12),
              color: colors.error,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onError, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Скрыть',
                    onPressed: onClose,
                    color: colors.onError,
                    splashRadius: 16,
                    iconSize: 17,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
    );
  }
}
