import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/utils/duration_format.dart';

void main() {
  test('formats today and yesterday as calendar dates', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    expect(formatDate(today), 'Today');
    expect(formatDate(yesterday), 'Yesterday');
  });

  test('formats dates from the current year without the year', () {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month == 1 ? 7 : 1, 15);

    expect(formatDate(date), matches(RegExp(r'^\w{3}, \d{1,2} \w{3}$')));
    expect(formatDate(date), isNot(contains(now.year.toString())));
  });

  test('formats dates from earlier years with an abbreviated date', () {
    expect(formatDate(DateTime(2020, 6, 27)), 'Sat, 27 Jun 2020');
  });

  test('formats date time with seconds', () {
    final formatted = formatDateTime(DateTime(2026, 6, 27, 9, 8, 7));

    expect(formatted, '2026-06-27 09:08:07');
  });
}
