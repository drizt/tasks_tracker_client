import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/utils/task_id.dart';
import 'package:ulid/ulid.dart';

void main() {
  test('generates ULID-compatible task ids', () {
    final id = createTaskId();

    expect(id, hasLength(26));
    expect(id, matches(RegExp(r'^[0-9a-hjkmnp-tv-z]{26}$')));
    expect(Ulid.parse(id).toCanonical(), id);
  });
}
