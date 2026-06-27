import 'package:flutter/material.dart';

import '../models/task.dart';

IconData taskStatusIcon(TaskStatus status) {
  return switch (status) {
    TaskStatus.newTask => Icons.fiber_new_rounded,
    TaskStatus.active => Icons.radio_button_checked,
    TaskStatus.completed => Icons.check_circle_outline_rounded,
    TaskStatus.deferred => Icons.pause_circle_outline_rounded,
    TaskStatus.canceled => Icons.cancel_outlined,
  };
}

Color taskStatusColor(TaskStatus status) {
  return switch (status) {
    TaskStatus.newTask => const Color(0xff2563eb),
    TaskStatus.active => const Color(0xffd97706),
    TaskStatus.completed => const Color(0xff16a34a),
    TaskStatus.deferred => const Color(0xff7c3aed),
    TaskStatus.canceled => const Color(0xffdc2626),
  };
}
