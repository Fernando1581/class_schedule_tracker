import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/class_schedule.dart';
import '../theme.dart';
import 'schedule_list_page.dart';
import 'calendar_page.dart';

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
  TimeEntry? _current;
  ClassSchedule? _currentSet;
  TimeEntry? _next;
  ClassSchedule? _nextSet;
  Duration _remaining = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
    _update();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _anim?.dispose();
    super.dispose();
  }

  DateTime _phNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }

  void _update() {
    final now = _phNow();
    final today = now.weekday;

    TimeEntry? current;
    ClassSchedule? currentSet;
    TimeEntry? next;
    ClassSchedule? nextSet;
    Duration remaining = Duration.zero;
    Duration total = Duration.zero;

    for (final s in appSchedules) {
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

    if (mounted) {
      setState(() {
        _current = current;
        _currentSet = currentSet;
        _next = next;
        _nextSet = nextSet;
        _remaining = remaining;
        _total = total;
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

  Widget _buildTimerCircle() {
    final hasCurrent = _current != null;
    final display = _current ?? _next;
    final today = _phNow().weekday;

    return SizedBox(
      width: 340,
      height: 340,
      child: AnimatedBuilder(
        animation: _anim ?? const AlwaysStoppedAnimation<double>(0),
        builder: (context, _) {
          double progress = 0;
          if (hasCurrent && _total.inMilliseconds > 0) {
            progress = _remaining.inMilliseconds / _total.inMilliseconds;
            progress = progress.clamp(0.0, 1.0);
          }
          return CustomPaint(
            painter: _TimerRingPainter(
              progress: progress,
              active: hasCurrent,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasCurrent) ...[
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Image.asset(
                        _current!.isLabFor(today)
                            ? 'assets/lab_icon.png'
                            : 'assets/classroom_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    hasCurrent
                        ? _fmtDuration(_remaining)
                        : (display != null
                            ? _fmt(display.startTime)
                            : '--'),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    hasCurrent
                        ? 'remaining'
                        : (display != null ? 'starts at' : ''),
                    style: const TextStyle(
                      fontSize: 14,
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
    final display = _current ?? _next;
    final displaySet = _currentSet ?? _nextSet;
    final today = _phNow().weekday;
    final room = display?.roomFor(today) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Class Schedule',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
          ),
          const Spacer(),
          _buildTimerCircle(),
          const SizedBox(height: 16),
          if (display != null) ...[
            if (room.isNotEmpty)
              Text(
                room,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
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
              display.teacher,
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
          const Spacer(),
          if (_next != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: kAccent, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Up Next',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${_next!.subject} • ${_fmt(_next!.startTime)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 1:
        return const ScheduleListPage();
      case 2:
        return const CalendarPage();
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: _buildCurrentTab()),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: (i) {
            setState(() => _navIndex = i);
            if (i == 0) _update();
          },
          backgroundColor: kSurfaceAlt,
          selectedItemColor: kTextPrimary,
          unselectedItemColor: kTextSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Schedules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Calendar',
            ),
          ],
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