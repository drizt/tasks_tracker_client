import 'package:ulid/ulid.dart';

String createTaskId() {
  return Ulid().toCanonical();
}
