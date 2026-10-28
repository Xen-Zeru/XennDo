# iOS setup, audit and release checklist

Updated 2026-10-28. iOS source integration is configured; **no iOS build,
simulator run, native XCTest or physical-iPhone test has run on this Linux host**.
Android remains the platform with build/emulator evidence. Nothing is published
by this extension, and no Apple team, certificate or provisioning profile is
created or committed.

## Project configuration

- Flutter-generated Swift host with UIScene/implicit-engine plugin registration.
- App bundle identifier: `com.xennzeru.xenndo`; display name: **XennDo**.
- Test bundle: `com.xennzeru.xenndo.RunnerTests`.
- Deployment target: **iOS 15.0**, matching this Flutter SDK's generated project.
- Version/build come from `pubspec.yaml` (`1.0.0+1`) through Flutter build settings.
- No development team selected. The owner must register/confirm the identifier
  in their Apple account and choose signing in Xcode.
- Calendar/check app icons derive from the existing Android vector design; SVG
  source is in `ios/Branding/`. Native launch background has light/dark variants.
- Flutter's Swift Package Manager project integration is retained. The Podfile
  and optional Pods xcconfig includes support plugins that require CocoaPods.
  The resulting native dependency graph still needs resolution on a Mac.
- No push service, APNs entitlement, background-fetch mode, iCloud sync,
  photo-library, camera, contacts or broad file-access permission is added.
  Notification authorization is requested through UserNotifications, not a
  fabricated Info.plist usage-description key.

## Locked dependency audit

No new dependency or lockfile change is required. This is a source/API audit of
resolved packages, **not** native compilation or an exhaustive security review.

| Area | Resolved implementation and finding |
| --- | --- |
| UI, Riverpod, go_router, uuid | Shared Flutter/Dart; no Android-only implementation in the task/list/search/progress flows. |
| Drift 2.35.2 / drift_flutter 0.3.1 | Native SQLite support on iOS; same `xenndo.sqlite` in the sandbox's application Documents directory. Android path/schema stay unchanged. |
| sqlite3 3.5.2 | Locked native SQLite library/build-hook implementation includes iOS device and simulator targets; artifact resolution/linking needs Xcode validation. |
| flutter_local_notifications 22.3.2 | iOS implementation and Darwin settings, permission queries, scheduling, cancellation, launch payloads and system Settings API inspected. |
| timezone 0.11.2 / flutter_timezone 5.1.1 | iOS device-zone lookup exists. Dart converts local reminder fields to an instant; OS requests use UTC. Resume reconciliation refreshes local zone and deadlines. |
| file_picker 13.2.0 / file_picker_darwin 2.3.4 | iOS UIDocumentPicker exports supplied JSON bytes with `forExporting:asCopy:` and imports scoped copies. No separate share plugin is required. The Darwin implementation requires iOS 14+, below this project's 15.0 floor. |
| package_info_plus 10.2.2 | iOS bundle metadata supported; Settings/About remain automatic. |
| path_provider_foundation 2.6.0 | Transitive sandbox path provider for native storage; no absolute device path stored in backups. |

Package-specific privacy manifests remain supplied by their native packages.
Review Xcode's aggregated privacy report, required-reason APIs and the final
archive's dependencies before making App Privacy declarations; a Dart audit
cannot certify the resulting archive.

## Notifications and limits

- App launch initializes Darwin notification support without requesting alert,
  sound or badge authorization. Ask when enabling a reminder or using Settings.
- Native `UNAuthorizationStatus.notDetermined` distinguishes a requestable state
  from denial; denied users go to system Settings. Provisional authorization
  allows quiet delivery. Badges and critical-alert authorization are not requested.
- AppDelegate forwards notification events through Flutter's delegate/plugin
  registration. Warm taps and launch payloads feed the existing task editor router.
  No notification action runs a new background task or bypasses the editor guard.
- Completing/deleting a task, removing its reminder and editing its time continue
  through the same serialized cancellation/scheduling boundary as Android.
- The plugin documents a **64-pending-request limit** on iOS. Before adding a new
  request, XennDo checks the pending set and refuses overflow. A visible warning
  preserves the task and reminder definition without evicting an existing request.
  This is not an unlimited rolling background queue or earliest-64 prioritization.
  Remove a reminder or reopen/retry after a delivery frees a slot. Restore may
  succeed with a reminder warning when more requests exist than iOS can retain.
- Focus, Scheduled Summary, authorization/sound settings and OS policy can delay
  or silence delivery. No exact delivery guarantee or Android exact-alarm control
  is presented on iOS.
- After timezone/DST changes, reopen the app to reconcile stored local times.
  A request already scheduled while the app is suspended retains its prior UTC
  instant until the app can reconcile. No background refresh entitlement is added.

## Data, backup and privacy

Schema **4** and backup format **2** remain unchanged; format **1** is still read.
JSON contains portable local dates, UTC timestamps and task/list IDs, not source
platform paths or native notification IDs. Restore remains validated and
transactional replace-all, with fresh local notification IDs and permission-aware
reconciliation. No live Android database is moved, reset or re-created.

Export uses Files/document providers; import reads the selected document copy.
The same plain-text privacy disclosure and replace-all confirmation apply on both
platforms. Provider cancellation/failure goes through the existing backup error
handling. A cloud provider may require connectivity; app-owned task storage works
offline. Sharing a saved file can happen through Files/provider UI; there is no
new in-app share action or automatic device-to-device transfer.

`UIFileSharingEnabled` is not enabled, so the Documents folder containing the
SQLite database is not exposed through app file sharing. iOS device/iCloud
backups may still contain sandbox data under the owner's device settings. This
is distinct from Android's existing automatic-backup exclusions. No database
or exported JSON encryption is added. Review [PRIVACY.md](PRIVACY.md).

## Exact Mac setup and development checks

1. Install Xcode and a compatible iOS SDK/simulator on macOS, plus the same Flutter
   SDK used here (3.47.6 / Dart 3.13.5) and a working CocoaPods installation.
   Complete Xcode's first-launch setup. If needed:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   xcodebuild -version
   pod --version
   flutter doctor -v
   ```

2. From the project root, resolve the locked packages and prepare the simulator
   build. Flutter prepares generated Swift packages and any required Pods:

   ```bash
   flutter precache --ios
   flutter pub get
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   flutter build ios --simulator
   open ios/Runner.xcworkspace
   ```

   If Flutter reports a CocoaPods integration issue, resolve the reported tool
   problem, then run `pod install` from `ios/` and retry. Do not upgrade locked
   dependencies or discard the customized project to suppress an error. Preserve
   the first successfully resolved `ios/Podfile.lock` for reproducible builds;
   generated Pods, local SDK configuration and signing material stay ignored.

3. In Xcode inspect Runner → General and Signing & Capabilities. Confirm the
   identifiers, XennDo branding, version/build, iOS 15.0 floor and selected
   orientations. **The owner selects the Apple team** for Runner/RunnerTests.
   Do not change the Android application ID or add APNs/iCloud capabilities for
   one-time local notifications.

4. Start an iPhone simulator and run both Flutter and native host checks:

   ```bash
   flutter devices
   flutter run -d <ios-simulator-id>
   xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' test
   ```

   Replace device placeholders with actual IDs. Native RunnerTests check bundle
   identity/metadata and that app file sharing does not expose Documents. They
   are supplied for the Mac run and have not executed here.

5. Pair a physical iPhone, enable Developer Mode where required, select owner
   signing and run `flutter run -d <iphone-id>`. Export a private backup before
   destructive restore/upgrade checks. Keep existing Android installation/data.

## Physical-iPhone acceptance matrix

- [ ] Fresh install/empty Inbox, offline CRUD/subtasks, completion/reopen/Undo,
  Today/overdue/My Top 3, Upcoming/date strip, search/filters and progress.
- [ ] Persistence and theme selection after termination/relaunch and upgrade.
- [ ] Notifications: no launch prompt, first contextual prompt, denial, repeated
  denial, Settings return, authorization, provisional/quiet delivery, foreground,
  background, terminated launch tap, missing-task tap and an existing unsaved draft.
- [ ] Time edits/removal/completion/deletion cancel the right request. Test pending
  IDs and delivered alerts, 64 requests/overflow, retry after delivery, app restart,
  device reboot, Focus/Summary/silent modes and timezone/DST changes.
- [ ] Save/export cancellation and provider failure; import cancellation,
  malformed/unsupported JSON and rollback failure; large-text confirmations.
- [ ] Android → iPhone → Android format-2 round trip using the real file pickers;
  legacy format-1 import, IDs/order/completed focus slots/theme preservation,
  fresh notification IDs and denied-permission restore warning. Verify counts
  without publishing private screenshots/backups.
- [ ] Small iPhone, notch/Dynamic Island/home indicator, landscape, large text,
  software/hardware keyboard, scroll-to-field validation, unsaved Close and iOS
  edge-back gesture behavior. Verify safe areas and VoiceOver focus/labels,
  contrast and reduced motion. iPad layouts are not release-qualified here.
- [ ] Owner-signed optimized build and native dependency/privacy integration.

## TestFlight and App Store — owner-controlled, not performed

1. Register/confirm the bundle ID and create the matching App Store Connect app
   using the owner's Apple Developer account. Choose signing/provisioning and
   protect certificates/profiles outside version control.
2. Approve icon/artwork, version/build number and target devices. Finish the
   physical-device matrix, privacy/contact URL, App Privacy responses, age rating,
   screenshots, support details, export-compliance and review information based
   on the actual archive. Do not guess declarations or credentials.
3. On the Mac, produce an owner-signed archive with `flutter build ipa --release`.
   Expected Flutter output directories are `build/ios/archive/` and
   `build/ios/ipa/`; no such archive or IPA was generated on Linux.
4. Inspect/signature-verify the archive in Xcode Organizer, resolve validation
   findings, then upload only with owner authorization. Run TestFlight internal
   testing and any required external beta review before requesting App Review.
   Publishing/releasing remains a separate owner decision.

Primary references: [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios),
[Flutter UIScene integration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate),
[locked notification plugin documentation](https://pub.dev/packages/flutter_local_notifications/versions/22.3.2).
