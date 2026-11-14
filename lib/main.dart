import 'package:flutter/material.dart';

import 'app.dart';
import 'data/settings_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalNotificationService notifications = LocalNotificationService();
  await notifications.initialize();
  runApp(
    MusorgramApp(settingsStore: SettingsStore(), notifications: notifications),
  );
}
