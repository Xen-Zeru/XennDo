# Xenn Do - Local Data Model

**Status:** Implemented in Phase 3; current schema version 4. Phase 9 adds task ordering and extends focus positions while preserving the three-active-task limit.

This document describes the Drift/SQLite persistence layer, the date and time
rules, and the migration strategy.

## 1. Storage overview

- Database: SQLite through Drift, opened with `driftDatabase(name: 'xenndo')` on
  Android.
- No network dependency. All reads and writes are local.
- Identifiers are UUID v4 strings generated on-device, except the built-in
  Inbox list which uses the stable id `inbox`.
- Related writes use database transactions.

## 2. Tables

### `task_lists`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT | Primary key |
| `name` | TEXT | Trimmed; blank names rejected |
| `color` | INTEGER | ARGB color value |
| `icon` | TEXT NULL | Optional icon key |
| `sort_order` | INTEGER | Manual ordering |
| `is_inbox` | BOOLEAN | Protects the built-in Inbox list |
| `created_at` | INTEGER | UTC epoch milliseconds |
| `updated_at` | INTEGER | UTC epoch milliseconds |

Constraints:

- `CHECK (length(trim(name)) > 0)`
- Inbox is seeded with `insertOrIgnore` on first database creation.
- Inbox deletion is rejected by the repository.

### `tasks`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT | Primary key |
| `title` | TEXT | Trimmed; blank titles rejected |
| `description` | TEXT NULL | Optional notes |
| `list_id` | TEXT NULL | References `task_lists(id)` with `ON DELETE SET NULL` |
| `sort_order` | INTEGER | Default 0; explicit list ordering uses increasing positive positions |
| `priority` | INTEGER | 0 none, 1 low, 2 medium, 3 high. New tasks default to medium in the repository; the schema default stays 0 for legacy rows. |
| `due_date` | INTEGER NULL | Local calendar date stored as epoch days |
| `due_time_minutes` | INTEGER NULL | Local wall-clock minutes, 0-1439 |
| `is_completed` | BOOLEAN | Completion state |
| `completed_at` | INTEGER NULL | UTC epoch milliseconds |
| `created_at` | INTEGER | UTC epoch milliseconds |
| `updated_at` | INTEGER | UTC epoch milliseconds |
| `reminder_at` | INTEGER NULL | Absolute UTC epoch milliseconds for the saved reminder |
| `reminder_date` | INTEGER NULL | Local calendar date of the reminder as epoch days |
| `reminder_time_minutes` | INTEGER NULL | Local wall-clock minutes of the reminder, 0-1439 |
| `reminder_offset_minutes` | INTEGER NULL | 0, 10, or 60 minutes before, for offset-based reminders |
| `notification_id` | INTEGER NULL | Stable notification identifier |

Constraints:

- `CHECK (length(trim(title)) > 0)`
- `CHECK (priority BETWEEN 0 AND 3)`
- `CHECK (due_time_minutes IS NULL OR due_time_minutes BETWEEN 0 AND 1439)`
- `CHECK (reminder_time_minutes IS NULL OR reminder_time_minutes BETWEEN 0 AND 1439)`

Indexes exist for due date, completion, completion timestamp, and list.

### `subtasks`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT | Primary key |
| `parent_task_id` | TEXT | References `tasks(id)` with `ON DELETE CASCADE` |
| `title` | TEXT | Blank titles rejected |
| `is_completed` | BOOLEAN | Independent of parent completion |
| `sort_order` | INTEGER | Manual ordering |
| `created_at` | INTEGER | UTC epoch milliseconds |
| `updated_at` | INTEGER | UTC epoch milliseconds |

### `daily_focus_entries`

| Column | Type | Notes |
| --- | --- | --- |
| `focus_date` | INTEGER | Local calendar date stored as epoch days |
| `task_id` | TEXT | References `tasks(id)` with `ON DELETE CASCADE` |
| `sort_order` | INTEGER | Non-negative position within a day; completed selections remain visible |

Constraints:

- Primary key `(focus_date, task_id)` guarantees distinct tasks per day.
- `UNIQUE (focus_date, sort_order)` and `CHECK (sort_order >= 0)`
  support arbitrary retained completed selections; the repository and backup
  validator enforce at most three incomplete selections per day.
- The repository additionally rejects a fourth task and duplicate selections.

### `settings`

| Column | Type | Notes |
| --- | --- | --- |
| `key` | TEXT | Primary key, e.g. `theme_mode` |
| `value` | TEXT | Stored preference value |
| `updated_at` | INTEGER | UTC epoch milliseconds |

Constraints:

- One row per key; writes use insert-or-replace so a preference can only hold a
  single value.
- Unknown or unreadable values fall back to the default (`theme_mode` falls back
  to `system`) instead of failing the read.
- Reminder metadata lives on the task row because one task has at most one
  active reminder in the initial version; the notification permission state is
  never stored because it is read from the platform on demand.

## 3. Date and time rules

Time-dependent logic is testable through pure helpers:

- `LocalDate` represents a calendar date without a time zone. `epochDay`
  conversion uses UTC calendar arithmetic, so a date-only deadline keeps the same
  selected calendar date regardless of the device's current time zone.
- `TaskTiming.isOverdue` accepts an explicit `now`, so overdue behavior can be
  tested without changing the device clock.
- `TaskTiming.resolveReminderInstant` computes an offset reminder's absolute
  UTC instant from local due date, local due time, and the selected offset.
  `TaskTiming.resolveLocalReminderInstant` does the same for an explicitly
  chosen reminder date and time.

Behavior summary:

| Value | Stored as | Time-zone change behavior |
| --- | --- | --- |
| Date-only deadline | Epoch day (`LocalDate`) | Keeps the same calendar date |
| Timed deadline | Epoch day plus local minutes | Keeps the same local wall-clock time; the absolute instant shifts with the zone |
| `created_at`, `updated_at`, `completed_at` | UTC epoch milliseconds | Absolute instant is stable |
| `reminder_at`, `reminder_date`, `reminder_time_minutes` | UTC instant plus local calendar date and minutes | The local fields win: the reminder keeps 10:00 local on its date, so the absolute instant shifts with the zone |
| `daily_focus_entries.focus_date` | Epoch day (`LocalDate`) | Focus selections stay on the local calendar date |

### Time-zone change guidance

- A task due "2026-10-20 at 10:00" is stored as date `2026-10-20` plus
  `10:00` local wall time. After a time-zone change, it still reads 10:00 local
  time on that date, so the absolute moment changes with the zone.
- A reminder is stored as local date and local minutes alongside the absolute
  UTC instant written at save time. The local fields are authoritative: on app
  start and on every resume, reconciliation re-derives the instant from them, so
  after a time-zone change the reminder still fires at the same local wall-clock
  time. Only reminders saved without local fields fall back to `reminder_at`.
- Completion history and progress must group by the completion instant converted
  to the device's local day.

## 4. Behavior rules

- Blank task titles, subtask titles, and list names are rejected.
- Deleting a list, except Inbox, moves its tasks to Inbox in a transaction.
- Deleting a task removes its subtasks and daily focus selections in a
  transaction; foreign keys use cascade as a second line of defense. The delete
  returns a snapshot that can restore the task, subtasks, and focus selections.
- Editing a task reconciles subtasks by id: existing rows are updated, new rows
  are inserted, and removed rows are deleted in one transaction.
- My Top 3 allows at most three distinct incomplete tasks per local date.
  Completed selections stay visible and free active slots. Reopening when three
  other active selections exist removes that selection, not the task. Undo
  restores focus only if capacity permits. Version 2 backups validate this limit.
- Completing a task sets `completed_at`; reopening clears it.
- Progress and history never store counters: completion counts are derived from
  `tasks.completed_at` grouped by the completion instant's local day, so
  reopening a task immediately removes it from those counts.
- The chosen theme mode is the only preference persisted in `settings`;
  notification permission status is read from the platform each time instead.
- `PRAGMA foreign_keys = ON` is applied on every database open.

## 5. Schema versioning and migrations

- The current schema version is `4`.
- `MigrationStrategy.onCreate` creates all tables and seeds Inbox.
- `MigrationStrategy.onUpgrade` applies stepwise migrations:
  - `from < 2` adds the reminder columns (`reminder_date`,
    `reminder_time_minutes`).
  - `from < 3` creates the `settings` table.
  - `from < 4` adds `tasks.sort_order` with default 0 and rebuilds the focus
    table with a non-negative position constraint, preserving rows and indexes.
    Migrations run in a transaction; unknown versions fail before changes.
  - Any unknown upgrade fails fast with
    `UnsupportedError('No migration registered from schema version X to Y.')`.
- Migration tests cover the stored version advancing to the current version,
  the reminder columns arriving for a legacy row, and the settings table being
  created and usable after an upgrade.
- When the schema changes:
  1. Increment `AppDatabase.currentSchemaVersion`.
  2. Add a stepwise `migrator.` migration in `onUpgrade`.
  3. Add a migration test before shipping.
- Reopening an existing database preserves data; this is covered by the file
  persistence test.

## 6. Backup file format

Backups are written as pretty-printed JSON and named
`xenndo-backup-YYYY-MM-DD.json`. Export and restore both go through the system
file dialogs (Storage Access Framework), so no storage permission is used and
only the chosen file is touched.

### Envelope

```json
{
  "format": "xenndo-backup",
  "version": 2,
  "schemaVersion": 4,
  "exportedAt": "2026-10-25T03:27:05.732840Z",
  "data": {
    "lists": [],
    "tasks": [],
    "subtasks": [],
    "focus": [],
    "settings": {}
  }
}
```

- `format` identifies the file before anything else is read.
- `version` is the backup format version. New exports use `2`; both `1` and `2`
  are readable. Version 1 tasks default to manual order `0`; its focus positions
  remain restricted to 0–2. Newer unsupported formats are rejected.
- `schemaVersion` records the database schema the file was produced from. It is
  informational: compatibility is decided by `version`, not by schema version.
- `exportedAt` is the moment of export, in ISO-8601 UTC.

### Payload

| Section | Records | Notable fields |
| --- | --- | --- |
| `lists` | `task_lists` rows | `id`, `name`, `color`, `icon`, `sortOrder`, `isInbox`, timestamps |
| `tasks` | `tasks` rows | `listId`, `priority`, `dueDate`, `dueTimeMinutes`, `isCompleted`, `completedAt`, `reminderDate`, `reminderTimeMinutes`, `reminderAt` |
| `subtasks` | `subtasks` rows | `taskId`, `title`, `isCompleted`, `sortOrder`, timestamps |
| `focus` | `daily_focus_entries` rows | `date`, `taskId`, `sortOrder` |
| `settings` | `settings` rows | only keys listed in `SettingsKeys.exportableKeys` |

Encoding rules:

- Calendar dates (`dueDate`, `reminderDate`, `focus.date`) are `YYYY-MM-DD`
  strings, so they keep their meaning across time zones.
- Instants (`createdAt`, `updatedAt`, `completedAt`, `reminderAt`,
  `exportedAt`) are ISO-8601 UTC timestamps.
- Integers such as `priority`, `dueTimeMinutes`, and `reminderTimeMinutes`
  keep their database meanings and ranges.

Deliberately excluded:

- **Notification ids.** They are assigned by the platform and are not portable,
  so a restore issues fresh ids for every task that carries reminder metadata.
- **Notification permission state.** It is transient device state, read from
  Android on demand and never stored, so it is never exported or restored.
- **`reminder_offset_minutes`.** Legacy column that current releases never
  write; restored rows keep it null.

### Validation

`BackupDocument.decode` validates the whole file before any instance exists,
and the restore only starts for a document that decoded successfully. Errors
name the section, record, and field:

- the file is not JSON, or not a JSON object;
- `format` is missing or belongs to another app;
- `version` is missing or unsupported;
- `schemaVersion` is missing;
- a `data` section is missing or has the wrong shape;
- text fields are empty, numbers fall outside their ranges (`priority` 0-3,
  `dueTimeMinutes`/`reminderTimeMinutes` 0-1439, focus `sortOrder` non-negative (0–2 for legacy format 1)),
  booleans are not booleans, dates are not real `YYYY-MM-DD` dates, or
  instants are not ISO-8601;
- ids repeat within a collection, or a day reuses a Top 3 position;
- a task points at a list that is absent, or a subtask/Top 3 selection points
  at a task that is absent;
- `settings` contains an unknown key or an unreadable `theme_mode` value.

### Restore

1. The file is read and validated with no database access.
2. A preview shows the counts found in the file.
3. After explicit confirmation, one `transaction` deletes focus entries,
   subtasks, tasks, lists, and settings, then inserts the backup rows. A failure
   at any point rolls the whole transaction back, so the previous data stays
   intact.
4. Inbox is seeded if the backup has no inbox list.
5. Fresh notification ids are issued for tasks with reminder metadata.
6. `ReminderReconciler` cancels stale notifications and schedules only
   reminders that are still in the future on this device.

## Phase 9 reliability details

Exports read every table in one transaction. Legacy tasks without a list are
mapped to Inbox in exports/restores. Notification IDs remain platform-specific,
are unique among current task rows, and are reassigned during restore.

Task database commits and Android scheduling outcomes are separate. A scheduling
failure leaves the saved task intact and produces a visible warning; retries
cannot duplicate a successful save. Disabling a reminder cancels the prior ID
before dropping its metadata. Platform updates serialize against reconciliation;
permission denial retains definitions without scheduling notifications. Startup
and resume failures are caught and can retry at the next resume.

Default list sorting puts incomplete tasks first, then priority, due date/time
and stable IDs. Explicit manual ordering overrides that default within a list.
Today and Upcoming use local date groups; Upcoming sorts dates chronologically.
Due dates are calendar dates; stored local reminder date/time is re-resolved on
resume after a timezone change. The overdue view refreshes every local minute.
