import 'package:smart_date_formatter/smart_date_formatter.dart';

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
      '${twoDigits(local.second)}';
}

String formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return local.isToday || local.isYesterday
      ? local.calendar
      : local.isSameYear(DateTime.now())
      ? local.format('EEE, d MMM')
      : local.format('EEE, d MMM yyyy');
}
