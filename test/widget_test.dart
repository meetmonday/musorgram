import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/core/app_theme.dart';
import 'package:musorgram/data/settings_store.dart';
import 'package:musorgram/ui/connection_page.dart';

void main() {
  testWidgets('connection screen submits entered credentials', (
    WidgetTester tester,
  ) async {
    LoginCredentials? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ConnectionPage(
          initialSettings: const AppSettings(
            baseUrl: defaultBaseUrl,
            token: '',
          ),
          canCancel: false,
          onLogin: (LoginCredentials credentials) async {
            submitted = credentials;
            return null;
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Логин'), 'Reader');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'secret');
    await tester.tap(find.text('ВОЙТИ'));
    await tester.pump();

    expect(submitted?.username, 'Reader');
    expect(submitted?.password, 'secret');
    expect(submitted?.baseUrl, defaultBaseUrl);
  });
}
