import 'dart:convert';

import 'package:crypto/crypto.dart';

DateTime? parseApiDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

String formatClock(String? value) {
  final DateTime? date = parseApiDate(value);
  if (date == null) {
    return '';
  }
  return '${_two(date.hour)}:${_two(date.minute)}';
}

String formatListTime(String? value, {DateTime? now}) {
  final DateTime? date = parseApiDate(value);
  if (date == null) {
    return '';
  }
  final DateTime localNow = (now ?? DateTime.now()).toLocal();
  if (_sameDate(date, localNow)) {
    return formatClock(value);
  }
  if (_sameDate(date, localNow.subtract(const Duration(days: 1)))) {
    return 'вчера';
  }
  if (date.year == localNow.year) {
    return '${_two(date.day)}.${_two(date.month)}';
  }
  return '${_two(date.day)}.${_two(date.month)}.${_two(date.year % 100)}';
}

String formatDay(String? value, {DateTime? now}) {
  final DateTime? date = parseApiDate(value);
  if (date == null) {
    return '';
  }
  final DateTime localNow = (now ?? DateTime.now()).toLocal();
  if (_sameDate(date, localNow)) {
    return 'Сегодня';
  }
  if (_sameDate(date, localNow.subtract(const Duration(days: 1)))) {
    return 'Вчера';
  }
  const List<String> months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final String year = date.year == localNow.year ? '' : ' ${date.year}';
  return '${date.day} ${months[date.month - 1]}$year';
}

String lastSeenText(String username, String? value, {DateTime? now}) {
  final DateTime? seen = parseApiDate(value);
  if (seen == null) {
    return username.isEmpty ? '' : '@$username';
  }
  final DateTime localNow = (now ?? DateTime.now()).toLocal();
  final Duration age = localNow.difference(seen);
  if (!age.isNegative && age < const Duration(minutes: 3)) {
    return 'в сети';
  }
  final String clock = '${_two(seen.hour)}:${_two(seen.minute)}';
  if (_sameDate(seen, localNow)) {
    return 'был(а) в сети в $clock';
  }
  if (_sameDate(seen, localNow.subtract(const Duration(days: 1)))) {
    return 'был(а) в сети вчера в $clock';
  }
  return 'был(а) в сети ${_two(seen.day)}.${_two(seen.month)}.${seen.year}';
}

String memberWord(int count) {
  if (count % 10 == 1 && count % 100 != 11) {
    return 'участник';
  }
  if (<int>{2, 3, 4}.contains(count % 10) &&
      !<int>{12, 13, 14}.contains(count % 100)) {
    return 'участника';
  }
  return 'участников';
}

String initials(String name) {
  final String clean = name.replaceAll('_', ' ').trim();
  final List<String> parts = clean
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (clean.isEmpty) {
    return '?';
  }
  return clean.substring(0, clean.length.clamp(0, 2)).toUpperCase();
}

int colorIndex(String value) {
  return sha1.convert(utf8.encode(value)).bytes.first % 8;
}

String resolveMediaUrl(String baseUrl, String? path) {
  if (path == null || path.trim().isEmpty) {
    return '';
  }
  final Uri? base = Uri.tryParse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
  final Uri? relative = Uri.tryParse(path);
  if (base == null || relative == null) {
    return '';
  }
  return base.resolveUri(relative).toString();
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _two(int value) => value.toString().padLeft(2, '0');
