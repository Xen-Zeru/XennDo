# XennDo progress and verification

Updated 2026-10-28.

The initial offline Android implementation, Phase 8.5 UI refinement, Phase 9
implementation audit and About-page follow-up are complete. Store publication
has not occurred; owner signing and device qualification remain separate gates.

## Delivered implementation

- Persistent task, list and independent subtask management, including completion,
  reopening, priorities, notes, local deadlines, ordering and deletion Undo.
- Today and chronological Upcoming, without duplicate focus rows. My Top 3
  retains completed selections and permits three active selections per local day.
- Combined search/list/priority/status/date filters; local-day completion history
  and progress derived from stored task records.
- One-time local reminders, contextual permission requests, denial/settings
  handling, scheduling/cancellation and notification-to-editor navigation.
- System/Light/Dark appearance and a dedicated About XennDo page with installed
  version/build metadata, developer credit and Flutter's license page. Settings
  keeps a compact version-only label.
- Validated, transactional backup restore; format 2 exports and format 1 imports.
  Schema 4 migrates earlier schemas without discarding user data.

The [product specification](PRODUCT_SPEC.md),
[implementation plan](IMPLEMENTATION_PLAN.md),
[data model](DATA_MODEL.md) and [initial-scope audit](PHASE9_AUDIT.md) retain the
requirements, architecture and implementation details.

## Important audit fixes

- Completed focus tasks free a slot; reopening and Undo cannot create a fourth
  active selection. Accessible move actions complement dragging.
- Date-range filters, list/task ordering, completion-history navigation and
  minute-based overdue refresh close initial-scope gaps.
- Today, Upcoming and search create rows lazily. The automated 5,000-task fixture
  exercises queries and navigation past earlier future-date groups.
- Reminder platform failures are separate from successful database commits.
  Removing a reminder cancels its previous notification ID. Reconciliation
  serializes with task updates and continues past individual platform failures.
- Notification navigation preserves the shell and unsaved drafts; direct editor
  routes cannot pop their last page. An editor retains its working copy while
  waiting for deletion cancellation, and Undo outlives its original task row.
- New/changed reminders require a future time. Unchanged elapsed definitions can
  remain when editing other fields. Calendar bounds include imported old dates.
- Exports read a consistent database snapshot. Restore validates before replacing
  data, normalizes legacy missing-list references and assigns fresh native IDs.
  Permission denial is reported without claiming successful reminder scheduling.
- Sensitive dialogs scroll, and Settings has no Add Task action.

## Recorded verification

The preceding implementation checks used Flutter 3.47.6 / Dart 3.13.5 and passed
formatting, static analysis, all **167 tests**, a debug APK build and an unsigned
release APK build. Raw logs and temporary screenshots are intentionally omitted
from the public source tree.

Actual Android API 37 emulator checks covered fresh/empty states, explicit
backup export/restore, permission denial and system settings, a real delivered
notification and editor navigation, reminder cancellation, offline task actions,
Undo, appearance persistence, and a full keyboard at 320 dp / 200% text.
About and Flutter license navigation were also checked. These checks used debug
builds, not a production-signed installation.

Private user records were compared before and after the checks and preserved.
Temporary QA tasks were removed. Emulator settings changed for verification
were restored. No reference-image sample tasks are seeded in the application.

## Source-publication preparation

- Consolidated verification history here instead of retaining screenshot galleries,
  raw logs, fixture-manipulation scripts and repeated machine-specific narratives.
- Removed disposable development captures and scratch output after reference checks.
  Personal database/backup copies are preserved privately outside the project.
- Reworked README around implemented features, setup, privacy, backup semantics,
  Android permissions, build outputs and the requested developer credit.
- Reviewed ignore rules for caches, IDE state, environment/signing secrets,
  personal data, logs and binary artifacts. Required generated Drift source,
  lockfile, Flutter metadata and Gradle wrapper remain publication candidates.
- This working folder has no Git metadata or remote. Tracked/untracked status,
  existing Git changes and prior-commit exposure cannot be established from it.
  No history, index, remote, commit or visibility was changed.

See the [source publication checklist](PUBLICATION_CHECKLIST.md) before staging
and the [Android release checklist](RELEASE_CHECKLIST.md) before distribution.

### Publication-cleanup validation — 2026-10-26

Using Flutter 3.47.6 / Dart 3.13.5:

| Check | Actual result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Passed: 103 Dart files, zero changes. |
| `flutter analyze` | Passed: no issues. |
| `flutter test --reporter expanded` | Passed: all 167 tests. |
| `flutter build apk --debug` | Passed: `build/app/outputs/flutter-apk/app-debug.apk`. |
| Local Markdown links / Android resources | Passed: 23 local links across 10 Markdown files; 16 resource references resolve. No runtime image asset depends on a deleted capture. External URLs were not network-verified. |
| Publication candidates / ignore policy | 147 candidate files scanned; no credential signatures, private keys, personal database/backup exports or literal machine-home paths found. Required generated source and Gradle wrapper remain eligible; 16 private/local ignore probes passed. |
| Before/after source comparison | Application source, tests, Android app sources/resources, package manifest/lockfile, Flutter metadata and emulator helper are unchanged. |
| Git status / remote / index / history | Blocked: this folder has no Git metadata. No tracked-file or history-cleanliness claim is possible. |

Removed 243 individually reviewed development-artifact paths: 114 captures,
65 logs and 64 scratch/gallery/data files. The 22 database/JSON files were
hash-verified into a private local archive outside the project before removal.
An external cleanup manifest records exact paths. Normal ignored build caches
and current APK outputs remain local; source and required assets were retained.

The build reported dependency-update notices and a Gradle native-access warning;
neither prevented success. Dependencies were not upgraded. No new emulator or
physical-device session, release build, installation or publication was performed
during this source cleanup. The earlier unsigned release artifact remains local.

## GitHub source-publication preparation — 2026-10-28

The owner supplied [Xen-Zeru/XennDo](https://github.com/Xen-Zeru/XennDo) and
authorized a source-only commit and push. Git was initialized on `main`, with
repository-local commit identity and SSH origin. An HTTPS reference query found
the repository empty. SSH authentication failed with `Permission denied
(publickey)`, blocking the push and remote verification until authentication is
available. No remote history was overwritten.

README now links to the actual repository and includes SSH/HTTPS cloning
instructions. Publication-candidate privacy checks and private-file ignore probes
were repeated before staging. No signing credentials, license, APK upload,
GitHub Release or visibility change was introduced.

## Android and iOS extension — 2026-10-28

Added an iOS 15.0 host generated with the installed Flutter SDK, then copied only
the iOS platform and its migration metadata into this working project. Runner
uses `com.xennzeru.xenndo`, display name XennDo, installed version/build metadata,
UIScene/implicit-engine plugin registration, matching calendar/check icons and
a light/dark launch background. No Apple development team is selected.

The resolved dependencies already include iOS implementations. No new package,
lockfile, database-schema or JSON-format change was needed. Drift storage keeps
the same sandbox filename, and format 2 / legacy format 1 remain portable.
FilePicker uses the native Files document picker on iOS; native cross-device
round trips still need device qualification. iOS device backups may include
sandbox data; documentation now distinguishes this from Android exclusions.

Darwin notification setup does not prompt at launch. Contextual permission,
not-determined vs denied state, provisional delivery, system Settings,
foreground presentation, UTC scheduling and warm/cold task payload routing use
the existing reminder/navigation architecture. A 64-request guard refuses excess
iOS reminders without evicting existing requests; task saves survive with a
visible warning. There is no background rolling reminder queue. Platform-aware
permission/delivery copy replaces Android-only messages on iOS.

Nine added tests cover iOS channel initialization/permissions/timezone refresh,
notification content/taps/cancellation/capacity, persisted task content after a
capacity refusal, and iPhone-style safe areas, large text, keyboard validation,
Settings navigation and unsaved-draft protection. These run on Linux with
mocked platform channels and layout metrics, not Apple's notification service.

| Check | Actual result |
| --- | --- |
| `dart format .` and clean format check | Passed: 107 Dart files, zero remaining changes. |
| `flutter analyze` | Passed after removing an unnecessary test import; no issues. |
| `flutter test --reporter expanded` | Passed: all 176 tests, including the original Android/shared regressions. |
| `flutter build apk --debug` | Passed: `build/app/outputs/flutter-apk/app-debug.apk`. No installation performed. |
| `ruby -c ios/Podfile` | Passed: syntax only; CocoaPods resolution requires a Mac. |
| Static iOS configuration/assets | Plist/XML/JSON parse, identifiers, absent signing team, 15 icon dimensions and local Markdown links passed. This is not an Xcode build. |
| Android/data preservation | All Android files match the pre-extension hash baseline, including ignored local configuration. Schema/generated database source, backup codec/repository and lockfile are unchanged. No live device database was accessed or reset. |
| Publication hygiene | Source credential/path scan and iOS generated-file/signing ignore probes passed. Nothing committed, pushed or published by this extension. |
| iOS compile / simulator / XCTest / physical iPhone / archive | Not run: host is Linux; Xcode and CocoaPods are unavailable. No IPA generated. |

The first new test runs exposed test-harness assumptions about UTC alias names,
the iOS cancel channel argument and widget platform overrides; these were
corrected against the locked plugin API before the full passing run. The final
Android build reported existing dependency-update and Gradle native-access
notices; no dependency upgrade or Android configuration change was made.

See [IOS_SETUP.md](IOS_SETUP.md) for the dependency audit, exact Mac commands,
owner-selected signing, physical-iPhone acceptance matrix and TestFlight/App
Store preparation. Native integration remains unverified until those checks run.
No platform was published and no signing material was generated.

## First signed Android release preparation — 2026-10-28

Requested artifact: production-signed APK for `com.xennzeru.xenndo`, version
`1.0.0+1`. No release is published by this work.

- Added an owner-run terminal helper that creates a production PKCS12 keystore
  outside the repository, or reuses an existing identity. Passwords are hidden
  and passed to keytool through an anonymous pipe; ignored local properties use
  mode 0600. The helper never overwrites an existing key or configuration.
- Release packaging now fails without signing configuration and rejects the
  standard debug keystore/alias. Missing-signing rejection and an unsigned-free
  debug dry run both passed. No implicit debug fallback exists.
- Updated README and the Android checklist with private setup, encrypted backup,
  certificate/checksum verification and safe device-install procedures.
- Clean format check: 107 Dart files, zero changes. `flutter analyze`: no issues.
  `flutter test --reporter expanded`: all 176 tests passed.
- Signing is awaiting actual owner-generated private files in this workspace.
  At this checkpoint neither the production keystore nor `android/key.properties`
  exists. The signed build must wait until the private setup is available.
- Therefore no new signed APK, verified production certificate or APK checksum
  is recorded yet. Existing debug/unsigned artifacts are not substituted.
- No user database was changed, no app was uninstalled, and nothing was staged,
  committed, pushed or published. Physical-device qualification remains pending.

## Verification limits

Physical hardware, the full supported API matrix, TalkBack/Switch Access,
landscape, reboot/Doze/manufacturer behavior, timezone/DST changes, real-device
frame timings and 16 KB runtime remain unqualified. Previous static ZIP/ELF
alignment checks do not establish runtime compatibility.

No production signing credentials or signed app bundle were created. Store
artwork/contact details, a hosted owner-reviewed privacy policy, required
publisher declarations/testing and publication approval remain open.
