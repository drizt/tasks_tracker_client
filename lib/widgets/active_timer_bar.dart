import 'package:flutter/material.dart';

import '../state/task_controller.dart';
import '../utils/duration_format.dart';

class ActiveTimerBar extends StatelessWidget {
  const ActiveTimerBar({required this.controller, super.key});

  final TaskController controller;

  @override
  Widget build(BuildContext context) {
    final activeTask = controller.activeTask;
    if (activeTask == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          const Icon(Icons.timer_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activeTask.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            formatDuration(controller.activeElapsed),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: controller.stopTimer,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
