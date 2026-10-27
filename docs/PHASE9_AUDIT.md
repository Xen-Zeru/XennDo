# Phase 9 initial-scope audit

Audited 2026-10-25/26 against PRODUCT_SPEC sections 5–9 and the Phase 8.5 UI
requirements. This is implementation evidence, not a claim of Play approval or
physical-device qualification. The release checklist tracks those separate gates.

| Requirement | Result and evidence |
| --- | --- |
| Fresh install / offline | Only Inbox is seeded; no sample tasks, onboarding account, network client or release Internet permission. A separate final-ID emulator installation was checked empty before restoring. Empty/loading/error widget states remain. |
| 5.1 Lists | Create, rename, recolor, reorder and delete; Inbox protected from deletion; deleting a list moves tasks to Inbox. Added visible contextual move actions and complete-order validation. Repository and task-management tests cover persistence/counts. |
| 5.2 Tasks | Title validation; all stored fields retained; transactional task/subtask editing; completion/reopen timestamps; deletion with Undo. Platform scheduling failure no longer turns a committed save into an apparent failure. Row-menu Undo now outlives disposal of its original row. |
| 5.3 Subtasks | Add/edit/delete/complete and accessible up/down order; independent parent completion. Shared aggregate subtask counts update rows without a subscription per task. Tests cover CRUD, persistence, independent completion and form validation. |
| 5.4 Dates / priority / order | Calendar-date storage and local-time overdue checks retained. Open list tasks default to priority then date/time, with explicit manual ordering available. Stable ordering and range-bound tests. Timed overdue refreshes each minute without reopening the screen. |
| 5.5 Today | Incomplete due/overdue groups, separate completed section, progress definition and My Top 3. Focus IDs are excluded from every other Today section; overdue focus labels and completed selections remain. Duplicate-row, large-text and rollover widget regressions. |
| 5.6 Upcoming | All incomplete future tasks grouped by correct local date; date-only vs timed metadata. Strip/date-picker navigation scrolls without filtering. Empty-date feedback is inline, avoiding a large blocking snackbar. The initial week includes tomorrow even on Sunday. Lazy groups support distant-date scrolling after thousands of earlier rows. |
| 5.7 My Top 3 | Limit applies to three incomplete tasks. Completed selections remain visible and free a slot. Selection/reorder/remove persist by day; drag and move actions retained. Reopen/Undo cannot create four active selections. Added schema migration and round-trip regressions. |
| 5.8 Search / filters | Titles and notes; combined list, priority, status and inclusive local due-date range; clear-all. Added range picker and lazy result rows. Tests check intersections, escaped search, results, clear behavior and 5,000-row queries. |
| 5.9 History | Added local-day completion-history groups, recent seven-day windows and an end-date picker for older windows. Rows open editing and allow reopening. Repeated completion preserves its timestamp. History/reopen widget regression. |
| 5.10 Reminders | Future validation for new/changed reminders, safe old-date pickers and unchanged elapsed definitions; in-context permission request, denied/permanently denied states, settings shortcut and unscheduled warnings. Stable unique IDs, immediate removal cancellation, complete/delete/reopen behavior and tap routing. Operations serialize with reconciliation. Startup/resume failures are caught; per-task reconciliation failures do not stop other tasks. Fake-scheduler tests verify failures, denial, cancellation, timezone resolution and navigation. Notification routes preserve the shell/unsaved drafts; direct editors cannot pop their last page. Editors retain a stable working copy during asynchronous deletion; missing targets have a Close action. Native checks are recorded separately in PROGRESS. |
| 5.11 Progress | Due-today denominator remains all tasks with today's due date, including timed overdue tasks today. Earlier due dates are excluded. No tasks due has no percentage. Seven-day counts derive from completion timestamps; loading/read failures are not displayed as zero data. |
| 5.12 Settings | Persisted System/Light/Dark; platform permission state, export/restore, actual package name/version and privacy text. No Add Task FAB. Sensitive dialogs scroll at large text. |
| 5.13 Backup | All owned rows exported in one read transaction; format 2 includes manual order and completed focus positions, while format 1 remains readable. Full validation precedes transactional replace-all. Null legacy list references normalize to Inbox. Fresh notification IDs on restore; denied permission is reported accurately. Partial-save failures no longer claim that no file was written. Existing failure/rollback/cancel tests retained. |
| Native UI / accessibility | Native Material 3 widgets, shared palette/spacing/shapes/rows, no image background, real data and package metadata. 48 dp controls, labels, flexible long-title layouts and keyboard-safe full editor. Reordering has visible alternatives; reduced-motion scrolling is respected. Widget tests include 320 dp / 200% text and scrollable backup confirmations. Physical TalkBack/Switch Access remain to qualify. |
| Persistence / migration | Schema 4 adds task order and rebuilds focus constraints without removing records. Unknown versions fail before mutation. Tests upgrade schemas 1/2/3, retain tasks/subtasks/focus/preferences, check foreign keys and reopen file databases. No database or user backup fixture is included in the public source candidates. |
| Performance | Existing 5,000-task repository fixture plus a widget fixture with lazy Today/Upcoming rows and navigation past 2,500 earlier future rows. Bounded visible row construction is checked; no real-device frame-time claim. |
| Android release | Permanent package/namespace/Kotlin path/display name, native icon/splash, explicit permissions and backup exclusions. Release debug-signing fallback removed. Debug and unsigned optimized release APK builds; signature/manifest/alignment checks. Signing and publication remain owner-controlled. |

## Boundaries retained

No accounts, cloud sync, collaboration, habits, recurrence, snooze, subtask-title
search, immutable completion event log or backup merge mode were added.
Backups remain readable JSON with a disclosure and explicit replace-all restore.
No new runtime dependency was necessary.

## Evidence locations

- Automated checks: `test/phase9_audit_test.dart`, database/repository, task
  management/editor, Today/focus, search, reminders, progress/settings, navigation,
  rollover and UI refinement tests.
- Exact commands/results and data-preservation checks: `docs/PROGRESS.md`.
- Historical emulator verification is summarized in `docs/PROGRESS.md`; raw
  captures and logs are excluded from public source.
- Publication blockers and remaining device matrix: `docs/RELEASE_CHECKLIST.md`.
