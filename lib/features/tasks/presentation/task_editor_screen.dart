import 'package:xenndo/features/reminders/presentation/reminder_platform_text.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/features/tasks/presentation/task_deletion_notice.dart';
import 'package:xenndo/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

class TaskEditorInitialValues {
  const TaskEditorInitialValues({
    required this.title,
    this.taskId,
    this.description = '',
    this.listId,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.dueTimeMinutes,
    this.reminderEnabled = false,
    this.reminderDate,
    this.reminderTimeMinutes,
    this.subtasks = const [],
  });

  final String? taskId;
  final String title;
  final String description;
  final String? listId;
  final TaskPriority priority;
  final LocalDate? dueDate;
  final int? dueTimeMinutes;
  final bool reminderEnabled;
  final LocalDate? reminderDate;
  final int? reminderTimeMinutes;
  final List<SubtaskDraft> subtasks;
}

class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({
    super.key,
    this.taskId,
    this.initialListId,
    this.initialValues,
  });

  final String? taskId;
  final String? initialListId;
  final TaskEditorInitialValues? initialValues;

  bool get isEditing => taskId != null || initialValues?.taskId != null;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final List<_EditableSubtask> _subtasks = [];

  late String? _listId;
  late TaskPriority _priority;
  LocalDate? _dueDate;
  int? _dueTimeMinutes;
  late bool _reminderEnabled;
  LocalDate? _reminderDate;
  int? _reminderTimeMinutes;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _allowPop = false;
  bool _confirmingDiscard = false;
  int _nextSubtaskKey = 0;

  String? get _taskId => widget.taskId ?? widget.initialValues?.taskId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValues;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _listId = initial?.listId ?? widget.initialListId;
    _priority = initial == null || initial.priority == TaskPriority.none
        ? TaskPriority.medium
        : initial.priority;
    _dueDate = initial?.dueDate;
    _dueTimeMinutes = initial?.dueTimeMinutes;
    _reminderEnabled = initial?.reminderEnabled ?? false;
    _reminderDate = initial?.reminderDate;
    _reminderTimeMinutes = initial?.reminderTimeMinutes;

    for (final subtask in initial?.subtasks ?? const <SubtaskDraft>[]) {
      _subtasks.add(
        _EditableSubtask(
          localKey: 'subtask-${_nextSubtaskKey++}',
          id: subtask.id,
          title: subtask.title,
          isCompleted: subtask.isCompleted,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final subtask in _subtasks) {
      subtask.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);

    return PopScope<Object?>(
      canPop: _allowPop || (!_hasUnsavedChanges && !_isSaving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSaving) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        key: const ValueKey('task-editor-screen'),
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit task' : 'Add task'),
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _isSaving ? null : _handleClose,
            icon: const Icon(Icons.close_rounded),
          ),
          actions: [
            if (widget.isEditing)
              IconButton(
                key: const ValueKey('delete-task-action'),
                tooltip: 'Delete task',
                onPressed: _isSaving ? null : _deleteTask,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: lists.when(
                  data: (availableLists) {
                    if (availableLists.isEmpty) {
                      return const AppErrorState(
                        title: 'No lists available',
                        message:
                            'The database did not return any lists to select.',
                      );
                    }
                    return _buildForm(context, availableLists);
                  },
                  loading: () =>
                      const AppLoadingState(message: 'Preparing the form...'),
                  error: (error, stackTrace) => AppErrorState(
                    title: 'Could not load lists',
                    message: 'Lists could not be read from the database.',
                    onRetry: () => ref.invalidate(listsProvider),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('save-task-button'),
                    onPressed: _isSaving || !lists.hasValue ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : widget.isEditing
                          ? 'Save changes'
                          : 'Save task',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<TaskListModel> lists) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedListId = _selectedListId(lists);

    return AbsorbPointer(
      absorbing: _isSaving,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('task-title-field'),
                controller: _titleController,
                autofocus: !widget.isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                onChanged: (_) => _markUnsaved(),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs doing?',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a task title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                key: const ValueKey('task-list-field'),
                initialValue: selectedListId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'List',
                  prefixIcon: Icon(Icons.list_alt_outlined),
                ),
                items: [
                  for (final list in lists)
                    DropdownMenuItem(value: list.id, child: Text(list.name)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _listId = value;
                      _hasUnsavedChanges = true;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Priority',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final priority in TaskPriority.selectable)
                    ChoiceChip(
                      key: ValueKey('priority-${priority.name}'),
                      label: Text(priority.label),
                      selected: _priority == priority,
                      onSelected: (_) {
                        setState(() {
                          _priority = priority;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FormField<void>(
                validator: (_) => _reminderValidation(),
                builder: (field) => field.hasError
                    ? Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ExpansionTile(
                key: const ValueKey('task-schedule-section'),
                expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : const AnimationStyle(
                        duration: Duration(milliseconds: 200),
                      ),
                initiallyExpanded: _dueDate != null || _reminderEnabled,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Due date and reminder'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Optional'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_dueDate!.toLocalDateTime()),
                ),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditorFieldTile(
                            key: const ValueKey('due-date-tile'),
                            icon: Icons.calendar_today_outlined,
                            label: 'Due date',
                            value: _dueDate == null
                                ? 'Not set'
                                : MaterialLocalizations.of(context)
                                      .formatMediumDate(
                                        _dueDate!.toLocalDateTime(),
                                      ),
                            onTap: _pickDueDate,
                            onClear: _dueDate == null
                                ? null
                                : () {
                                    setState(() {
                                      _dueDate = null;
                                      _dueTimeMinutes = null;
                                      _hasUnsavedChanges = true;
                                    });
                                  },
                          ),
                          if (_dueDate != null) ...[
                            const Divider(height: AppSpacing.xxl),
                            _EditorFieldTile(
                              key: const ValueKey('due-time-tile'),
                              icon: Icons.schedule_outlined,
                              label: 'Due time',
                              value: _dueTimeMinutes == null
                                  ? 'Not set'
                                  : MaterialLocalizations.of(
                                      context,
                                    ).formatTimeOfDay(
                                      TimeOfDay(
                                        hour:
                                            _dueTimeMinutes! ~/
                                            Duration.minutesPerHour,
                                        minute:
                                            _dueTimeMinutes! %
                                            Duration.minutesPerHour,
                                      ),
                                      alwaysUse24HourFormat:
                                          MediaQuery.alwaysUse24HourFormatOf(
                                            context,
                                          ),
                                    ),
                              onTap: _pickDueTime,
                              onClear: _dueTimeMinutes == null
                                  ? null
                                  : () {
                                      setState(() {
                                        _dueTimeMinutes = null;
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          SwitchListTile(
                            key: const ValueKey('reminder-switch'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reminder'),
                            subtitle: Text(
                              _reminderEnabled
                                  ? (_reminderHasPassed
                                        ? 'This reminder time has passed. Choose a new time to schedule it again.'
                                        : ref
                                                  .watch(
                                                    notificationPermissionProvider,
                                                  )
                                                  .value ==
                                              ReminderPermissionStatus.granted
                                        ? 'Reminder enabled. Delivery may be delayed.'
                                        : 'Not scheduled while notifications are off. Check Settings.')
                                  : 'No reminder set.',
                            ),
                            value: _reminderEnabled,
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    if (value) {
                                      _enableReminder();
                                    } else {
                                      setState(() {
                                        _reminderEnabled = false;
                                        _hasUnsavedChanges = true;
                                      });
                                    }
                                  },
                          ),
                          if (_reminderEnabled) ...[
                            const Divider(height: AppSpacing.xxl),
                            _EditorFieldTile(
                              key: const ValueKey('reminder-date-tile'),
                              icon: Icons.event_available_outlined,
                              label: 'Reminder date',
                              value: _reminderDate == null
                                  ? 'Not set'
                                  : MaterialLocalizations.of(context)
                                        .formatMediumDate(
                                          _reminderDate!.toLocalDateTime(),
                                        ),
                              onTap: _pickReminderDate,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _EditorFieldTile(
                              key: const ValueKey('reminder-time-tile'),
                              icon: Icons.alarm_outlined,
                              label: 'Reminder time',
                              value: _reminderTimeMinutes == null
                                  ? 'Not set'
                                  : MaterialLocalizations.of(
                                      context,
                                    ).formatTimeOfDay(
                                      TimeOfDay(
                                        hour:
                                            _reminderTimeMinutes! ~/
                                            Duration.minutesPerHour,
                                        minute:
                                            _reminderTimeMinutes! %
                                            Duration.minutesPerHour,
                                      ),
                                      alwaysUse24HourFormat:
                                          MediaQuery.alwaysUse24HourFormatOf(
                                            context,
                                          ),
                                    ),
                              onTap: _pickReminderTime,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              ReminderPlatformText.deliveryExplanation(
                                theme.platform,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ExpansionTile(
                key: const ValueKey('task-description-section'),
                expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : const AnimationStyle(
                        duration: Duration(milliseconds: 200),
                      ),
                initiallyExpanded: _descriptionController.text.isNotEmpty,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Description'),
                subtitle: Text(
                  _descriptionController.text.isEmpty
                      ? 'Add notes (optional)'
                      : 'Notes added',
                ),
                children: [
                  TextFormField(
                    key: const ValueKey('task-description-field'),
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 5,
                    onChanged: (_) => _markUnsaved(),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Add notes or context (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ExpansionTile(
                key: const ValueKey('task-subtasks-section'),
                expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : const AnimationStyle(
                        duration: Duration(milliseconds: 200),
                      ),
                initiallyExpanded: _subtasks.isNotEmpty,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Subtasks'),
                subtitle: Text(
                  _subtasks.isEmpty
                      ? 'Optional'
                      : '${_subtasks.length} ${_subtasks.length == 1 ? 'step' : 'steps'}',
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('add-subtask-button'),
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add subtask'),
                    ),
                  ),
                  if (_subtasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        'Add steps to break this task down.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var index = 0; index < _subtasks.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _SubtaskEditor(
                        key: ValueKey(_subtasks[index].localKey),
                        index: index,
                        subtask: _subtasks[index],
                        canMoveUp: index > 0,
                        canMoveDown: index < _subtasks.length - 1,
                        onToggle: (value) {
                          setState(() {
                            _subtasks[index].isCompleted = value;
                            _hasUnsavedChanges = true;
                          });
                        },
                        onEdited: _markUnsaved,
                        onMoveUp: () => _moveSubtask(index, index - 1),
                        onMoveDown: () => _moveSubtask(index, index + 1),
                        onDelete: () => _removeSubtask(index),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _selectedListId(List<TaskListModel> lists) {
    final current = _listId;
    if (current != null && lists.any((list) => list.id == current)) {
      return current;
    }
    for (final list in lists) {
      if (list.isInbox) {
        return list.id;
      }
    }
    return lists.first.id;
  }

  bool get _reminderHasPassed {
    final date = _reminderDate;
    final minutes = _reminderTimeMinutes;
    return date != null &&
        minutes != null &&
        !date
            .toLocalDateTime(hour: minutes ~/ 60, minute: minutes % 60)
            .isAfter(DateTime.now());
  }

  String? _reminderValidation() {
    if (!_reminderEnabled) {
      return null;
    }
    if (_reminderDate == null || _reminderTimeMinutes == null) {
      return 'Choose a reminder date and time.';
    }
    final initial = widget.initialValues;
    final unchanged =
        widget.isEditing &&
        initial?.reminderEnabled == true &&
        _reminderDate == initial?.reminderDate &&
        _reminderTimeMinutes == initial?.reminderTimeMinutes;
    if (_reminderHasPassed && !unchanged) {
      return 'Choose a future reminder date and time.';
    }
    return null;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate?.toLocalDateTime() ?? now;
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
      helpText: 'Select due date',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dueDate = LocalDate.fromDateTime(picked);
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickDueTime() async {
    final initial = _dueTimeMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(
              hour: initial ~/ Duration.minutesPerHour,
              minute: initial % Duration.minutesPerHour,
            ),
      helpText: 'Select due time',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dueTimeMinutes = picked.hour * Duration.minutesPerHour + picked.minute;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _enableReminder() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final ReminderPermissionStatus status;
    try {
      final current = await scheduler.checkPermission();
      status = current == ReminderPermissionStatus.requestable
          ? await scheduler.requestPermission()
          : current;
      if (mounted) ref.invalidate(notificationPermissionProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not check notification permission. Try again.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }

    if (status == ReminderPermissionStatus.denied ||
        status == ReminderPermissionStatus.requestable) {
      await _showPermissionDeniedDialog();
      return;
    }
    if (status != ReminderPermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications are not available on this device.'),
        ),
      );
      return;
    }

    final defaultDateTime = DateTime.now().add(const Duration(hours: 1));
    setState(() {
      _reminderEnabled = true;
      _hasUnsavedChanges = true;
      _reminderDate ??= _dueDate ?? LocalDate.fromDateTime(defaultDateTime);
      _reminderTimeMinutes ??=
          _dueTimeMinutes ??
          defaultDateTime.hour * Duration.minutesPerHour +
              defaultDateTime.minute;
    });
  }

  Future<void> _showPermissionDeniedDialog() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Notifications are off'),
        content: Text(
          'XennDo needs notification permission to remind you. You can turn it on in ${ReminderPlatformText.settingsName(Theme.of(context).platform)}. Without it, the reminder cannot be delivered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const ValueKey('open-notification-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      try {
        final opened = await ref
            .read(reminderSchedulerProvider)
            .openNotificationSettings();
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ReminderPlatformText.settingsInstructions(
                  Theme.of(context).platform,
                ),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open system settings.')),
          );
        }
      }
    }
  }

  Future<void> _pickReminderDate() async {
    final now = DateTime.now();
    final initial = _reminderDate?.toLocalDateTime() ?? now;
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
      helpText: 'Select reminder date',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _reminderDate = LocalDate.fromDateTime(picked);
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickReminderTime() async {
    final initial = _reminderTimeMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(
              hour: initial ~/ Duration.minutesPerHour,
              minute: initial % Duration.minutesPerHour,
            ),
      helpText: 'Select reminder time',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _reminderTimeMinutes =
          picked.hour * Duration.minutesPerHour + picked.minute;
      _hasUnsavedChanges = true;
    });
  }

  void _addSubtask() {
    setState(() {
      _subtasks.add(_EditableSubtask(localKey: 'subtask-${_nextSubtaskKey++}'));
      _hasUnsavedChanges = true;
    });
  }

  void _removeSubtask(int index) {
    final removed = _subtasks.removeAt(index);
    removed.controller.dispose();
    setState(() => _hasUnsavedChanges = true);
  }

  void _moveSubtask(int from, int to) {
    if (to < 0 || to >= _subtasks.length) {
      return;
    }
    setState(() {
      final moved = _subtasks.removeAt(from);
      _subtasks.insert(to, moved);
      _hasUnsavedChanges = true;
    });
  }

  void _markUnsaved() {
    if (_hasUnsavedChanges) {
      return;
    }
    setState(() => _hasUnsavedChanges = true);
  }

  void _handleClose() {
    if (_hasUnsavedChanges) {
      _confirmDiscard();
    } else {
      _popEditor();
    }
  }

  Future<void> _confirmDiscard() async {
    if (!_hasUnsavedChanges || !mounted || _confirmingDiscard || _isSaving) {
      return;
    }
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved task changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _confirmingDiscard = false;
    if (discard == true && mounted) {
      _popEditor();
    }
  }

  void _popEditor([bool? saved]) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(saved);
      } else {
        // Direct routes and notification launches must never pop the last page.
        GoRouter.maybeOf(context)?.goNamed('today');
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      final invalidField = _formKey.currentState!.fields.firstWhere(
        (field) => field.hasError,
      );
      FocusScope.of(context).unfocus();
      Scrollable.ensureVisible(
        invalidField.context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
      return;
    }

    final reminderError = _reminderValidation();
    if (reminderError != null) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reminderError)));
      return;
    }
    final lists = ref.read(listsProvider).value ?? const <TaskListModel>[];
    if (lists.isEmpty) {
      return;
    }

    if (_reminderEnabled) {
      final defaultDateTime = DateTime.now().add(const Duration(hours: 1));
      _reminderDate ??= _dueDate ?? LocalDate.fromDateTime(defaultDateTime);
      _reminderTimeMinutes ??=
          _dueTimeMinutes ??
          defaultDateTime.hour * Duration.minutesPerHour +
              defaultDateTime.minute;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final draft = TaskDraft(
      title: _titleController.text,
      description: _descriptionController.text,
      listId: _selectedListId(lists),
      priority: _priority,
      dueDate: _dueDate,
      dueTimeMinutes: _dueTimeMinutes,
      reminderEnabled: _reminderEnabled,
      reminderDate: _reminderDate,
      reminderTimeMinutes: _reminderTimeMinutes,
      subtasks: [
        for (final subtask in _subtasks)
          SubtaskDraft(
            id: subtask.id,
            title: subtask.controller.text,
            isCompleted: subtask.isCompleted,
          ),
      ],
    );

    try {
      final repository = ref.read(taskRepositoryProvider);
      final taskId = _taskId;
      if (taskId != null) {
        await repository.updateTask(taskId, draft);
      } else {
        await repository.createTask(draft);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Task updated.' : 'Task added.'),
        ),
      );
      _popEditor(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this task. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteTask() async {
    final taskId = _taskId;
    if (taskId == null) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final repository = ref.read(taskRepositoryProvider);

    try {
      final snapshot = await repository.deleteTaskWithSnapshot(taskId);
      if (!mounted) {
        return;
      }
      showTaskDeletionNotice(
        ScaffoldMessenger.of(context),
        repository,
        snapshot,
      );
      _popEditor(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this task. Please try again.'),
        ),
      );
    }
  }
}

class _EditableSubtask {
  _EditableSubtask({
    required this.localKey,
    this.id,
    String title = '',
    this.isCompleted = false,
  }) : controller = TextEditingController(text: title);

  final String localKey;
  final String? id;
  final TextEditingController controller;
  bool isCompleted;
}

class _SubtaskEditor extends StatelessWidget {
  const _SubtaskEditor({
    required this.index,
    required this.subtask,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onEdited,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    super.key,
  });

  final int index;
  final _EditableSubtask subtask;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdited;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: ValueKey('subtask-checkbox-$index'),
                value: subtask.isCompleted,
                onChanged: (value) => onToggle(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: TextFormField(
                    key: ValueKey('subtask-field-$index'),
                    controller: subtask.controller,
                    onChanged: (_) => onEdited(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Subtask ${index + 1}',
                      isDense: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a subtask title.';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                IconButton(
                  key: ValueKey('subtask-up-$index'),
                  tooltip: 'Move subtask ${index + 1} up',
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  key: ValueKey('subtask-down-$index'),
                  tooltip: 'Move subtask ${index + 1} down',
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  key: ValueKey('subtask-delete-$index'),
                  tooltip: 'Delete subtask ${index + 1}',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorFieldTile extends StatelessWidget {
  const _EditorFieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(AppRadii.md);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
