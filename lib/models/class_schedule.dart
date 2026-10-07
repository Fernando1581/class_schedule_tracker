import 'package:flutter/material.dart';

class DayInfo {
  String room;
  String teacher;
  bool isLab;

  DayInfo({
    this.room = '',
    this.teacher = '',
    this.isLab = false,
  });
}

class TimeEntry {
  TimeOfDay startTime;
  TimeOfDay endTime;
  String subject;
  String teacher;
  int colorIndex;
  String type;
  Map<int, DayInfo> perDay;

  TimeEntry({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
    this.colorIndex = 0,
    this.type = 'single',
    Map<int, DayInfo>? perDay,
  }) : perDay = perDay ?? {};

  String roomFor(int day) {
    if (perDay.containsKey(day)) return perDay[day]!.room;
    if (perDay.isNotEmpty) return perDay.values.first.room;
    return '';
  }

  String teacherFor(int day) {
    if (perDay.containsKey(day)) return perDay[day]!.teacher;
    if (perDay.isNotEmpty) return perDay.values.first.teacher;
    return teacher;
  }

  bool isLabFor(int day) {
    if (perDay.containsKey(day)) return perDay[day]!.isLab;
    if (perDay.isNotEmpty) return perDay.values.first.isLab;
    return false;
  }

  Duration get duration {
    final startMin = startTime.hour * 60 + startTime.minute;
    var endMin = endTime.hour * 60 + endTime.minute;
    if (endMin <= startMin) endMin += 24 * 60;
    final diff = endMin - startMin;
    if (diff > 360) return Duration.zero;
    return Duration(minutes: diff);
  }

  TimeEntry copy() {
    return TimeEntry(
      startTime: startTime,
      endTime: endTime,
      subject: subject,
      teacher: teacher,
      colorIndex: colorIndex,
      type: type,
      perDay: {
        for (final e in perDay.entries)
          e.key: DayInfo(
            room: e.value.room,
            teacher: e.value.teacher,
            isLab: e.value.isLab,
          ),
      },
    );
  }
}

class ClassSchedule {
  String name;
  Map<int, List<TimeEntry>> days;

  ClassSchedule({
    required this.name,
    Map<int, List<TimeEntry>>? days,
  }) : days = days ??
            {
              1: [],
              2: [],
              3: [],
              4: [],
              5: [],
              6: [],
            };
}

class Note {
  String text;
  DateTime date;

  Note({required this.text, required this.date});
}

final List<ClassSchedule> appSchedules = [];
final List<Note> appNotes = [];