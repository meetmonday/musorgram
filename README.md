# Musorgram Flutter

Кроссплатформенный клиент личных и групповых сообщений MusorBox для Android и
Linux. Интерфейс повторяет GTK-клиент: плотный список чатов, синие панели,
светлые пузырьки и фон в стиле Telegram Desktop 2015–2017.

## Возможности

- личные и групповые чаты;
- создание групп и вступление по ссылке-приглашению;
- история с загрузкой предыдущих сообщений;
- локальный кэш профиля, списка чатов и последних сообщений с фоновым
  обновлением после подключения;
- отправка текста с optimistic UI;
- realtime через SSE с автоматическим переподключением;
- локальный поиск по чатам и поиск пользователей MusorBox;
- счётчики непрочитанных и статусы прочтения;
- дисковый кэш аватаров и системные уведомления с переходом в чат;
- адаптивный интерфейс: два столбца на Linux/планшете и отдельные экраны на
  телефоне;
- вход по логину и паролю без сохранения пароля; отдельный токен приложения
  хранится через Android Keystore или Linux Secret
  Service.

## Запуск

```bash
flutter pub get
flutter run -d linux
```

При первом запуске приложение попросит адрес MusorBox, логин и пароль. Пароль
используется только для запроса отдельного токена приложения и не сохраняется.

Для разработки настройки также можно передать через окружение:

```bash
MB_TOKEN='...' MB_BASE_URL='https://nasralbox.randomshit.icu' \
  flutter run -d linux
```

Или в compile-time переменных — это удобно для локальной APK-сборки, но не
следует использовать для распространяемого файла:

```bash
flutter run -d android \
  --dart-define=MB_TOKEN='...' \
  --dart-define=MB_BASE_URL='https://nasralbox.randomshit.icu'
```

## Сборка

На GitHub каждый push и pull request в `main` параллельно запускает
форматирование, анализатор, тесты и release-сборки для Android arm64 и Linux.
Готовые APK и архив Linux bundle можно скачать в разделе **Actions →
Artifacts** соответствующего запуска. Полный Android APK для arm, arm64 и x64
можно собрать ручным запуском workflow **Build** с флажком `full_android`.

Linux:

```bash
flutter build linux --release
```

Результат находится в `build/linux/x64/release/bundle/`.

Android:

```bash
flutter doctor -v
flutter build apk --release
# или для Google Play:
flutter build appbundle --release
```

Минимальная поддерживаемая версия устройства — **Android 10 (API 29)**.
Для Android необходимы SDK Platform 37, актуальные Build Tools и принятые лицензии.

Локально и в CI APK по умолчанию подписывается временным debug-ключом. Для
публикуемой сборки создайте upload keystore, скопируйте
`android/key.properties.example` в `android/key.properties` и заполните четыре
значения. Оба файла с ключами исключены из Git. После этого `flutter build apk
--release` и `flutter build appbundle --release` автоматически используют
release-подпись.

## Проверка

```bash
flutter analyze
flutter test
```

## Уведомления Android

Realtime SSE работает, пока процесс приложения активен. Android может
приостановить сетевое соединение после сворачивания, поэтому гарантированные
уведомления при полностью закрытом приложении потребуют серверной отправки через
Firebase Cloud Messaging. Пока приложение запущено, входящие сообщения
показываются через локальные системные уведомления.
