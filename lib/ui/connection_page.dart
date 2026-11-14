import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/settings_store.dart';
import 'widgets/wallpaper.dart';

class LoginCredentials {
  const LoginCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;

  LoginCredentials normalized() {
    return LoginCredentials(
      baseUrl: baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      username: username.trim(),
      password: password,
    );
  }
}

typedef LoginCallback = Future<String?> Function(LoginCredentials credentials);

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({
    required this.initialSettings,
    required this.canCancel,
    required this.onLogin,
    this.onCancel,
    this.onLogout,
    super.key,
  });

  final AppSettings initialSettings;
  final bool canCancel;
  final LoginCallback onLogin;
  final VoidCallback? onCancel;
  final Future<void> Function()? onLogout;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.initialSettings.baseUrl,
    );
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final String? error = await widget.onLogin(
      LoginCredentials(
        baseUrl: _baseUrlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppPalette palette = context.appPalette;
    return Scaffold(
      body: Wallpaper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Material(
                  color: colors.surface,
                  elevation: 8,
                  shadowColor: colors.shadow.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        color: palette.header,
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                        child: Row(
                          children: <Widget>[
                            const _ConnectionMark(),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Musorgram',
                                    style: TextStyle(
                                      color: palette.onHeader,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Сообщения MusorBox',
                                    style: TextStyle(
                                      color: palette.headerMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Вход',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Используйте логин и пароль от MusorBox. Пароль '
                              'не сохраняется: сервер выдаст отдельный токен '
                              'для этого приложения.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _baseUrlController,
                              enabled: !_submitting,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _usernameFocus.requestFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Адрес MusorBox',
                                hintText: defaultBaseUrl,
                                prefixIcon: Icon(Icons.language, size: 19),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              enabled: !_submitting,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const <String>[
                                AutofillHints.username,
                              ],
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Логин',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: !_submitting,
                              obscureText: _obscurePassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 19,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Показать пароль'
                                      : 'Скрыть пароль',
                                  onPressed: () => setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  }),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: _error == null
                                  ? const SizedBox(height: 20)
                                  : Padding(
                                      key: ValueKey<String>(_error!),
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 42,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                onPressed: _submitting ? null : _submit,
                                child: _submitting
                                    ? SizedBox.square(
                                        dimension: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onPrimary,
                                        ),
                                      )
                                    : const Text(
                                        'ВОЙТИ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            if (widget.canCancel) ...<Widget>[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _submitting ? null : widget.onCancel,
                                child: const Text('Отмена'),
                              ),
                            ],
                            if (widget.onLogout != null) ...<Widget>[
                              const Divider(height: 26),
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => widget.onLogout!(),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.error,
                                ),
                                child: const Text('Выйти из аккаунта'),
                              ),
                            ],
                          ],
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
    );
  }
}

class _ConnectionMark extends StatelessWidget {
  const _ConnectionMark();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: palette.headerDark,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.onHeader.withValues(alpha: 0.34)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/logo_asset.png', fit: BoxFit.cover),
    );
  }
}
