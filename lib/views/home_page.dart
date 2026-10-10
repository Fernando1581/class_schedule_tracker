import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule.dart';
import '../services/alarm_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/gradient_header.dart';
import 'schedule_list_page.dart';
import 'notes_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  Timer? _ticker;
  AnimationController? _anim;
  StreamSubscription? _sub;
  StreamSubscription? _activeSub;

  TimeEntry? _current;
  ClassSchedule? _currentSet;
  TimeEntry? _next;
  ClassSchedule? _nextSet;
  Duration _remaining = Duration.zero;
  Duration _total = Duration.zero;
  bool _isCountingToNext = false;
  String? _activeSchedule;

  final _service = FirestoreService();
  int _lastScheduledAlarmId = -1;
  String _lastScheduledKey = '';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _sub = _service.streamSchedules(_userId).listen((list) {
      appSchedules.clear();
      appSchedules.addAll(list);
      _update();
    });

    _activeSub = _service.streamActiveSchedule(_userId).listen((name) {
      _activeSchedule = name;
      _update();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    _update();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _activeSub?.cancel();
    _ticker?.cancel();
    _anim?.dispose();
    super.dispose();
  }

  DateTime _phNow() {
    return DateTime.now();
  }

  String _alarmKey(ClassSchedule s, TimeEntry e, DateTime day) {
    return '${day.year}-${day.month}-${day.day}_${s.name}_'
        '${e.subject}_${e.startTime.hour}:${e.startTime.minute}';
  }

  Future<void> _scheduleAlarmIfNeeded(
    ClassSchedule s,
    TimeEntry e,
    DateTime day,
    DateTime now,
  ) async {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      e.startTime.hour,
      e.startTime.minute,
    );

    if (start.difference(now).inMinutes <= 2) return;

    final key = _alarmKey(s, e, day);
    if (key == _lastScheduledKey) return;

    if (_lastScheduledAlarmId >= 0) {
      await AlarmService.cancel(_lastScheduledAlarmId);
    }

    final id = await AlarmService.schedule(
      classStart: start,
      subject: e.subject,
      room: e.roomFor(day.weekday),
      teacher: e.teacherFor(day.weekday),
    );

    _lastScheduledAlarmId = id;
    _lastScheduledKey = key;
  }

  void _update() {
    final now = _phNow();
    final today = now.weekday;
    final todayDate = DateTime(now.year, now.month, now.day);

    TimeEntry? current;
    ClassSchedule? currentSet;
    TimeEntry? next;
    ClassSchedule? nextSet;
    Duration remaining = Duration.zero;
    Duration total = Duration.zero;
    bool countingToNext = false;

    final schedulesToScan = _activeSchedule == null
        ? <ClassSchedule>[]
        : appSchedules
            .where((s) => s.name == _activeSchedule)
            .toList();

    for (final s in schedulesToScan) {
      final entries = s.days[today] ?? [];
      for (final e in entries) {
        final start = DateTime(now.year, now.month, now.day, e.startTime.hour,
            e.startTime.minute);
        final end = DateTime(
            now.year, now.month, now.day, e.endTime.hour, e.endTime.minute);

        if (now.isAfter(start) && now.isBefore(end)) {
          current = e;
          currentSet = s;
          remaining = end.difference(now);
          total = end.difference(start);
        } else if (now.isBefore(start)) {
          if (next == null ||
              start.isBefore(DateTime(now.year, now.month, now.day,
                  next.startTime.hour, next.startTime.minute))) {
            next = e;
            nextSet = s;
          }
        }
      }
    }

    if (current == null && next != null) {
      final nextStart = DateTime(now.year, now.month, now.day,
          next.startTime.hour, next.startTime.minute);
      remaining = nextStart.difference(now);
      total = remaining;
      countingToNext = true;
    }

    if (next != null && nextSet != null) {
      _scheduleAlarmIfNeeded(nextSet, next, todayDate, now);
    }

    if (mounted) {
      setState(() {
        _current = current;
        _currentSet = currentSet;
        _next = next;
        _nextSet = nextSet;
        _remaining = remaining;
        _total = total;
        _isCountingToNext = countingToNext;
      });
    }
  }

  String _fmt(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _openAddNote() async {
    final now = _phNow();
    DateTime picked = DateTime(now.year, now.month, now.day);
    final textController = TextEditingController();

    final result = await showModalBottomSheet<Note>(
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
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: picked,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setSheetState(() => picked = p);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${picked.month}/${picked.day}/${picked.year}',
                        style: const TextStyle(color: kTextPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (textController.text.trim().isEmpty) return;
                        Navigator.pop(
                          ctx,
                          Note(
                            text: textController.text.trim(),
                            date: picked,
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
            );
          },
        );
      },
    );

    if (result != null) {
      await _service.saveNote(result, _userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildTimerCircle() {
    final hasCurrent = _current != null;
    final display = _current ?? _next;
    final today = _phNow().weekday;

    return SizedBox(
      width: 280,
      height: 280,
      child: AnimatedBuilder(
        animation: _anim ?? const AlwaysStoppedAnimation<double>(0),
        builder: (context, _) {
          double progress = 0;
          if (_total.inMilliseconds > 0 && display != null) {
            progress = _remaining.inMilliseconds / _total.inMilliseconds;
            progress = progress.clamp(0.0, 1.0);
          }
          return CustomPaint(
            painter: _TimerRingPainter(
              progress: progress,
              active: hasCurrent || _isCountingToNext,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasCurrent) ...[
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Image.asset(
                        _current!.isLabFor(today)
                            ? 'assets/lab_icon.png'
                            : 'assets/classroom_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    (hasCurrent || _isCountingToNext)
                        ? _fmtDuration(_remaining)
                        : (display != null
                            ? _fmt(display.startTime)
                            : '--'),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    hasCurrent
                        ? 'remaining'
                        : (_isCountingToNext ? 'until next class' : ''),
                    style: const TextStyle(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeTab() {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Student';
    final display = _current ?? _next;
    final displaySet = _currentSet ?? _nextSet;
    final today = _phNow().weekday;
    final room = display?.roomFor(today) ?? '';
    final teacher = display?.teacherFor(today) ?? '';
    final hasCurrent = _current != null;

    return GradientHeaderScaffold(
      title: 'Class Schedule',
      subtitle: 'Hi, $name',
      action: IconButton(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 20),
        color: kTextPrimary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Spacer(),
            _buildTimerCircle(),
            const SizedBox(height: 16),
            if (display != null) ...[
              if (room.isNotEmpty)
                Text(
                  room,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                display.subject,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_fmt(display.startTime)} - ${_fmt(display.endTime)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                teacher,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary,
                ),
              ),
              if (displaySet != null) ...[
                const SizedBox(height: 4),
                Text(
                  displaySet.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ],
            if (hasCurrent) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openAddNote,
                icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                label: const Text(
                  'Add note',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorder, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 1:
        return const ScheduleListPage();
      case 2:
        return const NotesPage();
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: _buildCurrentTab(),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: kAccent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: kAccent.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: _navIndex == 0,
                onTap: () => setState(() => _navIndex = 0),
              ),
              _NavButton(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                selected: _navIndex == 1,
                onTap: () => setState(() => _navIndex = 1),
              ),
              _NavButton(
                icon: Icons.sticky_note_2_outlined,
                activeIcon: Icons.sticky_note_2_rounded,
                selected: _navIndex == 2,
                onTap: () => setState(() => _navIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          selected ? activeIcon : icon,
          size: 24,
          color: selected ? kTextPrimary : kTextPrimary.withOpacity(0.55),
        ),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool active;

  _TimerRingPainter({required this.progress, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = kBorder;
    canvas.drawCircle(center, radius, trackPaint);

    if (!active) {
      final idlePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = kAccent.withOpacity(0.35);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2,
        false,
        idlePaint,
      );
      return;
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = kAccent;

    final startAngle = -math.pi / 2 + (1 - progress) * math.pi * 2;
    final sweepAngle = math.pi * 2 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter old) {
    return old.progress != progress || old.active != active;
  }
}