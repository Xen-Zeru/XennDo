# Xenn Do - Implementation Plan

**Last updated:** 2026-10-28

This plan delivers the initial offline-first Android version in nine phases.
Each phase ends with formatting, analysis, tests, and an update to
`docs/PROGRESS.md`. A phase is complete only when its acceptance criteria are
met and verified.

**Current phase:** Phase 9 — audit, fixes and Android release preparation.
Implementation checks and publication gates are tracked separately below and in
`docs/RELEASE_CHECKLIST.md`. No publication or signing-credential creation is
part of this work.

## Phase 1 - Project foundation

**Status:** Complete (2026-10-19)

**Goal:** Establish a reproducible Flutter project with the chosen architecture
and verified tooling.

**Deliverables**

- Flutter project named `xenndo`, Android platform scaffold only.
- Temporary application ID `com.example.xenndo` documented as replaceable.
- Riverpod root scope, go_router configuration, and Material 3 theme.
- Feature-based folder structure with a minimal working screen.
- Dependencies for Riverpod, Drift/SQLite, go_router, local notifications, and
  time zones, resolved against the installed SDK.
- Android core library desugaring configured for notifications.
- README, product specification, implementation plan, and progress document.
- Widget smoke test for the initial screen.

**Acceptance criteria**

- [x] `flutter pub get` completes and `pubspec.lock` is generated.
- [x] The app renders a minimal screen with the name Xenn Do and tagline
  "Plan your day. Get it done."
- [x] Riverpod wraps the app and go_router supplies the initial route.
- [x] Material 3 light and dark themes are configured.
- [x] The temporary application ID is clearly documented as a release blocker.
- [x] `dart format` makes no changes after formatting.
- [x] `flutter analyze` reports no issues.
- [x] The smoke test passes.
- [x] No database schema, reminder scheduling, or unfinished feature is claimed
  as implemented.

## Phase 2 - App shell and design system

**Status:** Complete (2026-10-19)

**Goal:** Build the navigable application shell and reusable visual foundation.

**Deliverables**

- Persistent shell with Today, Upcoming, Lists, and Settings destinations.
- Prominent Add Task action available throughout the shell.
- Progress entry point from Today.
- Responsive Material 3 layout that handles small phones and large text.
- Theme tokens for spacing, radii, priority colors, and status colors.
- Shared components: section headers, empty state, loading state, error state,
  preview notice, priority badge, and task row scaffold.
- Light, dark, and system theme selection source (persistence in Phase 7).
- Add/Edit Task layout with title, description, list, priority, due date,
  optional due time, reminder, subtasks, validation, and keyboard-safe layout.
- Placeholder screens with meaningful empty states and clearly separated
  temporary demo content.
- Widget tests for navigation, themes, responsive layout, editor validation, and
  reusable components.

**Acceptance criteria**

- [x] Each primary destination is reachable, and Add Task and Progress open
  from their intended entry points.
- [x] The shell and editor render without overflow at 320 dp width and 200% text
  scale.
- [x] Components use the shared theme; no feature hard-codes an unrelated palette.
- [x] Icon-only controls have semantic labels or tooltips.
- [x] Navigation, theme, editor, component, and smoke tests pass.
- [x] Light, dark, and system theme choices apply immediately.
- [x] The Add/Edit Task layout exposes every required field and validates an
  empty title.
- [x] Temporary demo data is visibly labeled as not saved and isolated for later
  removal.
- [x] `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test`
  pass.
- [x] Debug APK builds and the shell is visually inspected on an Android emulator.

The destructive-action confirmation/undo pattern is deferred to the phases that
introduce destructive mutations (Phases 4 and 7). Phase 2 contains no destructive
data actions.

## Phase 3 - Local database and repositories

**Status:** Complete (2026-10-20)

**Goal:** Establish durable local persistence with a tested Drift schema.

**Deliverables**

- Drift database with tables for lists, tasks, subtasks, and daily focus
  selections. A settings table was deferred to Phase 7, which added it as
  schema version 3.
- Schema versioning and a documented migration strategy.
- UUID-based identifiers and UTC timestamps, with local-date-aware due handling.
- Repositories scoped to feature needs instead of a generic repository layer:
  list, task/subtask, and daily focus.
- Transactions for related changes, including task creation with subtasks, list
  deletion with task migration, and task deletion with focus cleanup.
- Riverpod providers for the database, repositories, lists, Today, Upcoming, and
  My Top 3.
- In-memory and temporary-file database tests for persistence, deletion, focus
  limits, completion, and date handling.
- Seed of a protected Inbox list on first run.
- UI connection to persisted data with real empty states, replacing demo data.
- `docs/DATA_MODEL.md` documenting schema, date rules, and time-zone behavior.

**Acceptance criteria**

- [x] App data survives closing and reopening the database, verified with a
  temporary-file test.
- [x] Inbox cannot be deleted; deleting another list moves its tasks to Inbox.
- [x] Completing and reopening a task updates its completion timestamp correctly.
- [x] List, task, subtask, and focus CRUD tests pass.
- [x] Date-boundary behavior (overdue, today, upcoming, date-only retention) has
  tests using an explicit clock.
- [x] Schema version 1 and foreign-key enforcement are verified.
- [x] No UI depends directly on raw Drift tables; repositories return domain
  models.
- [x] Demo tasks and lists were removed.
- [x] Formatting, analysis, generation, and all tests pass.

## Phase 4 - Task and list management

**Status:** Complete (2026-10-21)

**Goal:** Deliver the core create, edit, organize, and complete workflows.

**Deliverables**

- List management: create, rename, recolor, and delete with task migration.
  Manual list reordering is deferred; the schema keeps `sort_order`.
- Task editor for description, list, High/Medium/Low priority (Medium default),
  due date/time, reminder metadata, and subtasks.
- Task add, view, edit, and delete from Today, Upcoming, and list detail.
- Task delete with a restorable snapshot and an Undo action.
- Task completion and reopen, with completed tasks shown in a separate section.
- Subtask add, edit, complete, reorder, and delete in the editor.
- Subtask completion never completes the parent task.
- Validation messages for task titles, list names, and subtask titles.
- Form input is preserved when a save fails.
- Repository and widget tests for create, edit, complete, delete/undo, list
  management, and validation.

**Acceptance criteria**

- [x] A user can create a list and add a task with title, list, priority, due
  date/time, and subtasks.
- [x] A task can be moved between lists and edited without data loss.
- [x] Subtasks can be reordered, edited, completed, and deleted independently.
- [x] Completing every subtask leaves the parent task open.
- [x] Deleting a task removes it and offers Undo that restores the task,
  subtasks, and focus selections.
- [x] Deleting a list explains that tasks move to Inbox and moves them.
- [x] Completed tasks appear separately and can be reopened.
- [x] Invalid blank titles are rejected with clear messages.
- [x] All mutations persist immediately through repositories.
- [x] Formatting, analysis, and all tests pass.

Manual task/list ordering deferred in Phase 4 is implemented in Phase 9. Task
creation remains the full title-first editor rather than a separate quick-add
shortcut.

## Phase 5 - Today, Upcoming, My Top 3, search, and filters

**Status:** Complete (2026-10-21)

**Goal:** Make the task data actionable through the core planning views.

**Deliverables**

- Today view with clearly labeled Overdue, Due today, and Completed sections.
- My Top 3 card with selection, reorder, removal, and completion controls.
- A My Top 3 picker that lists incomplete tasks and enforces the three-task
  limit.
- Duplicate task rows avoided between My Top 3 and the day sections.
- Upcoming grouped by local date with chronological and time-of-day ordering.
- Global search over task titles and descriptions.
- Filters for list, priority, and completion status, plus a clear-all action.
- Deterministic result ordering with stable tie-breakers.
- Date-based views refreshed on app resume and at local midnight.
- Clear empty, loading, and no-results states.
- Query-level tests for date boundaries, midnight rollover, focus limits,
  ordering, combined filters, and a 5,000-task fixture.
- Widget tests for focus selection, search/filter clearing, and day rollover.

**Acceptance criteria**

- [x] Overdue tasks appear in Today in a clearly labeled section.
- [x] Tasks due today appear in a separate Due today section.
- [x] My Top 3 accepts at most three distinct incomplete tasks and rejects
  duplicates.
- [x] My Top 3 supports reordering, removal, and completed selections staying
  visible.
- [x] A new local day starts with its own selections.
- [x] Upcoming excludes undated tasks and groups by local due date with timed
  tasks sorted by time.
- [x] Search matches task titles and descriptions.
- [x] Combined filters produce the intersection of active criteria.
- [x] Clearing filters restores the unfiltered result set.
- [x] Views are covered by a 5,000-task fixture query test.
- [x] Date views refresh on resume and local day change.
- [x] Formatting, analysis, and all tests pass.

Subtask-level search is not included; search currently covers task titles and
descriptions as specified in the Phase 5 prompt. It is noted in
`docs/PROGRESS.md`.

## Phase 6 - Local reminders

**Status:** Complete (2026-10-25)

**Goal:** Deliver reliable one-time local notifications using device time zones.

**Deliverables**

- Notification plugin initialization and Android channel setup.
- Time-zone initialization and current-zone refresh handling.
- In-context notification permission request and status display.
- Reminder scheduling, editing, cancellation, and tap routing to the task.
- Cancellation when a task is completed or deleted.
- Startup reconciliation of pending reminders.
- Handling of exact-alarm availability and fallback scheduling.
- Unit tests for reminder validation and service coordination where practical.
- Manual Android verification checklist.

**Acceptance criteria**

- [x] A future reminder fires at the selected local time on a physical or
  emulator device with notifications permitted.
- [x] Tapping a notification opens the correct task.
- [x] Editing a reminder replaces the previous scheduled notification.
- [x] Completing or deleting a task cancels its reminder.
- [x] Denying permission leaves the app usable and surfaces the unscheduled
  state.
- [x] Reminders remain scheduled after an app restart.
- [x] Time-zone changes are handled without firing at an unintended local time.
- [x] Formatting, analysis, and all tests pass.

Verified on the `Medium_Phone_API_37.0` emulator: a reminder saved for a local
time posted a notification, and tapping it opened the Edit task screen. Two
platform behaviors are accepted rather than fought: scheduling is inexact
unless the user grants exact alarms (so delivery can be a few minutes late
inside the system window), and the delivery was verified on an emulator rather
than physical hardware. Reboot restoration, a device time-zone change, and the
exact-alarm grant path are recorded as pending manual checks in
`docs/PROGRESS.md`.

## Phase 7 - Progress and settings

**Goal:** Add completion insight and persistent user preferences.

**Deliverables**

- Progress view for today and the last seven days based on completion timestamps.
- Completion history grouped by local day with task reopening support.
- Settings persistence for theme mode and notification preference state.
- Notification permission status and system settings shortcut.
- About/version/privacy section.
- Empty states for no history or no completions.
- Tests for aggregation boundaries and preference persistence.

**Acceptance criteria**

- [x] Progress counts match the underlying completion timestamps at local-day
  boundaries.
- [x] Reopening a task updates progress and history immediately.
- [x] Theme selection persists across restart and supports system/light/dark.
- [x] Notification status reflects the actual platform permission state.
- [x] No mutable counter is used as a source of truth for progress.
- [x] Formatting, analysis, and all tests pass.

Verified on the `Medium_Phone_API_37.0` emulator: the Progress screen showed
"No tasks due" instead of a percentage when nothing carried today's date, then
showed the completed task, the seven-day counts, and a single bar on today
after a task was completed. Selecting Dark, force-stopping the app, and
relaunching restored the dark theme and the selected chip, and the About card
reported the installed version `1.0.0 (1)`. Grouping boundaries, reopening,
theme persistence, and permission states are covered by automated tests; the
theme was returned to System and the verification task deleted afterwards.

## Phase 8 - Backup and restore

**Goal:** Let users move or recover their local data safely.

**Deliverables**

- Versioned JSON export of lists, tasks, subtasks, reminders, Top 3 selections,
  and required settings.
- Android share/save integration for the exported file.
- Import validation with schema version checks and clear errors.
- Confirmation flow with a pre-import data summary.
- Transactional replacement and reminder rescheduling after restore.
- Tests using representative backups, malformed files, and unsupported versions.
- Clean-install manual restore verification.

**Acceptance criteria**

- [x] Exported backup contains all data required to reconstruct app state.
- [x] A backup restored on a clean install reproduces lists, tasks, subtasks,
  completion history, and Top 3 selections.
- [x] Invalid or unsupported files fail without changing existing data.
- [x] Import requires explicit confirmation and reports the result.
- [x] Future reminders are rescheduled after restore.
- [x] The UI discloses that backup files are not encrypted.
- [x] Formatting, analysis, and all tests pass.

Verified on the `Medium_Phone_API_37.0` emulator: exporting wrote
`xenndo-backup-2026-10-25.json` through the system save dialog after the
disclosure, and the file held a version 1 envelope with the real lists, task,
Top 3, and settings rows. Restoring on the same install removed a task that had
been created after the export, so the data returned to the exported state. A
file with `"version": 99` was refused with "Nothing was changed.", and after
`adb uninstall` plus a reinstall the same backup rebuilt Today and Lists,
including the My Top 3 selection, with the reminder alarm re-registered for
2026-10-28 10:00. Validation, cancellation, transactional rollback (forced by a
SQLite trigger), and version rejection are covered by automated tests; no
storage permission was added and the verification files were removed from the
device afterwards.

## Phase 8.5 - XennDo UI Refinement

**Status:** Complete (2026-10-25), verified on `Medium_Phone_API_37.0`.

**Goal:** Refine the existing native Flutter interface without changing task,
reminder, progress, search, filter, persistence, or backup behavior.

**Deliverables**

- Calm, accessible light and dark Material 3 colors and shared spacing.
- A concise Today screen with documented due-today progress, compact focus
  rows, accessible reordering, and no duplicate agenda tasks.
- Reusable task rows with separate completion and edit actions, metadata, and
  contextual task management.
- An Upcoming date strip and date-picker navigation that scroll to groups
  without filtering the task list.
- Reference-matched typography, in-card Today section titles, Upcoming time
  columns, list icon tiles, and list progress derived from completed/total tasks.
- Compact Lists and Settings screens, accurate notification permission actions,
  and no Add Task action in Settings.
- A title-first, keyboard-safe editor with expandable optional fields and
  protection against accidental loss of edits.
- Focused widget tests, updated project documentation, and Android visual
  inspection.

**Acceptance criteria**

- [x] Existing task, list, focus, reminder, search, filter, progress, backup,
  and restore behavior remains intact.
- [x] Light and dark themes use the refined palette and preserve System/Light/
  Dark persistence.
- [x] Today does not duplicate tasks between My Top 3 and agenda sections;
  overdue focus tasks remain labeled and completed focus selections stay visible.
- [x] Focus tasks can be selected, completed, removed, reordered by dragging,
  and reordered with accessible move actions.
- [x] Upcoming date selection scrolls to its date group without hiding other
  tasks; the date picker remains available.
- [x] Settings has no Add Task button and displays the actual app name, version,
  notification status, and available permission actions.
- [x] The editor validates titles, handles keyboard insets, and confirms before
  discarding unsaved edits.
- [x] Small-screen and large-text layouts, empty and populated states, and
  meaningful task interactions are covered by tests.
- [x] Formatting and static analysis pass.
- [x] The standard `flutter test --no-pub --concurrency=1` run passes all 140 tests.
- [x] `flutter build apk --debug --no-pub` succeeds for the final source.
- [x] Current APK installed and running on the Android emulator; light/dark
  layouts, real notification denial/settings flow, full-keyboard handling, and large
  text checked. Screenshot provenance and unverified areas are documented.
- [x] Temporary verification fixtures removed and the original app database,
  preferences, font scale, and permission state restored.

See `docs/PROGRESS.md` for actual results and the limits of the current checks.
The Phase 8.5 record above predates the Phase 9 audit below.

## Phase 9 - Audit, fixes and Android release preparation

**Status:** Audit, fixes and preparation complete (2026-10-26); publication gates remain open.

**Goal:** Audit the entire initial scope, fix gaps, verify Android builds and
prepare a concrete release checklist without inventing signing credentials or
publishing. Owner-dependent publication gates remain explicit.

**Implementation and preparation**

- [x] Audit functional, offline, persistence, accessibility, layout, migration
  and Android configuration requirements; record evidence in `PHASE9_AUDIT.md`.
- [x] Close gaps in active-focus slots, date-range filters, list/task ordering,
  completion history, minute-based overdue refresh and reminder failure paths.
- [x] Preserve Undo after row disposal and database commits after platform errors.
- [x] Transactional schema-4 migration from prior schemas; backup format 2 with
  format-1 compatibility, order preservation and safe Inbox normalization.
- [x] Use `com.xennzeru.xenndo` consistently in application ID, namespace and
  Kotlin source path; display XennDo from actual package metadata.
- [x] Export old-app data before installing the separate new package; leave the
  old app installed. Verify empty fresh installation, then explicit restore.
- [x] Replace stock Android launcher/splash assets; preserve notification icon.
- [x] Remove debug release-signing fallback; accept protected external signing
  configuration and generate unsigned compilation artifacts when it is absent.
- [x] Review manifest permissions and disable implicit OS backup/transfer.
- [x] Run a 5,000-task query and lazy-layout regression, including distant-date
  scrolling without filtering away the other groups.
- [x] Add meaningful widget/repository regressions; format, analyze and test.
- [x] Build debug and unsigned release APKs and inspect identity/signature,
  permissions, retained icon resources and static 16 KB alignment.
- [x] Update README commands/output paths, data model, privacy/listing drafts,
  audit record, release checklist and PROGRESS with actual verification limits.

**Post-audit UI follow-up (2026-10-26):** Dedicated About XennDo page with the
requested copy, developer credit, automatic version/build and Flutter licenses;
Settings retains a compact version-only row. No later product phase started.

**Publication gates — not claimed complete**

- [ ] Owner-provided signing credentials and a verified production-signed AAB.
- [ ] Full physical-device/API matrix, TalkBack/Switch Access and 16 KB runtime.
- [ ] Reboot/Doze/manufacturer timing, cold-start notifications, DST/timezones
  and owner-signed optimized build checks on physical hardware.
- [ ] Approved store graphics/contact details, public privacy-policy URL,
  account verification, Play declarations, required testing and pre-launch report.
- [ ] Owner publication approval. Nothing is uploaded or published by this phase.

The exact commands, actual APK results and emulator checks are in PROGRESS.
No later product phase is started.

## Android and iOS extension — 2026-10-28

**Status:** Source integration and Linux checks complete (176 tests and Android
debug build passed); native iOS
qualification requires macOS/Xcode. No platform is published by this extension.

- Audit locked plugin support and retain Android identity, native configuration,
  database schema 4 and JSON backup versions 1/2.
- Add a generated iOS host with `com.xennzeru.xenndo`, native branding and
  owner-selected Apple signing. Preserve Flutter UIScene/plugin integration.
- Add Darwin notification initialization, contextual permissions, Settings,
  scheduling/cancellation, tap payloads and safe pending-request capacity handling.
- Replace Android-only UI text and check iPhone-style safe areas, keyboard,
  navigation and accessibility through Linux widget tests.
- Run formatting, analysis, tests and an Android regression build; record actual
  results in PROGRESS. iOS compilation/runtime is not inferred from Dart tests.
- Follow [IOS_SETUP.md](IOS_SETUP.md) for Mac setup, device qualification,
  cross-platform backup tests and owner-controlled TestFlight/App Store steps.

## Cross-phase quality gates

Every phase must:

- Run `dart format .`.
- Pass `dart format --output=none --set-exit-if-changed .`.
- Pass `flutter analyze`.
- Pass `flutter test`.
- Update `docs/PROGRESS.md` with actual commands, results, blockers, and the next
  phase's readiness.
- Avoid introducing excluded scope.
- Avoid claiming unverified device behavior as tested.
