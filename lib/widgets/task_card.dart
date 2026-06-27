import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/duration_format.dart';
import '../utils/task_status_style.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.total,
    required this.isSelected,
    required this.isRunning,
    required this.onTap,
    super.key,
  });

  final Task task;
  final Duration total;
  final bool isSelected;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? colorScheme.secondary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: task.status.label,
                child: Icon(
                  taskStatusIcon(task.status),
                  size: 18,
                  color: taskStatusColor(task.status),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isRunning) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Running',
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text(
                formatDuration(total),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isRunning
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: isRunning ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
