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

## Verification limits

Physical hardware, the full supported API matrix, TalkBack/Switch Access,
landscape, reboot/Doze/manufacturer behavior, timezone/DST changes, real-device
frame timings and 16 KB runtime remain unqualified. Previous static ZIP/ELF
alignment checks do not establish runtime compatibility.

No production signing credentials or signed app bundle were created. Store
artwork/contact details, a hosted owner-reviewed privacy policy, required
publisher declarations/testing and publication approval remain open.
