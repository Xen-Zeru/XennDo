# XennDo Android release checklist

Updated 2026-10-26. This records release preparation separately from publication
approval. No production signing credentials have been supplied or generated;
no app has been published.

## Identity, branding and version

- [x] Final application ID and namespace: **`com.xennzeru.xenndo`**, supplied by
  the owner. Kotlin package and source folder use the same identity.
- [x] Launcher/display name: **XennDo**; About reads installed package metadata.
- [x] Replace the Flutter stock launcher with a teal calendar/check vector,
  adaptive and monochrome icon; Android 12 splash assets and light/dark native
  startup themes. Preserve the monochrome notification icon during shrinking.
- [x] Version `1.0.0`, build `1`, sourced from `pubspec.yaml` (`1.0.0+1`).
- [ ] Owner approves the launcher artwork and final public branding. Store icon
  (512×512), feature graphic, phone screenshots, description and contact details
  still need final preparation in Play Console.
- [ ] Confirm the first publication version/build number; later uploads must
  advance the build number.

Changing from `com.example.xenndo` creates a separate Android installation. It
does not migrate private SQLite data, permission grants, preferences or native
alarms. The old app was **not uninstalled**. Before installing the new package,
its backup was exported through the app to the emulator's Downloads folder,
validated and retained. The new installation was checked empty, then that backup
was restored through the preview and replace-all confirmation. See PROGRESS
for the actual data-preservation checks. Keep this backup private.

## Signing: required before distribution

- [x] Remove the release build's debug-key fallback.
- [x] Release builds without `android/key.properties` produce an **unsigned**
  APK. A successful compile is not a signed, installable or publishable release.
- [x] Reject partial signing properties instead of silently changing identity.
- [x] Ignore `key.properties`, `*.jks` and `*.keystore` in version control.
- [ ] Owner supplies/protects the upload keystore and its recovery material,
  chooses Play App Signing, and controls the signing passwords.
- [ ] Create local, ignored `android/key.properties` with the four owner-owned
  values: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. `storeFile` can
  be an absolute path outside this repository, or a path relative to `android/`.
  Protect the file and inject credentials through protected CI storage if used.
  Do not put secrets in chat, source, docs, build logs or version control.
- [ ] Run `flutter build appbundle --release` after signing is configured; inspect
  `build/app/outputs/bundle/release/app-release.aab` and verify its certificate.
- [ ] Verify the upload certificate and any Play-delivered build against the
  owner-controlled expected identity. Retain the signed artifact/checksums.

The audit's `app-debug.apk` uses the Android development key. The audit's
`app-release.apk` is unsigned: `apksigner verify` intentionally fails. Neither
artifact is a Play Store publication candidate. Follow the official
[Android signing guide](https://developer.android.com/studio/publish/app-signing)
and [Flutter release instructions](https://docs.flutter.dev/deployment/android).

## Configuration and privacy

- [x] APK minimum SDK 24; compile/target SDK 36. Recheck the target API required
  at publication time against
  [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).
- [x] Release manifest has no Internet, broad storage, contacts, location or
  account permission. Backup uses the scoped system document picker.
- [x] Declare `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` and
  `SCHEDULE_EXACT_ALARM`. Notification vibration and AndroidX internal receiver
  permission are merged dependencies. Use inexact delivery without exact-alarm
  access; the app does not request `USE_EXACT_ALARM`.
- [x] Main activity is exported for launching; notification receivers are not
  exported. Notification permission denial leaves task management usable; legacy
  Android/OEM settings navigation has an app-details fallback.
- [x] Disable automatic Android cloud backup and device transfer with manifest
  flags and extraction rules; explicit user-controlled JSON export remains.
- [x] No accounts, analytics, advertising, cloud service or demo-data seed.
- [x] Backup privacy disclosure and replace-all confirmation are scrollable;
  scheduling failures never claim a failed database save.
- [ ] Owner reviews the exact-alarm use against current Play policy/declarations
  and tests inexact timing on real devices. Permission presence is not proof of
  special-access approval or precise delivery.
- [ ] Review dependency licenses/security advisories before shipping; preserve
  the resolved lockfile and required notices. No broad dependency upgrade was
  performed as part of this audit.

## Required device qualification

Emulator checks and automated results are summarized in
[PROGRESS.md](PROGRESS.md). Temporary captures are excluded from public source;
those checks do not replace this matrix.

- [ ] Physical Android device: fresh install, CRUD, persistence, search, filters,
  history, themes, backup export/restore and offline operation.
- [ ] Minimum supported API 24 and representative APIs before/after notification
  permission changes (notably API 32/33), plus current Android releases.
- [ ] TalkBack focus/order, Switch Access, landscape, smallest supported screen,
  200% text, contrast, external keyboard and gesture/button navigation.
- [ ] Notifications: denied/permanently denied, notification channel disabled,
  exact access denied/granted, foreground/background delivery, cold-start tap,
  deleted-task tap, cancellation, reboot, upgrade and timezone/DST changes.
- [ ] Battery saver/Doze and manufacturer background restrictions. Never promise
  exact reminder delivery when Android has not granted it.
- [ ] Real-device performance with at least 5,000 tasks; the automated fixture
  verifies queries and bounded lazy row construction, not frame timings.
- [ ] 16 KB runtime environment. APK ZIP alignment and ELF load alignment are
  statically checked; that does not establish runtime compatibility. Follow
  [Android's 16 KB guide](https://developer.android.com/guide/practices/page-sizes).
- [ ] Test an owner-signed optimized build and the final Play-distributed build.
  The unsigned release APK was not installed for testing.

## Store publication work remaining

- [ ] Verified developer account, publisher identity, final support email and
  applicable testing/access requirements in Play Console.
- [ ] Publish the owner-reviewed [privacy statement](PRIVACY.md) at an active
  public URL and supply that URL to Play Console; update in-app information if
  needed. The local privacy text currently works entirely offline.
- [ ] Complete Data safety, ads declaration (no ads), target audience, content
  rating, app access (no account required) and permission declarations. Check
  actual dependency behavior and the final binary when answering.
- [ ] Finalize [listing copy and release notes](STORE_LISTING.md), localized
  artwork/screenshots and contact details; review all claims against the app.
- [ ] Upload the production-signed AAB, run internal/closed testing and Play's
  pre-launch report, resolve findings, then obtain owner publication approval.

The [Play review preparation guide](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
is the source for the App content/privacy declarations. These requirements can
change; verify them in the owner's Play Console immediately before submission.

## Backup, upgrade and rollback procedure

1. Export a private backup before installing an update, switching application
   IDs or testing a destructive restore. Keep the currently installed artifact
   and its signing certificate identified.
2. Install updates with the same application ID and signing identity. Use the
   app's explicit export/restore flow when changing IDs; leave the old install
   intact until the destination has been checked.
3. Schema versions 1, 2 and 3 migrate transactionally to 4. New backups use format
   2; this build also reads format 1. Old builds cannot read format 2 or schema 4.
4. Do not downgrade a live schema-4 database into an older build. If rollback is
   necessary, retain current data, use a pre-upgrade backup with the matching
   older build, and explicitly confirm any replacement. Do not uninstall or
   overwrite the user's only copy to force a rollback.
