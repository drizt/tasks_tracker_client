import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker/utils/duration_format.dart';

void main() {
  test('formats date time with seconds', () {
    final formatted = formatDateTime(DateTime(2026, 6, 27, 9, 8, 7));

    expect(formatted, '2026-06-27 09:08:07');
  });
}
