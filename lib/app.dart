import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'data/api_client.dart';
import 'data/settings_store.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'ui/connection_page.dart';
import 'ui/home_page.dart';

class MusorgramApp extends StatefulWidget {
  const MusorgramApp({
    required this.settingsStore,
    required this.notifications,
    super.key,
  });

  final SettingsStore settingsStore;
  final AppNotificationService notifications;

  @override
  State<MusorgramApp> createState() => _MusorgramAppState();
}

class _MusorgramAppState extends State<MusorgramApp> {
  AppSettings? _settings;
  bool _loading = true;
  bool _editingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    AppSettings settings;
    try {
      settings = await widget.settingsStore.load();
    } on Object {
      settings = const AppSettings(baseUrl: defaultBaseUrl, token: '');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<String?> _login(LoginCredentials rawCredentials) async {
    final LoginCredentials credentials = rawCredentials.normalized();
    final Uri? baseUri = Uri.tryParse(credentials.baseUrl);
    if (baseUri == null ||
        !<String>{'http', 'https'}.contains(baseUri.scheme) ||
        baseUri.host.isEmpty) {
      return 'Адрес должен начинаться с https:// или http://';
    }
    if (credentials.username.isEmpty) {
      return 'Введите логин';
    }
    if (credentials.password.isEmpty) {
      return 'Введите пароль';
    }

    final AuthApiClient auth = AuthApiClient(baseUrl: credentials.baseUrl);
    ApiClient? api;
    bool settingsSaved = false;
    try {
      final String token = await auth.login(
        username: credentials.username,
        password: credentials.password,
      );
      final AppSettings settings = AppSettings(
        baseUrl: credentials.baseUrl,
        token: token,
      ).normalized();
      api = ApiClient(baseUrl: settings.baseUrl, token: settings.token);
      await api.getMe();
      await widget.settingsStore.save(settings);
      settingsSaved = true;
      final AppSettings? previous = _settings;
      if (previous != null &&
          previous.isConfigured &&
          (previous.baseUrl != settings.baseUrl ||
              previous.token != settings.token)) {
        final ApiClient previousApi = ApiClient(
          baseUrl: previous.baseUrl,
          token: previous.token,
        );
        try {
          await previousApi.revokeCurrentToken().timeout(
            const Duration(seconds: 5),
          );
        } on Object {
          // The new login is valid even if the old server cannot be reached.
        } finally {
          previousApi.close();
        }
      }
      if (!mounted) {
        return null;
      }
      setState(() {
        _settings = settings;
        _editingSettings = false;
      });
    } on Object catch (error) {
      if (!settingsSaved && api != null) {
        try {
          await api.revokeCurrentToken();
        } on Object {
          // The server also limits old application tokens per account.
        }
      }
      return error.toString();
    } finally {
      api?.close();
      auth.close();
    }
    return null;
  }

  Future<void> _forgetToken() async {
    final AppSettings? settings = _settings;
    if (settings != null && settings.isConfigured) {
      final ApiClient api = ApiClient(
        baseUrl: settings.baseUrl,
        token: settings.token,
      );
      try {
        await api.revokeCurrentToken().timeout(const Duration(seconds: 5));
      } on Object {
        // Signing out locally must also work while the server is unavailable.
      } finally {
        api.close();
      }
    }
    try {
      await widget.settingsStore.clear();
    } on Object {
      // The in-memory session is still cleared if the keyring is unavailable.
    }
    await clearApplicationCaches();
    await widget.notifications.cancelAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = const AppSettings(baseUrl: defaultBaseUrl, token: '');
      _editingSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings? settings = _settings;
    Widget home;
    if (_loading || settings == null) {
      home = const _StartupPage();
    } else if (!settings.isConfigured || _editingSettings) {
      home = ConnectionPage(
        initialSettings: settings,
        canCancel: settings.isConfigured,
        onLogin: _login,
        onCancel: settings.isConfigured
            ? () => setState(() => _editingSettings = false)
            : null,
        onLogout: settings.isConfigured ? _forgetToken : null,
      );
    } else {
      home = MusorgramHome(
        key: ValueKey<String>('${settings.baseUrl}:${settings.token.hashCode}'),
        settings: settings,
        notifications: widget.notifications,
        onEditSettings: () => setState(() => _editingSettings = true),
      );
    }

    return MaterialApp(
      title: 'Musorgram',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ThemeMode.system,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        final bool dark = theme.brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: context.appPalette.headerDark,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: theme.dividerColor,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.header,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _PlaneMark(size: 74),
            const SizedBox(height: 18),
            Text(
              'Musorgram',
              style: TextStyle(
                color: palette.onHeader,
                fontSize: 22,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaneMark extends StatelessWidget {
  const _PlaneMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.headerDark,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: palette.onHeader.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/logo_asset.png', fit: BoxFit.cover),
    );
  }
}
