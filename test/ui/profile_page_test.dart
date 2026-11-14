import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/core/app_theme.dart';
import 'package:musorgram/data/models.dart';
import 'package:musorgram/ui/profile_page.dart';

void main() {
  testWidgets('profile page presents API account data as read only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const ProfilePage(
          user: UserSummary(
            id: 7,
            username: 'Reader',
            fullName: 'Читатель',
            avatarUrl: null,
            lastSeenAt: null,
          ),
          baseUrl: 'https://example.test',
        ),
      ),
    );

    expect(find.text('Читатель'), findsOneWidget);
    expect(find.text('@Reader'), findsOneWidget);
    expect(find.text('example.test'), findsOneWidget);
    expect(find.textContaining('только для просмотра'), findsOneWidget);
  });
}
