# AGENTS.md

## Scope and sources

- This is the standalone Flutter messaging client for Android and Linux, not the MusorBox backend. Forum/topics/comments from `API.md` are out of scope; user-facing text is Russian.
- For UI or feature work, read `IMPLEMENTATION_PLAN.md` and `reference.jpg`; the compact 2015–2017 Telegram look and the 760 px mobile/two-column breakpoint are intentional. Do not add active UI for operations absent from `API.md`.
- Treat `API.md` as the checked-in wire contract for `/api/messages...`; Bearer tokens belong only in the `Authorization` header, never URLs, logs, fixtures, or commits.

## Commands

- Setup/run: `flutter pub get`, then `MB_TOKEN='...' MB_BASE_URL='https://...' flutter run -d linux`.
- Verify in order: `dart format lib test`, `flutter analyze`, `flutter test`.
- Focus a file with `flutter test test/data/api_client_test.dart`; focus a case with `flutter test test/data/api_client_test.dart --plain-name 'creates a group'`.
- Tests are local unit/widget tests and require no running MusorBox server. Inject `http.Client`, cache roots, and notification abstractions rather than making live requests.
- `analysis_options.yaml` excludes `android/**` and `linux/**`; after platform changes, build that target rather than relying on `flutter analyze`.

## Execution flow

- `lib/main.dart` initializes optional native notifications; `lib/app.dart` loads/validates secure connection settings; `lib/ui/home_page.dart` owns one `MusorgramController`; the controller coordinates API calls, cache-first startup, selected-chat state, SSE, refreshes, and notifications.
- Keep wire parsing and chat identity types in `lib/data/models.dart`; HTTP and SSE transport live in `lib/data/api_client.dart`; shared asynchronous state belongs in `lib/state/musorgram_controller.dart`, not duplicated in widgets.
- Preserve the controller's stale-response guards (`_chatGeneration`) and serialized/coalesced chat refreshes when changing async flows.

## Runtime invariants

- SSE events are signals, not message payloads: after `message`, `read`, initial `ready`, or reconnect, fetch the relevant `updates?after=...` data. Reconnects must recover missed events.
- Stored secure settings override `--dart-define`, which overrides process `MB_TOKEN`/`MB_BASE_URL`, which overrides the default URL. Clear stored settings when an environment override appears ignored.
- Cache and notification failures are deliberately best-effort so missing Linux keyrings/notification daemons or corrupt caches do not block startup or messaging. Signing out clears secure settings, JSON/media caches, and notifications.
- Android supports API 30+ and `android/app/build.gradle.kts` currently signs release builds with the debug key; a release artifact is not publication-ready until a release keystore is configured.
