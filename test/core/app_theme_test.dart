import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/core/app_theme.dart';

void main() {
  test('light and dark themes expose matching palettes', () {
    final ThemeData light = buildAppTheme();
    final ThemeData dark = buildDarkAppTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<AppPalette>(), AppPalette.light);
    expect(dark.extension<AppPalette>(), AppPalette.dark);
    expect(dark.colorScheme.surface, isNot(light.colorScheme.surface));
    expect(
      AppPalette.dark.outgoingMessage,
      isNot(AppPalette.dark.incomingMessage),
    );
  });

  testWidgets('system theme follows platform brightness', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildDarkAppTheme(),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (BuildContext context) => ColoredBox(
            key: const ValueKey<String>('themed-surface'),
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );

    ColoredBox surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('themed-surface')),
    );
    expect(surface.color, buildDarkAppTheme().colorScheme.surface);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();

    surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('themed-surface')),
    );
    expect(surface.color, buildAppTheme().colorScheme.surface);
  });
}
