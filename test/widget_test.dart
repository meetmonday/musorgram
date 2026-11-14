import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/core/app_theme.dart';
import 'package:musorgram/data/settings_store.dart';
import 'package:musorgram/ui/connection_page.dart';

void main() {
  testWidgets('connection screen submits entered token', (
    WidgetTester tester,
  ) async {
    AppSettings? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ConnectionPage(
          initialSettings: const AppSettings(
            baseUrl: defaultBaseUrl,
            token: '',
          ),
          canCancel: false,
          onConnect: (AppSettings settings) async {
            submitted = settings;
            return null;
          },
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'API-токен'),
      'test-token',
    );
    await tester.tap(find.text('ПОДКЛЮЧИТЬСЯ'));
    await tester.pump();

    expect(submitted?.token, 'test-token');
    expect(submitted?.baseUrl, defaultBaseUrl);
  });
}
