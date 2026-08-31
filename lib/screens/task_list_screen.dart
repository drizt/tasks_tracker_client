import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../models/time_entry.dart';
import '../state/task_controller.dart';
import '../utils/duration_format.dart';
import '../utils/task_status_style.dart';
import '../widgets/active_timer_bar.dart';
import '../widgets/task_card.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    required this.controller,
    required this.serverUri,
    required this.onConfigureServer,
    super.key,
  });

  final TaskController controller;
  final Uri serverUri;
  final Future<void> Function(BuildContext context) onConfigureServer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                controller.selectPreviousTask,
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                controller.selectNextTask,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: _Body(
                        controller: controller,
                        serverUri: serverUri,
                        onConfigureServer: onConfigureServer,
                      ),
                    ),
                    ActiveTimerBar(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.controller,
    required this.serverUri,
    required this.onConfigureServer,
  });

  final TaskController controller;
  final Uri serverUri;
  final Future<void> Function(BuildContext context) onConfigureServer;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  static const double _minSidebarWidth = 240;
  static const double _defaultSidebarWidth = 340;
  static const double _maxSidebarWidth = 560;
  static const double _minDetailsWidth = 360;
  static const double _resizeHandleWidth = 8;

  double sidebarWidth = _defaultSidebarWidth;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return _ErrorView(
        message: controller.error!,
        onRetry: controller.load,
        onConfigureServer: widget.onConfigureServer,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            (constraints.maxWidth - _minDetailsWidth - _resizeHandleWidth)
                .clamp(_minSidebarWidth, _maxSidebarWidth)
                .toDouble();
        final effectiveSidebarWidth = sidebarWidth
            .clamp(_minSidebarWidth, maxWidth)
            .toDouble();

        return Row(
          children: [
            SizedBox(
              width: effectiveSidebarWidth,
              child: _TaskSidebar(
                controller: controller,
                serverUri: widget.serverUri,
                onConfigureServer: widget.onConfigureServer,
              ),
            ),
            _ResizeHandle(
              width: _resizeHandleWidth,
              onDrag: (delta) {
                setState(() {
                  sidebarWidth = (sidebarWidth + delta)
                      .clamp(_minSidebarWidth, maxWidth)
                      .toDouble();
                });
              },
            ),
            Expanded(child: _TaskDetails(controller: controller)),
          ],
        );
      },
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.width, required this.onDrag});

  final double width;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Resize task list',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
          child: SizedBox(
            width: width,
            child: Center(
              child: Container(width: 1, color: colorScheme.outlineVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskSidebar extends StatefulWidget {
  const _TaskSidebar({
    required this.controller,
    required this.serverUri,
    required this.onConfigureServer,
  });

  final TaskController controller;
  final Uri serverUri;
  final Future<void> Function(BuildContext context) onConfigureServer;

  @override
  State<_TaskSidebar> createState() => _TaskSidebarState();
}

class _TaskSidebarState extends State<_TaskSidebar> {
  static const double _taskExtent = 44;

  final ScrollController _scrollController = ScrollController();
  String? _lastSelectedTaskId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filteredTasks = controller.filteredTasks;
    final selectedTaskId = controller.selectedTaskId;
    if (selectedTaskId != _lastSelectedTaskId) {
      _lastSelectedTaskId = selectedTaskId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedTask(filteredTasks, selectedTaskId);
      });
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tasks Tracker',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Server settings (${widget.serverUri.toString()})',
                  onPressed: () => widget.onConfigureServer(context),
                  icon: const Icon(Icons.settings_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Add task',
                  onPressed: () => _showTaskDialog(context, controller),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: TaskListFilter.values.map((filter) {
                final isSelected = controller.filter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: Theme.of(context).textTheme.labelLarge,
                  onSelected: (_) => controller.setFilter(filter),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(child: Text('No ${controller.filter.label} tasks'))
                : ListView.builder(
                    controller: _scrollController,
                    itemExtent: _taskExtent,
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return TaskCard(
                        task: task,
                        total: controller.totalForTask(task.id),
                        isSelected: controller.selectedTaskIds.contains(
                          task.id,
                        ),
                        isRunning: controller.activeTaskId == task.id,
                        onTap: () => controller.selectTask(
                          task.id,
                          additive: HardwareKeyboard.instance.isControlPressed,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _scrollToSelectedTask(List<Task> tasks, String? selectedTaskId) {
    if (!_scrollController.hasClients || selectedTaskId == null) {
      return;
    }

    final selectedIndex = tasks.indexWhere((task) => task.id == selectedTaskId);
    if (selectedIndex == -1) {
      return;
    }

    final position = _scrollController.position;
    final taskTop = selectedIndex * _taskExtent;
    final taskBottom = taskTop + _taskExtent;
    final viewportTop = position.pixels;
    final viewportBottom = viewportTop + position.viewportDimension;
    final targetOffset = switch ((taskTop, taskBottom)) {
      (final top, _) when top < viewportTop => top,
      (_, final bottom) when bottom > viewportBottom =>
        bottom - position.viewportDimension,
      _ => null,
    };

    if (targetOffset != null) {
      _scrollController.jumpTo(
        targetOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }
}

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({required this.controller});

  final TaskController controller;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.selectedTasks;
    if (tasks.isEmpty) {
      return const Center(child: Text('Select a task'));
    }

    final task = tasks.last;
    final taskIds = tasks.map((task) => task.id).toList();
    final entries = controller.entriesForTasks(taskIds);
    final isMultiple = tasks.length > 1;
    final isRunning = !isMultiple && controller.activeTaskId == task.id;
    final commonStatus =
        tasks.every((selectedTask) => selectedTask.status == task.status)
        ? task.status
        : null;
    final allArchived = tasks.every((selectedTask) => selectedTask.isArchived);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMultiple)
            SelectableText(
              '${tasks.length} tasks selected',
              style: Theme.of(context).textTheme.headlineMedium,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        task.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          task.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  tooltip: 'Edit task',
                  onPressed: () =>
                      _showTaskDialog(context, controller, existingTask: task),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: task.isArchived ? 'Unarchive task' : 'Archive task',
                  onPressed: () => task.isArchived
                      ? controller.unarchiveTask(task.id)
                      : controller.archiveTask(task.id),
                  icon: Icon(
                    task.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete task',
                  onPressed: () => _confirmDelete(context, controller, task),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: 'Total',
                value: formatDuration(controller.totalForTasks(taskIds)),
                icon: Icons.timelapse_rounded,
              ),
              _MetricTile(
                label: 'Entries',
                value: entries.length.toString(),
                icon: Icons.format_list_bulleted_rounded,
              ),
              _MetricTile(
                label: 'Status',
                value: commonStatus?.label ?? 'Mixed',
                icon: commonStatus == null
                    ? Icons.rule_rounded
                    : taskStatusIcon(commonStatus),
                iconColor: commonStatus == null
                    ? colorScheme.onSurfaceVariant
                    : taskStatusColor(commonStatus),
              ),
              _MetricTile(
                label: isMultiple ? 'Tasks' : 'Archive',
                value: isMultiple
                    ? tasks.length.toString()
                    : task.isArchived
                    ? 'Archived'
                    : 'Current',
                icon: isMultiple
                    ? Icons.checklist_rounded
                    : task.isArchived
                    ? Icons.archive_outlined
                    : Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!isMultiple)
                FilledButton.icon(
                  onPressed: isRunning
                      ? controller.stopTimer
                      : () => controller.startTimer(task.id),
                  icon: Icon(
                    isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(isRunning ? 'Stop timer' : 'Start timer'),
                ),
              MenuAnchor(
                builder: (context, menuController, child) {
                  return OutlinedButton.icon(
                    onPressed: menuController.isOpen
                        ? menuController.close
                        : menuController.open,
                    icon: Icon(
                      commonStatus == null
                          ? Icons.rule_rounded
                          : taskStatusIcon(commonStatus),
                      color: commonStatus == null
                          ? colorScheme.onSurfaceVariant
                          : taskStatusColor(commonStatus),
                    ),
                    label: Text(isMultiple ? 'Set status' : task.status.label),
                  );
                },
                menuChildren: TaskStatus.values.map((status) {
                  return MenuItemButton(
                    leadingIcon: Icon(
                      taskStatusIcon(status),
                      color: taskStatusColor(status),
                    ),
                    onPressed: () =>
                        controller.changeTasksStatus(taskIds, status),
                    child: Text(status.label),
                  );
                }).toList(),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    tasks.every(
                      (selectedTask) =>
                          selectedTask.status == TaskStatus.completed,
                    )
                    ? null
                    : () => controller.completeTasks(taskIds),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Complete'),
              ),
              OutlinedButton.icon(
                onPressed: () => allArchived
                    ? controller.unarchiveTasks(taskIds)
                    : controller.archiveTasks(taskIds),
                icon: Icon(
                  allArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(allArchived ? 'Unarchive' : 'Archive'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Time entries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!isMultiple)
                OutlinedButton.icon(
                  onPressed: () => _showTimeEntryDialog(
                    context,
                    controller,
                    taskId: task.id,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add entry'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No saved time entries',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : _TimeEntryGroups(
                    selectionKey: taskIds.join(','),
                    entries: entries,
                    taskNamesById: {
                      for (final selectedTask in tasks)
                        selectedTask.id: selectedTask.title,
                    },
                    showTaskNames: isMultiple,
                    onEdit: (entry) => _showTimeEntryDialog(
                      context,
                      controller,
                      taskId: entry.taskId,
                      existingEntry: entry,
                    ),
                    onDelete: (entry) =>
                        _confirmDeleteTimeEntry(context, controller, entry),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimeEntryGroups extends StatelessWidget {
  const _TimeEntryGroups({
    required this.selectionKey,
    required this.entries,
    required this.taskNamesById,
    required this.showTaskNames,
    required this.onEdit,
    required this.onDelete,
  });

  final String selectionKey;
  final List<TimeEntry> entries;
  final Map<String, String> taskNamesById;
  final bool showTaskNames;
  final ValueChanged<TimeEntry> onEdit;
  final ValueChanged<TimeEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = _groupTimeEntries(entries);
    final today = DateTime.now();

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ExpansionTile(
          key: PageStorageKey('$selectionKey:${group.date.toIso8601String()}'),
          initiallyExpanded: _isSameDate(group.date, today),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  formatDate(group.date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                formatDuration(group.total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          children: group.entries.map((entry) {
            return _TimeEntryRow(
              entry: entry,
              taskName: showTaskNames ? taskNamesById[entry.taskId] : null,
              onEdit: () => onEdit(entry),
              onDelete: () => onDelete(entry),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TimeEntryGroup {
  const _TimeEntryGroup({
    required this.date,
    required this.entries,
    required this.total,
  });

  final DateTime date;
  final List<TimeEntry> entries;
  final Duration total;
}

List<_TimeEntryGroup> _groupTimeEntries(List<TimeEntry> entries) {
  final entriesByDate = <DateTime, List<TimeEntry>>{};
  for (final entry in entries) {
    final localStart = entry.startedAt.toLocal();
    final date = DateTime(localStart.year, localStart.month, localStart.day);
    entriesByDate.putIfAbsent(date, () => []).add(entry);
  }

  return entriesByDate.entries.map((dateEntries) {
    final total = dateEntries.value.fold(
      Duration.zero,
      (sum, entry) => sum + entry.duration,
    );
    return _TimeEntryGroup(
      date: dateEntries.key,
      entries: dateEntries.value,
      total: total,
    );
  }).toList();
}

bool _isSameDate(DateTime first, DateTime second) {
  final localSecond = second.toLocal();
  return first.year == localSecond.year &&
      first.month == localSecond.month &&
      first.day == localSecond.day;
}

class _TimeEntryRow extends StatelessWidget {
  const _TimeEntryRow({
    required this.entry,
    required this.taskName,
    required this.onEdit,
    required this.onDelete,
  });

  final TimeEntry entry;
  final String? taskName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [formatDuration(entry.duration), ?taskName].join('  '),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.endedAt == null
                      ? '${formatDateTime(entry.startedAt)} - Running'
                      : '${formatDateTime(entry.startedAt)} - '
                            '${formatDateTime(entry.endedAt!)}',
                ),
                if (entry.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.note,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Edit time entry',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete time entry',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onConfigureServer,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function(BuildContext context) onConfigureServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              'Could not load tasks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SelectableText(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyErrorMessage(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onConfigureServer(context),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Server'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyErrorMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Error copied')));
  }
}

Future<void> _showTaskDialog(
  BuildContext context,
  TaskController controller, {
  Task? existingTask,
}) async {
  final result = await showDialog<_TaskFormResult>(
    context: context,
    builder: (context) => _TaskDialog(existingTask: existingTask),
  );

  if (result == null) {
    return;
  }

  if (existingTask == null) {
    await controller.addTask(
      title: result.title,
      description: result.description,
    );
  } else {
    await controller.updateTask(
      existingTask.copyWith(
        title: result.title,
        description: result.description,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.existingTask});

  final Task? existingTask;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.existingTask?.description ?? '',
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingTask == null ? 'Add task' : 'Edit task'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.of(context).pop(
              _TaskFormResult(
                title: titleController.text.trim(),
                description: descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TaskFormResult {
  const _TaskFormResult({required this.title, required this.description});

  final String title;
  final String description;
}

Future<void> _confirmDelete(
  BuildContext context,
  TaskController controller,
  Task task,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete task?'),
        content: Text('This will remove "${task.title}" and its time entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await controller.deleteTask(task.id);
  }
}

Future<void> _showTimeEntryDialog(
  BuildContext context,
  TaskController controller, {
  required String taskId,
  TimeEntry? existingEntry,
}) async {
  final result = await showDialog<_TimeEntryFormResult>(
    context: context,
    builder: (context) => _TimeEntryDialog(existingEntry: existingEntry),
  );

  if (result == null) {
    return;
  }

  if (existingEntry == null) {
    final endedAt = result.endedAt;
    if (endedAt == null) {
      return;
    }

    await controller.addTimeEntry(
      taskId: taskId,
      startedAt: result.startedAt,
      endedAt: endedAt,
      note: result.note,
    );
  } else {
    await controller.updateTimeEntry(
      existingEntry.copyWith(
        startedAt: result.startedAt.toUtc(),
        endedAt: result.endedAt?.toUtc(),
        clearEndedAt: result.endedAt == null,
        note: result.note,
      ),
    );
  }
}

class _TimeEntryDialog extends StatefulWidget {
  const _TimeEntryDialog({this.existingEntry});

  final TimeEntry? existingEntry;

  @override
  State<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController startController;
  late final TextEditingController endController;
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    final defaultEnd = DateTime.now();
    final defaultStart = defaultEnd.subtract(const Duration(minutes: 30));
    startController = TextEditingController(
      text: formatDateTime(widget.existingEntry?.startedAt ?? defaultStart),
    );
    endController = TextEditingController(
      text: widget.existingEntry == null
          ? formatDateTime(defaultEnd)
          : widget.existingEntry?.endedAt == null
          ? ''
          : formatDateTime(widget.existingEntry!.endedAt!),
    );
    noteController = TextEditingController(
      text: widget.existingEntry?.note ?? '',
    );
  }

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingEntry == null ? 'Add time entry' : 'Edit time entry',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: startController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Start',
                  hintText: '2026-06-27 09:00:00',
                ),
                validator: (value) {
                  if (_parseDateTimeInput(value) == null) {
                    return 'Use YYYY-MM-DD HH:MM:SS';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'End',
                  hintText: '2026-06-27 10:30:00',
                ),
                validator: (value) {
                  final start = _parseDateTimeInput(startController.text);
                  final end = _parseDateTimeInput(value);
                  final canStayOpen = widget.existingEntry?.isRunning ?? false;
                  if (canStayOpen && (value == null || value.trim().isEmpty)) {
                    return null;
                  }
                  if (end == null) {
                    return 'Use YYYY-MM-DD HH:MM:SS';
                  }
                  if (start != null && !end.isAfter(start)) {
                    return 'End must be after start';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.of(context).pop(
              _TimeEntryFormResult(
                startedAt: _parseDateTimeInput(startController.text)!,
                endedAt: _parseDateTimeInput(endController.text),
                note: noteController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> _confirmDeleteTimeEntry(
  BuildContext context,
  TaskController controller,
  TimeEntry entry,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete time entry?'),
        content: Text(
          entry.endedAt == null
              ? '${formatDateTime(entry.startedAt)} - Running'
              : '${formatDateTime(entry.startedAt)} - '
                    '${formatDateTime(entry.endedAt!)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await controller.deleteTimeEntry(entry.id);
  }
}

DateTime? _parseDateTimeInput(String? value) {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return null;
  }

  final normalizedValue = trimmedValue.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalizedValue);
}

class _TimeEntryFormResult {
  const _TimeEntryFormResult({
    required this.startedAt,
    required this.endedAt,
    required this.note,
  });

  final DateTime startedAt;
  final DateTime? endedAt;
  final String note;
}
