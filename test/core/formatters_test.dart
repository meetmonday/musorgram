import 'package:flutter_test/flutter_test.dart';
import 'package:musorgram/core/formatters.dart';

void main() {
  group('formatters', () {
    test('builds initials like the GTK client', () {
      expect(initials('Иван Петров'), 'ИП');
      expect(initials('reader_name'), 'RN');
      expect(initials('A'), 'A');
      expect(initials(''), '?');
    });

    test('uses stable avatar colors', () {
      expect(colorIndex('Reader'), colorIndex('Reader'));
      expect(colorIndex('Reader'), inInclusiveRange(0, 7));
    });

    test('chooses Russian member word', () {
      expect(memberWord(1), 'участник');
      expect(memberWord(2), 'участника');
      expect(memberWord(5), 'участников');
      expect(memberWord(11), 'участников');
      expect(memberWord(21), 'участник');
    });

    test('resolves relative media URL', () {
      expect(
        resolveMediaUrl('https://example.test', '/uploads/a.png'),
        'https://example.test/uploads/a.png',
      );
    });
  });
}
