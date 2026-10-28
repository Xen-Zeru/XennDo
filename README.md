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

XennDo is a personal task planner built with Flutter and Material 3 for Android
and iOS.
Organize schoolwork, work projects and everyday activities in one place, with
local reminders and a daily focus list. Core features work offline without an
account or backend service.

## Download XennDo

[![Download Android APK](https://img.shields.io/badge/Download-Android%20APK-007F75?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Xen-Zeru/XennDo/releases/download/v1.0.0-android-testing.1/app-debug.apk) **Testing build — debug-signed, not production-ready.**

[All releases](https://github.com/Xen-Zeru/XennDo/releases)

**iPhone — Coming soon.** iOS distribution is being prepared. iOS source
support is not an installable release.

| Platform | Status |
| --- | --- |
| Android, API 24+ | Builds and automated tests verified on Linux; prior Android emulator checks recorded in the progress document. Physical-device/release qualification remains pending. |
| iOS, 15.0+ | Native project and shared code configured. Dart tests run on Linux with mocked iOS channels/layouts. Xcode compilation, simulator and physical-iPhone verification are pending. |

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

On iOS, the sandbox uses the same database schema. Documents are not exposed
through app file sharing, but iOS/iCloud device backups may include app data
according to the device's backup settings. No iCloud sync capability is enabled.
This differs from the Android backup exclusions above.

You can deliberately export a backup through the system document picker. If you
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

Android and iOS use the same versioned JSON format; native notification IDs are
reassigned on restore. Transfer the exported file yourself, then use Restore on
the destination. Cross-device Android ↔ iPhone picker and reminder behavior still
needs physical-device verification. There is no automatic sync or separate
in-app share button; a saved backup can be shared through Files/document providers.

## Technology

| Area | Implementation |
| --- | --- |
| UI | Flutter, Dart, Material 3 |
| State | Riverpod |
| Navigation | go_router |
| Persistence | Drift and SQLite |
| Reminders | flutter_local_notifications, timezone, flutter_timezone |
| Backup files | file_picker, Android Storage Access Framework and iOS Files picker |
| Package metadata | package_info_plus |
| Record IDs | uuid |

Dependency versions are recorded in [pubspec.yaml](pubspec.yaml) and resolved
in [pubspec.lock](pubspec.lock). Database schema **4** includes migrations from
schemas 1–3; the generated Drift source is kept with the app.

## Getting started

### Prerequisites

- Flutter with Dart **3.13.5 or a compatible 3.x version**. The project is tested
  with **Flutter 3.47.6 / Dart 3.13.5**.
- For Android: Android SDK tools and a compatible JDK. Android sources target Java 17, and the
  included Gradle wrapper selects the project's Gradle version.
- An Android emulator or device. With the tested Flutter SDK, the app's minimum
  API is **24** and its compile/target API is **36**. These SDK levels use
  Flutter-managed defaults.
- For iOS: a Mac with Xcode and its iOS SDK/simulator, CocoaPods for plugin
  fallback integration, and owner-controlled signing for physical devices and
  distribution. iOS cannot be compiled or run on Omarchy Linux.

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

### Android: build and install a development APK

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Use a single connected Android device, or select one with `adb -s`. Launch
**XennDo** from its app icon after installation. Replacement installs retain
private app data when the application ID and signing identity match.

### Android release builds

```bash
flutter build apk --release
```

| Build | Local output | Signing |
| --- | --- | --- |
| Debug | `build/app/outputs/flutter-apk/app-debug.apk` | Development debug key |
| Release | `build/app/outputs/flutter-apk/app-release.apk` | Requires owner-controlled production signing |

Run `python3 tools/setup_android_signing.py` in your own terminal to create or
reuse an owner-controlled production keystore outside the repository and write
ignored `android/key.properties`. Passwords are entered privately, without echo.
Release packaging fails without signing configuration and rejects the standard
debug keystore/alias. It never substitutes the debug key. Debug builds remain
available without release credentials. Artifacts are local build outputs, not
files intended for the source repository.

Owner signing, a signed app bundle, device qualification and store preparation
are documented in the [Android release checklist](docs/RELEASE_CHECKLIST.md).

### iOS: Mac/Xcode verification required

On a Mac, install the same Flutter SDK, configure Xcode and fetch dependencies:

```bash
flutter doctor -v
flutter precache --ios
flutter pub get
flutter build ios --simulator
open ios/Runner.xcworkspace
flutter devices
flutter run -d <ios-device-id>
```

The bundle identifier is **`com.xennzeru.xenndo`** and deployment target is
**iOS 15.0**. No Apple development team or credentials are committed. In Xcode,
select your team for Runner and RunnerTests before a physical-device build.
The project uses Flutter's generated Swift Package Manager integration with a
Podfile for plugins that need CocoaPods. Native integration has not been built
on this Linux machine.

Follow the [iOS setup and release checklist](docs/IOS_SETUP.md) for exact setup,
native tests, notification/backup checks, signing and TestFlight/App Store steps.
No iOS artifact or hosted release is available from this work.

## Project layout

```text
android/          Android host, resources and Gradle wrapper
ios/              iOS host, Xcode workspace, branding and plugin integration
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

## iOS reminders

Permission is requested when enabling a reminder or from Settings, rather than
on first launch. After denial, Settings opens the system notification settings.
Provisional permission permits quiet delivery. Foreground presentation and task
payloads are configured for the same task editor navigation as Android.

iOS can retain at most 64 pending notification requests. XennDo rejects an
additional request with a warning while retaining the saved task and existing
requests. Remove a reminder, or reopen/retry after a delivery frees a slot; there
is no background rolling queue. Focus, Scheduled Summary, notification settings
and OS behavior can delay or silence delivery. Reopen XennDo after a timezone
change to reconcile stored local reminder times. Native behavior remains pending
iPhone verification.

## Documentation

- [Product specification](docs/PRODUCT_SPEC.md)
- [Data model, migrations and backup format](docs/DATA_MODEL.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Progress and verification](docs/PROGRESS.md)
- [Initial-scope implementation audit](docs/PHASE9_AUDIT.md)
- [Privacy statement](docs/PRIVACY.md)
- [Android release checklist](docs/RELEASE_CHECKLIST.md)
- [iOS setup and release checklist](docs/IOS_SETUP.md)
- [Source publication checklist](docs/PUBLICATION_CHECKLIST.md)

## Developer

Developed by **Jan Lester B. Ibañez**.
