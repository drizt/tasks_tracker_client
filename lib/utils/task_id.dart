import 'package:ulid/ulid.dart';

String createTaskId() {
  return Ulid().toBase32(lowercase: true);
}
