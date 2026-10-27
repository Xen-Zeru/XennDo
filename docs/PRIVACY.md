# XennDo privacy statement

Draft for owner review before publication; updated 2026-10-26.

XennDo is a personal task planner that works offline. It does not require an
account. The app contains no advertising, analytics, tracking or cloud-sync SDK,
and it does not send task data to a XennDo server.

Tasks, notes, lists, subtasks, completion timestamps, daily focus selections,
reminder definitions and appearance preferences are stored in the app's private
local SQLite database. The app does not add its own database encryption layer.
Android's device security and backup-file handling remain important.

Notifications are optional. Android permission is requested when enabling a
reminder or through Settings. Task titles and notes can appear in reminder
notifications; the device's notification and lock-screen settings control their
visibility. Android may delay reminders. Denial does not prevent using tasks.

You can explicitly export all your app data through Android's save dialog.
Backups are readable JSON, are not encrypted and may contain personal notes.
Choose a private location. If you choose a third-party or cloud storage provider,
that provider handles the selected file under its own policies. XennDo does not
operate that storage service. Automatic Android cloud backup and device transfer
are disabled by the app's backup configuration.

Restore reads the backup you select, validates it and requests confirmation
before replacing the destination app's entire data set. Deleting tasks removes
them from the local database; existing exported files are separate copies that
you must manage/delete yourself. Uninstalling an app removes its private data;
export before uninstalling if you want to keep it.

No contacts, location, photo library or broad storage access is needed. Scoped
file access is granted by the system picker. Android and your chosen document
provider may process information independently of XennDo.

Before publishing, the owner must add a real privacy contact and host the final
statement at a public URL. No contact address or URL has been invented here.
