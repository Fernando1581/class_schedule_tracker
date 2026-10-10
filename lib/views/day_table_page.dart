import 'package:flutter/material.dart';
import '../models/class_schedule.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

const kBlockColors = <Color>[
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFFFFC800),
  Color(0xFFA855F7),
  Color(0xFF22C55E),
  Color(0xFFF97316),
];

class DayTablePage extends StatefulWidget {
  final ClassSchedule schedule;
  final int weekday;
  final String userId;

  const DayTablePage({
    super.key,
    required this.schedule,
    required this.weekday,
    required this.userId,
  });

  @override
  State<DayTablePage> createState() => _DayTablePageState();
}

class _DayTablePageState extends State<DayTablePage> {
  static const _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  final _service = FirestoreService();

  List<TimeEntry> get _entries => widget.schedule.days[widget.weekday]!;

  Future<void> _persist() async {
    await _service.saveSchedule(widget.schedule, widget.userId);
  }

  void _sort(List<TimeEntry> list) {
    list.sort((a, b) {
      final am = a.startTime.hour * 60 + a.startTime.minute;
      final bm = b.startTime.hour * 60 + b.startTime.minute;
      return am.compareTo(bm);
    });
  }

  String _fmt(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  int _startMin(TimeEntry e) => e.startTime.hour * 60 + e.startTime.minute;

  int _endMin(TimeEntry e) {
    final s = e.startTime.hour * 60 + e.startTime.minute;
    var en = e.endTime.hour * 60 + e.endTime.minute;
    if (en <= s) en += 24 * 60;
    return en;
  }

  bool _tooLong(TimeOfDay s, TimeOfDay e) {
    final sM = s.hour * 60 + s.minute;
    var eM = e.hour * 60 + e.minute;
    if (eM <= sM) eM += 24 * 60;
    return (eM - sM) > 360;
  }

  List<int> _targetDays(String type) {
    switch (type) {
      case 'major':
        return [1, 2, 3, 4, 5, 6];
      case 'msat1':
        return [1, 2, 3];
      case 'msat2':
        return [4, 5, 6];
      default:
        return [widget.weekday];
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _newStart(TimeEntry e) => e.startTime.hour * 60 + e.startTime.minute;

  int _newEnd(TimeEntry e) {
    final s = e.startTime.hour * 60 + e.startTime.minute;
    var en = e.endTime.hour * 60 + e.endTime.minute;
    if (en <= s) en += 24 * 60;
    return en;
  }

  TimeEntry? _findConflict(
    int day,
    TimeEntry candidate, {
    TimeEntry? ignore,
  }) {
    final list = widget.schedule.days[day] ?? [];
    final cStart = _newStart(candidate);
    final cEnd = _newEnd(candidate);

    for (final e in list) {
      if (identical(e, ignore)) continue;
      if (ignore != null &&
          e.subject == ignore.subject &&
          e.startTime == ignore.startTime &&
          e.endTime == ignore.endTime) {
        continue;
      }

      final eStart = _startMin(e);
      final eEnd = _endMin(e);

      if (cStart < eEnd && cEnd > eStart) {
        return e;
      }
    }
    return null;
  }

  String? _validateNoConflicts(
    TimeEntry candidate,
    List<int> targetDays, {
    TimeEntry? ignore,
  }) {
    for (final d in targetDays) {
      final conflict = _findConflict(d, candidate, ignore: ignore);
      if (conflict != null) {
        final dayName = _dayNames[d] ?? 'Day $d';
        return 'Conflicts with "${conflict.subject}" '
            '(${_fmt(conflict.startTime)} - ${_fmt(conflict.endTime)}) '
            'on $dayName';
      }
    }
    return null;
  }

  Future<void> _addEntry({TimeEntry? existing}) async {
    final result = await showModalBottomSheet<TimeEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEntrySheet(
        existing: existing,
        nextColorIndex:
            existing?.colorIndex ?? (_entries.length % kBlockColors.length),
      ),
    );
    if (result == null) return;

    final newDays = _targetDays(result.type);

    final error = _validateNoConflicts(
      result,
      newDays,
      ignore: existing,
    );
    if (error != null) {
      _snack(error);
      return;
    }

    setState(() {
      if (existing != null) {
        final oldDays = _targetDays(existing.type);
        for (final d in oldDays) {
          widget.schedule.days[d]!.removeWhere(
            (e) =>
                e.subject == existing.subject &&
                e.startTime == existing.startTime &&
                e.endTime == existing.endTime,
          );
        }
      }

      for (final d in newDays) {
        final list = widget.schedule.days[d]!;
        final dupe = list.any((e) =>
            e.subject == result.subject &&
            e.startTime == result.startTime &&
            e.endTime == result.endTime);
        if (!dupe) list.add(result.copy());
        _sort(list);
      }
    });

    await _persist();
  }

  Future<void> _editDay(TimeEntry e) async {
    TimeOfDay start = e.startTime;
    TimeOfDay end = e.endTime;
    final roomController =
        TextEditingController(text: e.roomFor(widget.weekday));
    final teacherController =
        TextEditingController(text: e.teacherFor(widget.weekday));
    bool lab = e.isLabFor(widget.weekday);

    final saved = await showModalBottomSheet<_DayEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pick(bool isStart) async {
              final p = await showTimePicker(
                context: ctx,
                initialTime: isStart ? start : end,
              );
              if (p != null) setSheetState(() => isStart ? start = p : end = p);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_dayNames[widget.weekday]} details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Only changes this day.',
                      style: TextStyle(fontSize: 12, color: kTextSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Start',
                            value: _fmt(start),
                            onTap: () => pick(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'End',
                            value: _fmt(end),
                            onTap: () => pick(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: teacherController,
                      decoration: const InputDecoration(
                        labelText: 'Teacher',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: lab,
                      onChanged: (v) => setSheetState(() => lab = v),
                      activeColor: kAccent,
                      title: const Text(
                        'Lab class on this day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (roomController.text.trim().isEmpty) {
                            _snack('Please enter a room');
                            return;
                          }
                          if (teacherController.text.trim().isEmpty) {
                            _snack('Please enter a teacher');
                            return;
                          }
                          final sM = start.hour * 60 + start.minute;
                          final eM = end.hour * 60 + end.minute;
                          if (sM == eM) {
                            _snack('Start and end time cannot be the same');
                            return;
                          }
                          if (_tooLong(start, end)) {
                            _snack('Class cannot be longer than 6 hours');
                            return;
                          }

                          final candidate = TimeEntry(
                            startTime: start,
                            endTime: end,
                            subject: e.subject,
                            teacher: e.teacher,
                            colorIndex: e.colorIndex,
                            type: e.type,
                            perDay: e.perDay,
                          );

                          final conflict = _findConflict(
                            widget.weekday,
                            candidate,
                            ignore: e,
                          );
                          if (conflict != null) {
                            _snack(
                              'Conflicts with "${conflict.subject}" '
                              '(${_fmt(conflict.startTime)} - '
                              '${_fmt(conflict.endTime)})',
                            );
                            return;
                          }

                          Navigator.pop(
                            ctx,
                            _DayEditResult(
                              start: start,
                              end: end,
                              info: DayInfo(
                                room: roomController.text.trim(),
                                teacher: teacherController.text.trim(),
                                isLab: lab,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: kTextPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == null) return;

    setState(() {
      final list = _entries;
      final i = list.indexOf(e);
      if (i < 0) return;

      list[i] = TimeEntry(
        startTime: saved.start,
        endTime: saved.end,
        subject: e.subject,
        teacher: e.teacher,
        colorIndex: e.colorIndex,
        type: e.type,
        perDay: e.perDay,
      );
      list[i].perDay[widget.weekday] = saved.info;
      _sort(list);
    });

    await _persist();
  }

  Future<void> _deleteEntry(TimeEntry e) async {
    setState(() {
      final days = _targetDays(e.type);
      for (final d in days) {
        widget.schedule.days[d]!.removeWhere(
          (x) =>
              x.subject == e.subject &&
              x.startTime == e.startTime &&
              x.endTime == e.endTime,
        );
      }
    });
    await _persist();
  }

  List<Widget> _buildRows() {
    final rows = <Widget>[];
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final color = kBlockColors[e.colorIndex % kBlockColors.length];
      final day = widget.weekday;

      rows.add(
        _TimelineBlock(
          entry: e,
          color: color,
          timeLabel: _fmt(e.startTime),
          roomLabel: e.roomFor(day),
          teacherLabel: e.teacherFor(day),
          isLab: e.isLabFor(day),
          onTap: () => _editDay(e),
          onLongPress: () => _addEntry(existing: e),
          onDelete: () => _deleteEntry(e),
          fmt: _fmt,
        ),
      );

      if (i < _entries.length - 1) {
        final next = _entries[i + 1];
        final gapStart = _endMin(e);
        final gapEnd = _startMin(next);
        if (gapEnd > gapStart) {
          rows.add(_GapStrip(minutes: gapEnd - gapStart));
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    _sort(_entries);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextPrimary),
        title: Text(
          _dayNames[widget.weekday]!,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _entries.isEmpty
            ? _buildEmpty()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: _buildRows(),
              ),
      ),
      floatingActionButton: _entries.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addEntry(),
              backgroundColor: kAccent,
              foregroundColor: kTextPrimary,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add time',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _addEntry(),
        icon: const Icon(Icons.add, color: kTextPrimary),
        label: const Text(
          'Add time',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: kBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _DayEditResult {
  final TimeOfDay start;
  final TimeOfDay end;
  final DayInfo info;

  _DayEditResult({
    required this.start,
    required this.end,
    required this.info,
  });
}

class _TimelineBlock extends StatelessWidget {
  final TimeEntry entry;
  final Color color;
  final String timeLabel;
  final String roomLabel;
  final String teacherLabel;
  final bool isLab;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final String Function(TimeOfDay) fmt;

  const _TimelineBlock({
    required this.entry,
    required this.color,
    required this.timeLabel,
    required this.roomLabel,
    required this.teacherLabel,
    required this.isLab,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = entry.duration.inMinutes;
    final blockHeight = (minutes * 0.6).clamp(70.0, 120.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: kSurfaceAlt, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: BoxConstraints(minHeight: blockHeight),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: Image.asset(
                              isLab
                                  ? 'assets/lab_icon.png'
                                  : 'assets/classroom_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.subject,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: kDanger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${fmt(entry.startTime)} - ${fmt(entry.endTime)}  (${minutes} min)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                      if (roomLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          roomLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                      ],
                      if (teacherLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          teacherLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapStrip extends StatelessWidget {
  final int minutes;

  const _GapStrip({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 70),
          const SizedBox(width: 12),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: kSurfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                'Vacant • $minutes min',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  final TimeEntry? existing;
  final int nextColorIndex;

  const _AddEntrySheet({
    required this.existing,
    required this.nextColorIndex,
  });

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;
  late final TextEditingController _teacherController;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _colorIndex;
  late String _type;
  late bool _isLab;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectController = TextEditingController(text: e?.subject ?? '');
    _roomController = TextEditingController(
      text: e != null && e.perDay.isNotEmpty
          ? e.perDay.values.first.room
          : '',
    );
    _teacherController = TextEditingController(
      text: e != null && e.perDay.isNotEmpty
          ? e.perDay.values.first.teacher
          : (e?.teacher ?? ''),
    );
    _start = e?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
    _end = e?.endTime ?? const TimeOfDay(hour: 9, minute: 0);
    _colorIndex = e?.colorIndex ?? widget.nextColorIndex;
    _type = e?.type ?? 'single';
    _isLab = e != null && e.perDay.isNotEmpty
        ? e.perDay.values.first.isLab
        : false;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  List<int> _targetDaysForType(String type) {
    switch (type) {
      case 'major':
        return [1, 2, 3, 4, 5, 6];
      case 'msat1':
        return [1, 2, 3];
      case 'msat2':
        return [4, 5, 6];
      default:
        return const [1, 2, 3, 4, 5, 6];
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _submit() {
    if (_subjectController.text.trim().isEmpty) {
      _snack('Please enter a subject');
      return;
    }
    if (_roomController.text.trim().isEmpty) {
      _snack('Please enter a room');
      return;
    }
    if (_teacherController.text.trim().isEmpty) {
      _snack('Please enter a teacher');
      return;
    }

    final startMin = _start.hour * 60 + _start.minute;
    var endMin = _end.hour * 60 + _end.minute;
    if (endMin <= startMin) endMin += 24 * 60;

    if (endMin == startMin) {
      _snack('Start and end time cannot be the same');
      return;
    }
    if (endMin - startMin > 360) {
      _snack('Class cannot be longer than 6 hours');
      return;
    }

    final baseRoom = _roomController.text.trim();
    final baseTeacher = _teacherController.text.trim();
    final days = _targetDaysForType(_type);
    final perDay = <int, DayInfo>{};
    for (final d in days) {
      perDay[d] = DayInfo(
        room: baseRoom,
        teacher: baseTeacher,
        isLab: _isLab,
      );
    }

    Navigator.pop(
      context,
      TimeEntry(
        startTime: _start,
        endTime: _end,
        subject: _subjectController.text.trim(),
        teacher: baseTeacher,
        colorIndex: _colorIndex,
        type: _type,
        perDay: perDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add time' : 'Edit time',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Start',
                    value: _fmt(_start),
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'End',
                    value: _fmt(_end),
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room (default for all days)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: 'Teacher',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isLab,
              onChanged: (v) => setState(() => _isLab = v),
              activeColor: kAccent,
              title: const Text(
                'Lab class (default for all days)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Applies to',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip('Major', 'major'),
                _typeChip('M-SAT1', 'msat1'),
                _typeChip('M-SAT2', 'msat2'),
                _typeChip('Single', 'single'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(kBlockColors.length, (i) {
                final selected = i == _colorIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kBlockColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? kTextPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: kTextPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  widget.existing == null ? 'Add' : 'Save',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kAccent : kSurfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kAccent : kBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? kTextPrimary : kTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: const TextStyle(color: kTextPrimary),
        ),
      ),
    );
  }
}