import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/class_schedule.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> saveSchedule(ClassSchedule s, String userId) async {
    await _schedules.doc('${userId}_${s.name}').set({
      'userId': userId,
      'name': s.name,
      'days': _encodeDays(s.days),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ClassSchedule>> streamSchedules(String userId) {
    return _schedules
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map(_decodeSchedule).toList());
  }

  Future<void> deleteSchedule(String userId, String name) async {
    await _schedules.doc('${userId}_$name').delete();
  }

  Future<void> setActiveSchedule(String userId, String? scheduleName) async {
    await _users.doc(userId).set({
      'activeSchedule': scheduleName,
    }, SetOptions(merge: true));
  }

  Stream<String?> streamActiveSchedule(String userId) {
    return _users
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['activeSchedule'] as String?);
  }

  Future<void> saveNote(Note note, String userId) async {
    await _notes.add({
      'userId': userId,
      'text': note.text,
      'date': Timestamp.fromDate(note.date),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<MapEntry<String, Note>>> streamNotes(String userId) {
    return _notes.where('userId', isEqualTo: userId).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        return MapEntry(
          doc.id,
          Note(
            text: data['text'] as String,
            date: (data['date'] as Timestamp).toDate(),
          ),
        );
      }).toList();
    });
  }

  Future<void> updateNote(String docId, Note note) async {
    await _notes.doc(docId).update({
      'text': note.text,
      'date': Timestamp.fromDate(note.date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String docId) async {
    await _notes.doc(docId).delete();
  }

  Map<String, dynamic> _encodeDays(Map<int, List<TimeEntry>> days) {
    final map = <String, dynamic>{};
    days.forEach((day, entries) {
      map[day.toString()] = entries.map((e) {
        return <String, dynamic>{
          'startHour': e.startTime.hour,
          'startMinute': e.startTime.minute,
          'endHour': e.endTime.hour,
          'endMinute': e.endTime.minute,
          'subject': e.subject,
          'teacher': e.teacher,
          'colorIndex': e.colorIndex,
          'type': e.type,
          'perDay': e.perDay.map((k, v) {
            return MapEntry(k.toString(), <String, dynamic>{
              'room': v.room,
              'teacher': v.teacher,
              'isLab': v.isLab,
            });
          }),
        };
      }).toList();
    });
    return map;
  }

  ClassSchedule _decodeSchedule(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawDays = data['days'] as Map<String, dynamic>? ?? {};
    final days = <int, List<TimeEntry>>{};

    rawDays.forEach((dayKey, value) {
      final list = (value as List).map((raw) {
        final m = raw as Map<String, dynamic>;
        final perDayMap = m['perDay'] as Map<String, dynamic>? ?? {};
        final perDay = <int, DayInfo>{};
        perDayMap.forEach((k, v) {
          final info = v as Map<String, dynamic>;
          perDay[int.parse(k)] = DayInfo(
            room: info['room'] as String? ?? '',
            teacher: info['teacher'] as String? ?? '',
            isLab: info['isLab'] as bool? ?? false,
          );
        });

        return TimeEntry(
          startTime: TimeOfDay(
            hour: m['startHour'] as int,
            minute: m['startMinute'] as int,
          ),
          endTime: TimeOfDay(
            hour: m['endHour'] as int,
            minute: m['endMinute'] as int,
          ),
          subject: m['subject'] as String,
          teacher: m['teacher'] as String? ?? '',
          colorIndex: m['colorIndex'] as int? ?? 0,
          type: m['type'] as String? ?? 'single',
          perDay: perDay,
        );
      }).toList();

      days[int.parse(dayKey)] = list;
    });

    return ClassSchedule(
      name: data['name'] as String,
      days: days,
    );
  }
}