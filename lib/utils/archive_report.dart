import '../models/task.dart';
import '../models/time_entry.dart';

typedef _ReportTask = ({Task task, DateTime end, DateTime day, int? minutes});

DateTime? archiveReportEnd(Task task, Iterable<TimeEntry> entries) {
  DateTime? latest;
  var hasEntries = false;
  for (final entry in entries) {
    if (entry.taskId != task.id) {
      continue;
    }
    hasEntries = true;
    final end = entry.endedAt;
    if (end != null && (latest == null || end.isAfter(latest))) {
      latest = end;
    }
  }
  return hasEntries ? latest : task.archivedAt;
}

// A workday runs from 05:00 local time until 05:00 the following morning.
DateTime archiveDayStart(DateTime timestamp) {
  final local = timestamp.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day - (local.hour < 5 ? 1 : 0),
    5,
  );
}

DateTime archiveWeekStart(DateTime timestamp) {
  final day = archiveDayStart(timestamp);
  return DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
    5,
  );
}

List<_ReportTask> _archiveReportTasks(
  List<Task> tasks,
  List<TimeEntry> entries,
) {
  final reportTasks = <_ReportTask>[];
  for (final task in tasks) {
    if (!task.isArchived) {
      continue;
    }
    final end = archiveReportEnd(task, entries);
    if (end == null) {
      continue;
    }
    final taskDay = archiveDayStart(end);
    final taskEntries = entries
        .where((entry) => entry.taskId == task.id)
        .toList();
    final duration = taskEntries
        .where((entry) => entry.endedAt != null)
        .fold(Duration.zero, (total, entry) => total + entry.duration);
    final minutes = taskEntries.isEmpty
        ? null
        : (duration.inMicroseconds / const Duration(minutes: 10).inMicroseconds)
                  .round() *
              10;
    reportTasks.add((task: task, end: end, day: taskDay, minutes: minutes));
  }
  reportTasks.sort((first, second) {
    final byEnd = first.end.compareTo(second.end);
    return byEnd != 0 ? byEnd : first.task.id.compareTo(second.task.id);
  });
  return reportTasks;
}

int _totalMinutes(Iterable<_ReportTask> tasks) =>
    tasks.fold(0, (total, item) => total + (item.minutes ?? 0));

({Duration day, Duration week, Duration total}) archiveTimeTotals({
  required List<Task> tasks,
  required List<TimeEntry> entries,
  required DateTime now,
  Iterable<String>? selectedTaskIds,
}) {
  final day = archiveDayStart(now);
  final weekStart = archiveWeekStart(now);
  final reportTasks = _archiveReportTasks(tasks, entries);
  final selectedIds = selectedTaskIds?.toSet();
  return (
    day: Duration(
      minutes: _totalMinutes(reportTasks.where((item) => item.day == day)),
    ),
    week: Duration(
      minutes: _totalMinutes(
        reportTasks.where(
          (item) => !item.day.isBefore(weekStart) && !item.day.isAfter(day),
        ),
      ),
    ),
    total: Duration(
      minutes: _totalMinutes(
        reportTasks.where(
          (item) => selectedIds == null || selectedIds.contains(item.task.id),
        ),
      ),
    ),
  );
}

String generateArchiveReport({
  required Task selectedTask,
  required List<Task> tasks,
  required List<TimeEntry> entries,
}) {
  final selectedEnd = archiveReportEnd(selectedTask, entries);
  if (!selectedTask.isArchived || selectedEnd == null) {
    return '';
  }

  final day = archiveDayStart(selectedEnd);
  final weekStart = archiveWeekStart(selectedEnd);
  final reportTasks = _archiveReportTasks(tasks, entries);

  String dayBody(DateTime date) {
    final dailyTasks = reportTasks.where((task) => task.day == date).toList();
    final lines = dailyTasks.map(
      (item) => item.minutes == null
          ? '* ${item.task.title}'
          : '* ${item.task.title} - ${_formatMinutes(item.minutes!)}',
    );
    return '${lines.join('\n')}\n\n${_reportTotal(dailyTasks)}';
  }

  final dailyReport = '#сделано\n${dayBody(day)}';
  if (day.weekday != DateTime.sunday) {
    return dailyReport;
  }

  final days =
      reportTasks
          .where(
            (item) => !item.day.isBefore(weekStart) && !item.day.isAfter(day),
          )
          .map((item) => item.day)
          .toSet()
          .toList()
        ..sort();
  final weekTasks = reportTasks.where(
    (item) => !item.day.isBefore(weekStart) && !item.day.isAfter(day),
  );
  final weeklyReport =
      '#неделя\n\n${days.map(dayBody).join('\n\n----\n\n')}'
      '\n\n====\n\n${_reportTotal(weekTasks)}';
  return '$dailyReport\n\n$weeklyReport';
}

String _reportTotal(Iterable<_ReportTask> tasks) {
  final total = _totalMinutes(tasks);
  final names = tasks
      .where((item) => item.minutes == null)
      .map((item) => item.task.title);
  final time = _formatMinutes(total);
  return names.isEmpty ? time : '$time + ${names.join(' + ')}';
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return [
    if (hours > 0) '$hours ч.',
    if (remainder > 0 || hours == 0) '$remainder мин.',
  ].join(' ');
}
