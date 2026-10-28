# XennDo - Product Specification

**Tagline:** Plan your day. Get it done.

**Status:** Initial-scope implementation and Phase 8.5 UI refinement are implemented.
Phase 9 audits and Android release preparation are recorded in
`docs/PROGRESS.md`; signing, physical-device qualification and store publication
remain separate owner-controlled gates in `docs/RELEASE_CHECKLIST.md`.

**Last updated:** 2026-10-28

## 1. Product overview

XennDo is an offline-first personal to-do application for Android and iOS. It is
designed for people who want a fast, private daily planner without an account,
subscription, backend, or cloud dependency.

The core promise is simple:

1. Capture what needs doing.
2. Decide what matters today.
3. Get it done.

Working data is stored locally in private app storage. Explicit backup exports
can leave that storage through a user-selected document provider.

## 2. Goals

- Provide a zero-friction first-run experience with no sign-up.
- Make quick capture and task organization fast.
- Support deliberate daily planning through Today, Upcoming, and My Top 3.
- Keep tasks visible and actionable with priorities, due dates, and reminders.
- Preserve user confidence through clear completion history and local backup.
- Respect privacy by default: no account, telemetry, cloud sync, or AI.
- Deliver a responsive, accessible Material 3 mobile experience.
- Extend the verified Android implementation to iOS; native iOS qualification
  remains pending Mac/Xcode and physical-device checks in `IOS_SETUP.md`.

## 3. Non-goals for the initial version

The following are explicitly excluded until the initial version is complete:

- Recurring tasks
- Habits
- Focus timer
- Home-screen or lock-screen widgets
- Collaboration, sharing, or assignment
- Cloud sync or multi-device sync
- Accounts, authentication, backend services
- AI-generated suggestions or summaries
- Web, desktop, or tablet-specific release support
- Calendar integration

## 4. Target user and core use cases

**Primary user:** An individual planning personal tasks on an Android or iOS phone who
values speed, privacy, and a small feature set.

Core use cases:

- Quickly add a task and optionally assign it to a list.
- Plan a day by reviewing due and overdue work in Today.
- Choose up to three priority tasks for the day in My Top 3.
- Break a larger task into subtasks.
- Schedule a one-time local reminder for a task.
- Find a task by text, list, priority, status, or due date.
- Review recently completed work.
- Export and restore a local backup after changing devices or reinstalling.

## 5. Functional requirements

### 5.1 Lists

- A default list named **Inbox** exists on first launch.
- Users can create, rename, reorder, and delete custom lists.
- Inbox cannot be deleted.
- Deleting a custom list moves its tasks to Inbox rather than deleting them.
- Each task belongs to exactly one list in the initial version.
- Lists show an open-task count.

### 5.2 Tasks

- A task requires a non-empty title.
- Optional fields: notes, list, priority, due date, due time, reminder.
- Priority values shown to users: high, medium, and low. Medium is the default.
- Due dates are optional. A time can be attached to a due date.
- Tasks can be marked complete and reopened.
- Completed tasks retain a completion timestamp.
- Tasks record created and last-updated timestamps.
- Deleting a task requires confirmation and removes its subtasks and reminder.
- Users can reorder tasks within a list or day view where practical.
- Task titles and notes are searchable.

### 5.3 Subtasks

- A task can have zero or more subtasks.
- Each subtask has a title, completion state, and manual order.
- Subtask completion is independent of parent completion.
- Parent task cards may show subtask progress (for example, 2 of 3 done).
- Completing a parent task does not automatically delete or complete subtasks.

### 5.4 Due dates and priorities

- Due dates use the device's local calendar date.
- Optional due times use the device's local time zone.
- Overdue means due before the current local day, or due earlier today when a
  time is set.
- Date-only deadlines are stored as a calendar date so they retain the selected
  date across time zones. Timed deadlines store a local wall-clock time and may
  shift absolutely when the device time zone changes. Reminders are stored as
  absolute instants. See `docs/DATA_MODEL.md`.
- Sorting defaults: incomplete before complete, then priority, then due time,
  then manual order.

### 5.5 Today

- Today shows incomplete tasks that are due today or overdue.
- Completed tasks may be revealed in a separate completed section.
- Today includes access to My Top 3.
- Overdue tasks are clearly distinguished from tasks due today.
- An empty state explains how to add a task or plan the day.

### 5.6 Upcoming

- Upcoming groups incomplete tasks with future due dates by day.
- The view starts with tomorrow and supports browsing later dates.
- Tasks without due dates are not included.

### 5.7 My Top 3

- Users can select up to three incomplete tasks as their Top 3 for the day.
- Selections are unique and remain associated with that local day.
- Users can replace or remove a selection at any time.
- Completed Top 3 tasks remain visible as completed for the day, but no longer
  occupy an active slot.
- My Top 3 is visible from Today and must be fast to update.

### 5.8 Search and filters

- Search matches task titles and descriptions. Subtask title search is deferred
  beyond the initial search release.
- Search results update as the query changes.
- Filters include list, priority, completion status, and due-date range.
- Multiple filters can be combined and are clearly indicated when active.
- Clearing search and filters restores the unfiltered result set.

### 5.9 Completion history

- Completion timestamps are retained when a task is completed.
- A history view groups completed tasks by local day.
- Reopening a task removes its completion timestamp.
- Users can view recent completion history but are not required to keep an
  indefinite audit log.

### 5.10 Reminders

- Reminders are local, one-time notifications associated with a task.
- A reminder requires a future date and time.
- Users can edit or remove a reminder before it fires.
- Notification permission is requested in context, with an explanation.
- Denying permission does not prevent task use; the reminder remains clearly
  marked as not scheduled.
- Reminders are scheduled in the device time zone and survive app restarts.
- Completing or deleting a task cancels its pending reminder.
- Tapping a reminder opens the associated task.
- Exact-alarm capability is used when available; otherwise the app requests
  the closest supported scheduling behavior and explains any limitation.

### 5.11 Progress

- Progress summarizes completed work for today and the last seven days.
- Progress must be derived from completion timestamps, not a separate mutable
  counter.
- Empty and low-data states remain useful and non-judgmental.

### 5.12 Settings

- Theme preference: system, light, or dark.
- Reminder permission status and a shortcut to system notification settings.
- Backup and restore entry points.
- Compact About row showing only the installed version (no parenthesized build).
- Dedicated About XennDo page with the app description, offline/data-control
  information, actual version/build metadata, Xenn Jan developer credit, and a
  link to Flutter’s open-source license page.
- Settings are persisted locally.

### 5.13 Backup and restore

- Users can export all app data to a versioned JSON backup file.
- Export uses the platform document save flow and makes clear that the file is not
  encrypted.
- Import validates the file before changing data.
- Import shows a summary and asks for confirmation before replacing local data.
- Invalid or unsupported backups fail safely without partial data loss.
- Backup includes lists, tasks, subtasks, reminder metadata, Top 3 selections,
  and settings required to reconstruct the app state.
- Restore reschedules valid future reminders.

## 6. Information model

Conceptual entities:

**List**

- Stable ID
- Name
- Sort order
- Created/updated timestamps
- Protected Inbox flag

**Task**

- Stable ID
- List ID
- Title, optional notes
- Priority
- Optional due date and time
- Reminder timestamp/state
- Completion timestamp
- Manual sort order
- Top 3 date, when selected
- Created/updated timestamps

**Subtask**

- Stable ID
- Parent task ID
- Title
- Completion state
- Manual sort order
- Created/updated timestamps

**Settings**

- Theme preference
- Notification preference state
- Schema/version metadata

IDs must be generated on-device (UUID or equivalent) and must not depend on a
server. Schema migrations must preserve existing user data.

## 7. UX and visual direction

- Material 3 with a calm, focused teal-based color system.
- Clear light and dark themes following the system by default.
- Primary navigation destinations: Today, Upcoming, Lists, and Settings.
- A persistent Add Task action on task screens; Settings has no Add Task action.
- Progress is reachable from Today. Search is an in-screen task tool when
  implemented in Phase 5 rather than a primary navigation destination.
- Task rows prioritize title, completion control, due state, priority, and list.
- Destructive actions require confirmation or provide undo.
- Empty states explain the next useful action rather than only stating that a
  list is empty.
- Touch targets are at least 48 dp; text scales without clipping core actions.
- Color is never the sole indicator of priority, overdue state, or completion.

## 8. Non-functional requirements

### Offline and privacy

- Core functionality works with no network connection.
- No account, backend, analytics, crash-reporting SDK, ads, or AI service.
- Working data remains in private app storage; explicit export/provider sharing
  and iOS device/iCloud backups may create copies outside it. Android automatic
  backup exclusions remain. See `PRIVACY.md` and `IOS_SETUP.md`.

### Performance

- Cold start reaches an interactive Today screen quickly on a mid-range device.
- Scrolling remains smooth with at least 5,000 tasks.
- Search and filter operations are responsive for the supported data volume.
- Database queries are indexed for due date, completion, list, and priority.

### Reliability

- Database migrations are tested.
- Reminder scheduling is idempotent and can be reconciled at startup.
- Backup import is transactional.
- The app handles permission denial and unavailable notification services
  gracefully.

### Accessibility

- Semantic labels for icon-only actions.
- Keyboard/focus support where relevant.
- Sufficient contrast in both themes.
- Respects system text scaling and reduced-motion settings where practical.

### Localization

- English is the initial language.
- User-facing strings should be kept extractable for later localization.

## 9. Release requirements

- Final application ID and namespace: `com.xennzeru.xenndo`; display name XennDo.
  The old `com.example.xenndo` installation has separate private storage.
- Configure production signing; never publish debug-signed artifacts.
- Provide a production launcher icon and splash screen.
- Review notification permissions and exact-alarm policy declarations.
- Complete Android release qualification on supported API levels.
- iOS uses the same `com.xennzeru.xenndo` identity; owner-selected Apple signing,
  Mac/Xcode builds and physical-iPhone qualification are tracked in `IOS_SETUP.md`.
- Verify backup and restore on a clean install.
- Publish a privacy policy consistent with the no-account, local-first design.

## 10. Success criteria for the initial version

- A user can install the app, create lists and tasks, and use the app entirely
  offline without creating an account.
- Today, Upcoming, My Top 3, search, and filters produce correct results after
  app restarts.
- Reminders fire at the selected local time when permission is granted.
- Completion history and progress reflect actual completion timestamps.
- A backup can be exported, imported on a clean install, and verified.
- Light and dark themes both meet accessibility checks.
- Formatting, static analysis, tests, and release build checks pass.
