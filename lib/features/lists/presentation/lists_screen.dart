import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/core/widgets/page_heading.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';

const _listColors = <int>[
  0xFF006B5F,
  0xFF2F6FED,
  0xFF9A6700,
  0xFFB3261E,
  0xFF6A4FB6,
  0xFF0F7B8A,
];

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listSummariesProvider);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('lists-screen'),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeading(
              title: 'My lists',
              actions: [
                FilledButton.tonalIcon(
                  key: const ValueKey('create-list-action'),
                  onPressed: () => _createList(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 24),
                  label: const Text('New list'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              0,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  lists.when(
                    data: (value) {
                      if (value.isEmpty) {
                        return AppErrorState(
                          title: 'Inbox unavailable',
                          message: 'Your lists could not be loaded.',
                          onRetry: () => ref.invalidate(listSummariesProvider),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, list) in value.indexed) ...[
                            _ListCard(
                              list: list,
                              onMoveUp: !list.isInbox && index > 1
                                  ? () => _moveList(
                                      context,
                                      ref,
                                      value,
                                      index,
                                      index - 1,
                                    )
                                  : null,
                              onMoveDown:
                                  !list.isInbox && index < value.length - 1
                                  ? () => _moveList(
                                      context,
                                      ref,
                                      value,
                                      index,
                                      index + 1,
                                    )
                                  : null,
                              onOpen: () => context.pushNamed(
                                'listDetail',
                                pathParameters: {'listId': list.id},
                              ),
                              onRename: () => _renameList(context, ref, list),
                              onRecolor: () => _recolorList(context, ref, list),
                              onDelete: list.isInbox
                                  ? null
                                  : () => _deleteList(context, ref, list),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      );
                    },
                    loading: () =>
                        const AppLoadingState(message: 'Loading your lists...'),
                    error: (error, stackTrace) => AppErrorState(
                      title: 'Could not load lists',
                      message:
                          'Your lists could not be read from the database.',
                      onRetry: () => ref.invalidate(listSummariesProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveList(
    BuildContext context,
    WidgetRef ref,
    List<TaskListSummary> lists,
    int from,
    int to,
  ) async {
    final ids = lists.map((list) => list.id).toList();
    ids.insert(to, ids.removeAt(from));
    try {
      await ref.read(listRepositoryProvider).reorderLists(ids);
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not reorder lists.');
    }
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final result = await showListFormDialog(
      context,
      title: 'Create list',
      confirmLabel: 'Create',
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(listRepositoryProvider)
          .createList(name: result.name, color: result.color);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not create the list. Please try again.');
      }
    }
  }

  Future<void> _renameList(
    BuildContext context,
    WidgetRef ref,
    TaskListSummary list,
  ) async {
    final result = await showListFormDialog(
      context,
      title: 'Rename list',
      confirmLabel: 'Save',
      initialName: list.name,
      initialColor: list.color,
      showColors: false,
    );
    if (result == null) {
      return;
    }

    try {
      await ref.read(listRepositoryProvider).renameList(list.id, result.name);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not rename the list. Please try again.');
      }
    }
  }

  Future<void> _recolorList(
    BuildContext context,
    WidgetRef ref,
    TaskListSummary list,
  ) async {
    final result = await showListFormDialog(
      context,
      title: 'Change list color',
      confirmLabel: 'Save',
      initialName: list.name,
      initialColor: list.color,
      showName: false,
    );
    if (result == null) {
      return;
    }

    try {
      await ref.read(listRepositoryProvider).recolorList(list.id, result.color);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not update the list color.');
      }
    }
  }

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    TaskListSummary list,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('Delete ${list.name}?'),
        content: const Text(
          'Tasks in this list will move to Inbox. No tasks will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-list'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete list'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(listRepositoryProvider).deleteList(list.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${list.name} deleted. Tasks moved to Inbox.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not delete the list. Please try again.');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class ListFormResult {
  const ListFormResult({required this.name, required this.color});

  final String name;
  final int color;
}

Future<ListFormResult?> showListFormDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  int? initialColor,
  bool showName = true,
  bool showColors = true,
}) {
  return showDialog<ListFormResult>(
    context: context,
    builder: (dialogContext) => _ListFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialColor: initialColor ?? _listColors.first,
      showName: showName,
      showColors: showColors,
    ),
  );
}

class _ListFormDialog extends StatefulWidget {
  const _ListFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialColor,
    required this.showName,
    required this.showColors,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final int initialColor;
  final bool showName;
  final bool showColors;

  @override
  State<_ListFormDialog> createState() => _ListFormDialogState();
}

class _ListFormDialogState extends State<_ListFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showName)
              TextFormField(
                key: const ValueKey('list-name-field'),
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  hintText: 'Work, Personal, Errands...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a list name.';
                  }
                  return null;
                },
              ),
            if (widget.showColors) ...[
              if (widget.showName) const SizedBox(height: AppSpacing.lg),
              Text(
                'Color',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final color in _listColors)
                    _ColorOption(
                      key: ValueKey('list-color-$color'),
                      color: color,
                      selected: _color == color,
                      onTap: () => setState(() => _color = color),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-list-form'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              ListFormResult(
                name: widget.showName
                    ? _nameController.text.trim()
                    : widget.initialName,
                color: _color,
              ),
            );
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Select list color',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(color),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.onOpen,
    required this.onRename,
    required this.onRecolor,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final TaskListSummary list;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onRecolor;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storedAccent = Color(list.color);
    final accent = theme.brightness == Brightness.dark
        ? Color.lerp(storedAccent, Colors.white, 0.45)!
        : storedAccent;
    final borderRadius = BorderRadius.circular(AppRadii.lg);

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(_iconFor(list), size: 34, color: accent),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      list.openTaskCount == 1
                          ? '1 open task'
                          : '${list.openTaskCount} open tasks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Tooltip(
                      message: list.totalTaskCount == 0
                          ? 'No tasks in this list'
                          : '${list.completedTaskCount} of ${list.totalTaskCount} tasks complete',
                      child: Semantics(
                        label: list.totalTaskCount == 0
                            ? 'No tasks in this list'
                            : '${list.completedTaskCount} of ${list.totalTaskCount} tasks complete',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: list.completionFraction,
                            minHeight: 8,
                            backgroundColor: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('list-menu-${list.id}'),
                tooltip: '${list.name} options',
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'up':
                      onMoveUp?.call();
                    case 'down':
                      onMoveDown?.call();
                    case 'open':
                      onOpen();
                    case 'rename':
                      onRename();
                    case 'recolor':
                      onRecolor();
                    case 'delete':
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('Open list')),
                  if (onMoveUp != null)
                    const PopupMenuItem(value: 'up', child: Text('Move up')),
                  if (onMoveDown != null)
                    const PopupMenuItem(
                      value: 'down',
                      child: Text('Move down'),
                    ),
                  const PopupMenuItem(
                    key: ValueKey('list-rename'),
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem(
                    key: ValueKey('list-recolor'),
                    value: 'recolor',
                    child: Text('Change color'),
                  ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      key: ValueKey('list-delete'),
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(TaskListSummary list) {
    return switch (list.icon) {
      'inbox' => Icons.inbox_rounded,
      'work' => Icons.work_outline_rounded,
      'school' || 'education' => Icons.school_rounded,
      'person' || 'personal' => Icons.home_rounded,
      'shopping' || 'shopping_bag' || 'errands' => Icons.shopping_bag_outlined,
      _ => list.isInbox ? Icons.inbox_outlined : Icons.folder_rounded,
    };
  }
}
