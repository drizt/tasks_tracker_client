import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/models/task.dart';
import 'package:tasks_tracker_client/models/time_entry.dart';
import 'package:tasks_tracker_client/utils/archive_report.dart';

void main() {
  test('day starts at 05:00 local time, including month rollover', () {
    expect(
      archiveDayStart(DateTime(2026, 11, 1, 4, 59, 59)),
      DateTime(2026, 10, 31, 5),
    );
    expect(archiveDayStart(DateTime(2026, 11, 1, 5)), DateTime(2026, 11, 1, 5));
    final timestamp = DateTime(2026, 11, 1, 5).toUtc();
    expect(archiveDayStart(timestamp), DateTime(2026, 11, 1, 5));
  });

  test('week starts Monday at 05:00 after the Sunday workday ends', () {
    expect(
      archiveWeekStart(DateTime(2026, 11, 9, 4, 59, 59)),
      DateTime(2026, 11, 2, 5),
    );
    expect(
      archiveWeekStart(DateTime(2026, 11, 9, 5)),
      DateTime(2026, 11, 9, 5),
    );
    expect(
      archiveWeekStart(DateTime(2026, 11, 15, 23, 59)),
      DateTime(2026, 11, 9, 5),
    );
  });

  test('daily report matches the supplied format exactly', () {
    final titles = [
      'Фикс снятий Baltbet',
      'Фикс парсинга Ligastavok',
      'Фикс Zenit',
      'Фикс снятия B1winBasic',
      'Изменение алгоритма автоснятия',
    ];
    final tasks = [for (final title in titles) _task(title)];
    final durations = [10, 50, 20, 10, 240];
    final entries = [
      for (var i = 0; i < tasks.length; i++)
        _entry(tasks[i], DateTime(2026, 11, 6, 10 + i), durations[i]),
    ];

    expect(
      generateArchiveReport(
        selectedTask: tasks.last,
        tasks: tasks,
        entries: entries,
      ),
      '#сделано\n'
      '* Фикс снятий Baltbet - 10 мин.\n'
      '* Фикс парсинга Ligastavok - 50 мин.\n'
      '* Фикс Zenit - 20 мин.\n'
      '* Фикс снятия B1winBasic - 10 мин.\n'
      '* Изменение алгоритма автоснятия - 4 ч.\n\n'
      '5 ч. 30 мин.',
    );
  });

  test('rounds full task totals once and sums rounded values', () {
    final tasks = [_task('First'), _task('Second'), _task('Tiny')];
    final entries = [
      _entry(tasks[0], DateTime(2026, 11, 5, 10), 4),
      _entry(tasks[0], DateTime(2026, 11, 6, 10), 11),
      _entry(tasks[1], DateTime(2026, 11, 6, 11), 15),
      _entry(tasks[2], DateTime(2026, 11, 6, 12), 4),
    ];
    final totals = archiveTimeTotals(
      tasks: tasks,
      entries: entries,
      now: DateTime(2026, 11, 6, 15),
    );
    expect(totals.day, const Duration(minutes: 40));
    expect(totals.week, const Duration(minutes: 40));
    expect(totals.total, const Duration(minutes: 40));
    final selectedTotals = archiveTimeTotals(
      tasks: tasks,
      entries: entries,
      now: DateTime(2026, 11, 6, 15),
      selectedTaskIds: [tasks.first.id, tasks.last.id],
    );
    expect(selectedTotals.day, totals.day);
    expect(selectedTotals.week, totals.week);
    expect(selectedTotals.total, const Duration(minutes: 20));
    expect(
      generateArchiveReport(
        selectedTask: tasks.first,
        tasks: tasks,
        entries: entries,
      ),
      '#сделано\n* First - 20 мин.\n* Second - 20 мин.\n'
      '* Tiny - 0 мин.\n\n40 мин.',
    );
  });

  test('uses the latest end, local 05:00 cutoff, and archived state', () {
    final tasks = [
      _task('Before'),
      _task('Selected'),
      _task('After'),
      _task('Current', archived: false),
      _task('No entries'),
    ];
    final entries = [
      _entry(tasks[0], DateTime(2026, 11, 6, 4, 59, 59), 10),
      _entry(tasks[1], DateTime(2026, 11, 6, 5), 10),
      _entry(tasks[2], DateTime(2026, 11, 7, 4, 59), 10),
      _entry(tasks[3], DateTime(2026, 11, 6, 12), 10),
      // Earlier entries must not determine the finish day.
      _entry(tasks[2], DateTime(2026, 11, 5, 12), 10),
      TimeEntry(
        id: 'running',
        taskId: tasks[1].id,
        startedAt: DateTime(2026, 11, 8),
      ),
    ];
    expect(
      generateArchiveReport(
        selectedTask: tasks[1],
        tasks: tasks,
        entries: entries,
      ),
      '#сделано\n* Selected - 10 мин.\n* After - 20 мин.\n\n30 мин.',
    );
  });

  test(
    'Sunday includes only Monday through Sunday in chronological groups',
    () {
      final tasks = [
        _task('Previous Sunday'),
        _task('Monday'),
        _task('Friday'),
        _task('Sunday'),
        _task('Next Monday'),
      ];
      final entries = [
        _entry(tasks[0], DateTime(2026, 11, 2, 4, 59), 60),
        _entry(tasks[1], DateTime(2026, 11, 2, 5), 60),
        _entry(tasks[2], DateTime(2026, 11, 6, 12), 20),
        _entry(tasks[3], DateTime(2026, 11, 9, 4, 59), 30),
        _entry(tasks[4], DateTime(2026, 11, 9, 5), 60),
      ];
      final totals = archiveTimeTotals(
        tasks: tasks,
        entries: entries,
        now: DateTime(2026, 11, 9, 4, 59),
      );
      expect(totals.day, const Duration(minutes: 30));
      expect(totals.week, const Duration(minutes: 110));
      expect(totals.total, const Duration(minutes: 230));
      expect(
        generateArchiveReport(
          selectedTask: tasks[3],
          tasks: tasks.reversed.toList(),
          entries: entries.reversed.toList(),
        ),
        '#сделано\n* Sunday - 30 мин.\n\n30 мин.\n\n'
        '#неделя\n\n* Monday - 1 ч.\n\n1 ч.\n\n----\n\n'
        '* Friday - 20 мин.\n\n20 мин.\n\n----\n\n'
        '* Sunday - 30 мин.\n\n30 мин.\n\n====\n\n1 ч. 50 мин.',
      );
    },
  );

  test('uses archive time for untimed tasks and adds names to daily total', () {
    final timed = _task('Timed');
    final untimed = _task('Chromium 157.0.8103.39')
        .copyWith(archivedAt: DateTime(2026, 11, 7, 4, 59));
    final tasks = [
      timed,
      untimed,
      _task('Next day').copyWith(archivedAt: DateTime(2026, 11, 7, 5)),
    ];
    expect(
      generateArchiveReport(
        selectedTask: untimed,
        tasks: tasks,
        entries: [_entry(timed, DateTime(2026, 11, 6, 12), 330)],
      ),
      '#сделано\n* Timed - 5 ч. 30 мин.\n* Chromium 157.0.8103.39\n\n'
      '5 ч. 30 мин. + Chromium 157.0.8103.39',
    );
  });

  test('includes untimed names in each day and the weekly total', () {
    final timed = _task('Timed');
    final monday = _task('Monday untimed')
        .copyWith(archivedAt: DateTime(2026, 11, 2, 12));
    final sunday = _task('Chromium 157.0.8103.39')
        .copyWith(archivedAt: DateTime(2026, 11, 9, 4, 59));
    final tasks = [
      timed,
      monday,
      sunday,
      _task('Previous week').copyWith(archivedAt: DateTime(2026, 11, 2, 4)),
      _task('Next week').copyWith(archivedAt: DateTime(2026, 11, 9, 5)),
      _task('Unarchived', archived: false),
    ];
    expect(
      generateArchiveReport(
        selectedTask: sunday,
        tasks: tasks,
        entries: [_entry(timed, DateTime(2026, 11, 8, 12), 330)],
      ),
      '#сделано\n* Timed - 5 ч. 30 мин.\n* Chromium 157.0.8103.39\n\n'
      '5 ч. 30 мин. + Chromium 157.0.8103.39\n\n'
      '#неделя\n\n* Monday untimed\n\n0 мин. + Monday untimed\n\n----\n\n'
      '* Timed - 5 ч. 30 мин.\n* Chromium 157.0.8103.39\n\n'
      '5 ч. 30 мин. + Chromium 157.0.8103.39\n\n====\n\n'
      '5 ч. 30 мин. + Monday untimed + Chromium 157.0.8103.39',
    );
  });

  test('does not use archive time for a task with only a running entry', () {
    final task = _task('Running');
    expect(
      generateArchiveReport(
        selectedTask: task,
        tasks: [task],
        entries: [
          TimeEntry(id: 'running', taskId: task.id, startedAt: DateTime(2026)),
        ],
      ),
      isEmpty,
    );
  });

  test(
    'does not generate a report for an untimed task without archive time',
    () {
      final task = _task('No entries').copyWith(clearArchivedAt: true);
      expect(
        generateArchiveReport(selectedTask: task, tasks: [task], entries: []),
        isEmpty,
      );
    },
  );
}

Task _task(String title, {bool archived = true}) => Task(
  id: title,
  title: title,
  description: '',
  status: TaskStatus.completed,
  isArchived: archived,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  archivedAt: archived ? DateTime(2026, 11, 10) : null,
);

TimeEntry _entry(Task task, DateTime end, int minutes) => TimeEntry(
  id: '${task.id}-$end',
  taskId: task.id,
  startedAt: end.subtract(Duration(minutes: minutes)),
  endedAt: end.toUtc(),
);
