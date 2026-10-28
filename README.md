<div align="center">
  <h1>XennDo</h1>
  <p><strong>Plan your day. Get it done.</strong></p>
  <p><a href="https://github.com/Xen-Zeru/XennDo">GitHub repository</a></p>
  <p>
    <img alt="Flutter 3.47.6" src="https://img.shields.io/badge/Flutter-3.47.6-02569B?logo=flutter&amp;logoColor=white">
    <img alt="Dart 3.13.5" src="https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart&amp;logoColor=white">
    <img alt="Android API 24 and above" src="https://img.shields.io/badge/Android-API%2024%2B-3DDC84?logo=android&amp;logoColor=white">
    <img alt="Offline support" src="https://img.shields.io/badge/Offline-supported-007F75">
  </p>
</div>

XennDo is a personal task planner for Android, built with Flutter and Material 3.
Organize schoolwork, work projects and everyday activities in one place, with
local reminders and a daily focus list. Core features work offline without an
account or backend service.

## Download XennDo

[![Download Android APK](https://img.shields.io/badge/Download-Android%20APK-007F75?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Xen-Zeru/XennDo/releases/download/v1.0.0-android-testing.1/app-debug.apk) **Testing build — debug-signed, not production-ready.**

[All releases](https://github.com/Xen-Zeru/XennDo/releases)

**iPhone — Coming soon.** iOS distribution is being prepared. iOS source
support is not an installable release.

## Features

- **Today:** review overdue work, today's deadlines and completed tasks. Focus
  tasks appear once, with clear overdue labels.
- **Upcoming:** browse future tasks grouped by local date. The date strip and
  date picker scroll to a group while keeping other dates available.
- **Tasks and lists:** create custom lists, set priorities, add notes and optional
  due dates/times, and reorder work. Deleting a list moves its tasks to Inbox.
- **Subtasks:** break work into smaller steps, reorder them and track completion
  independently of the parent task.
- **Search and filters:** search titles and notes, combining list, priority,
  completion status and due-date-range filters.
- **Progress and history:** review completions by local day, reopen tasks, and
  see due-today progress and seven-day completion counts.
- **Local reminders:** set one-time notifications, edit or remove them, and open
  the associated task from a notification.
- **Appearance:** choose System, Light or Dark, with a preference saved locally.
- **About:** view installed version/build information, developer credit and
  Flutter's open-source license page.

### My Top 3

Choose up to **three active focus tasks** for each local day. You can remove or
reorder selections using drag handles or move actions. Completed selections
stay visible for that day and free an active slot.

If three other active selections exist when you reopen a completed focus task,
it reopens in its list and leaves the focus selection. Deletion Undo also
respects the three-active-task limit.

### Progress that reflects your tasks

Daily due-task progress measures completed tasks whose due date is **today**.
It includes timed tasks already overdue today, but excludes tasks with an
earlier due date. An empty day displays **No tasks due**.

History and completion counts use each task's latest completion timestamp.
Reopening a task clears that timestamp; this is not an immutable event log.

## Offline storage and privacy

Tasks, lists, subtasks, focus selections and preferences are stored in the app's
private local SQLite database. The app has no account system, cloud sync,
advertising, analytics or crash-reporting SDK. It does not add its own database
encryption layer.

The Android release manifest does not request Internet permission. Debug and
profile builds include Flutter's development networking permission. Automatic
Android app backup and device transfer are disabled by the manifest and backup
rules.

You can deliberately export a backup through Android's document picker. If you
choose a cloud-backed document provider, that provider handles the selected
file under its own policies. Task titles and notes can also appear in Android
notifications, subject to your notification and lock-screen settings.

See the [privacy statement](docs/PRIVACY.md) for details.

## Backup and restore

In **Settings → Data**, export a backup or select a file to restore.

- Exports contain lists, tasks, subtasks, completion data, reminder definitions,
  focus selections and appearance settings.
- Backups are readable JSON and **are not encrypted**. Store them privately.
- Restore validates the file, shows a preview, and asks for confirmation before
  **replacing all destination data**. There is no merge mode.
- Replacement is transactional: a failed database restore rolls back its changes.
- This version exports backup format **2** and also reads format **1**.
  Eligible future reminders are reconciled after restore; permission is required
  for notification delivery.

Export before uninstalling or replacing an installation. The final application
ID is **`com.xennzeru.xenndo`**. An older `com.example.xenndo` installation has
separate private storage; changing IDs does not transfer its data automatically.
Use an explicit backup/restore and retain the old installation until verified.

## Technology

| Area | Implementation |
| --- | --- |
| UI | Flutter, Dart, Material 3 |
| State | Riverpod |
| Navigation | go_router |
| Persistence | Drift and SQLite |
| Reminders | flutter_local_notifications, timezone, flutter_timezone |
| Backup files | file_picker and Android's Storage Access Framework |
| Package metadata | package_info_plus |
| Record IDs | uuid |

Dependency versions are recorded in [pubspec.yaml](pubspec.yaml) and resolved
in [pubspec.lock](pubspec.lock). Database schema **4** includes migrations from
schemas 1–3; the generated Drift source is kept with the app.

## Getting started

### Prerequisites

- Flutter with Dart **3.13.5 or a compatible 3.x version**. The project is tested
  with **Flutter 3.47.6 / Dart 3.13.5**.
- Android SDK tools and a compatible JDK. Android sources target Java 17, and the
  included Gradle wrapper selects the project's Gradle version.
- An Android emulator or device. With the tested Flutter SDK, the app's minimum
  API is **24** and its compile/target API is **36**. These SDK levels use
  Flutter-managed defaults.

Add Flutter and Android platform-tools to your shell's `PATH`, then clone the
project using SSH:

```bash
git clone git@github.com:Xen-Zeru/XennDo.git
cd XennDo
```

You can also clone from [HTTPS](https://github.com/Xen-Zeru/XennDo.git).
From the project root, check your setup and fetch the locked dependencies:

```bash
flutter doctor -v
flutter pub get
```

SDK and dependency setup may need an Internet connection; using the app does not.
Android SDK paths belong in local, ignored configuration, not source control.

### Run

```bash
flutter devices
flutter run
```

Flutter will use or prompt for an available device. To regenerate Drift code
after changing the database tables:

```bash
dart run build_runner build
```

### Format, analyze and test

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Use `dart format .` to apply formatting. The tests cover repository behavior,
migrations, backup validation, reminders, navigation, task interactions and
responsive layouts, including large text. Automated tests do not establish
physical-device notification timing or accessibility qualification.

If your system temporary directory is constrained, you can put test scratch
files in an ignored local directory before running the commands:

```bash
mkdir -p .dart_tool/tmp
export TMPDIR="$PWD/.dart_tool/tmp"
```

### Build and install a development APK

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Use a single connected Android device, or select one with `adb -s`. Launch
**XennDo** from its app icon after installation. Replacement installs retain
private app data when the application ID and signing identity match.

### Release builds

```bash
flutter build apk --release
```

| Build | Local output | Signing |
| --- | --- | --- |
| Debug | `build/app/outputs/flutter-apk/app-debug.apk` | Development debug key |
| Release | `build/app/outputs/flutter-apk/app-release.apk` | Unsigned unless owner signing is configured |

Without local `android/key.properties`, the release build produces an
**unsigned APK**. It is not installable or ready for distribution. The build
never substitutes the debug key for release signing. Artifacts are local build
outputs, not files intended for the source repository.

Owner signing, a signed app bundle, device qualification and store preparation
are documented in the [Android release checklist](docs/RELEASE_CHECKLIST.md).

## Project layout

```text
android/          Android host, resources and Gradle wrapper
lib/
  app/            Navigation, app shell and lifecycle handling
  core/           Database, migrations, time helpers and shared UI
  features/       Task planning, search, reminders, progress, settings and backup
test/            Repository, migration and widget tests
docs/            Product, data model, verification and release guidance
tools/           Optional development and emulator helper
```

## Android reminder permissions

- **POST_NOTIFICATIONS:** requested in context on Android versions that require
  runtime notification permission. Denial leaves task management available.
- **RECEIVE_BOOT_COMPLETED:** lets the notification plugin restore scheduled
  reminders after a reboot.
- **SCHEDULE_EXACT_ALARM:** permits exact scheduling where Android grants access.
  Otherwise the app uses inexact delivery.

Android battery restrictions, Doze, manufacturer behavior and special-access
settings can delay delivery. Exact delivery is not guaranteed. Settings shows
notification permission status and offers an appropriate request or system
settings action. Completing or deleting a task cancels its reminder; past
reminder definitions are not rescheduled.

The backup picker uses scoped file access and does not request broad storage
permission. AndroidX's internal receiver permission and notification vibration
permission may also appear in the merged manifest.

## Documentation

- [Product specification](docs/PRODUCT_SPEC.md)
- [Data model, migrations and backup format](docs/DATA_MODEL.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Progress and verification](docs/PROGRESS.md)
- [Initial-scope implementation audit](docs/PHASE9_AUDIT.md)
- [Privacy statement](docs/PRIVACY.md)
- [Android release checklist](docs/RELEASE_CHECKLIST.md)
- [Source publication checklist](docs/PUBLICATION_CHECKLIST.md)

## Developer

Developed by **Jan Lester B. Ibañez**.
