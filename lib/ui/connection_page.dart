import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/settings_store.dart';
import 'widgets/wallpaper.dart';

typedef ConnectCallback = Future<String?> Function(AppSettings settings);

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({
    required this.initialSettings,
    required this.canCancel,
    required this.onConnect,
    this.onCancel,
    this.onForgetToken,
    super.key,
  });

  final AppSettings initialSettings;
  final bool canCancel;
  final ConnectCallback onConnect;
  final VoidCallback? onCancel;
  final Future<void> Function()? onForgetToken;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;
  final FocusNode _tokenFocus = FocusNode();
  bool _obscureToken = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.initialSettings.baseUrl,
    );
    _tokenController = TextEditingController(
      text: widget.initialSettings.token,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _tokenFocus.dispose();
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
    final String? error = await widget.onConnect(
      AppSettings(
        baseUrl: _baseUrlController.text,
        token: _tokenController.text,
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
                              'Подключение',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Токен можно создать в настройках профиля '
                              'MusorBox. Он хранится в системном защищённом '
                              'хранилище устройства.',
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
                              onSubmitted: (_) => _tokenFocus.requestFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Адрес MusorBox',
                                hintText: defaultBaseUrl,
                                prefixIcon: Icon(Icons.language, size: 19),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _tokenController,
                              focusNode: _tokenFocus,
                              enabled: !_submitting,
                              obscureText: _obscureToken,
                              enableSuggestions: false,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'API-токен',
                                prefixIcon: const Icon(
                                  Icons.key_rounded,
                                  size: 19,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscureToken
                                      ? 'Показать токен'
                                      : 'Скрыть токен',
                                  onPressed: () => setState(() {
                                    _obscureToken = !_obscureToken;
                                  }),
                                  icon: Icon(
                                    _obscureToken
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
                                        'ПОДКЛЮЧИТЬСЯ',
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
                            if (widget.onForgetToken != null) ...<Widget>[
                              const Divider(height: 26),
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => widget.onForgetToken!(),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.error,
                                ),
                                child: const Text('Удалить сохранённый токен'),
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
