import 'package:flutter/material.dart';

class AppTimer {
  final int? id;
  final TimeOfDay time;
  final bool enabled;

  AppTimer({
    this.id,
    required this.time,
    required this.enabled,
  });

  Map<String, dynamic> toMap() {
    final today = DateTime.now();
    return {
      'time':
          DateTime(today.year, today.month, today.day, time.hour, time.minute)
              .millisecondsSinceEpoch,
      'enabled': enabled ? 1 : 0,
    };
  }

  @override
  String toString() {
    return 'Timer{id: $id, time: $time, enabled: $enabled}';
  }
}
