import 'package:flutter/material.dart';
import '../models/class_schedule.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import 'day_table_page.dart';

class ScheduleDaysPage extends StatefulWidget {
  final ClassSchedule schedule;
  final String userId;

  const ScheduleDaysPage({
    super.key,
    required this.schedule,
    required this.userId,
  });

  @override
  State<ScheduleDaysPage> createState() => _ScheduleDaysPageState();
}

class _ScheduleDaysPageState extends State<ScheduleDaysPage> {
  static const _days = [
    _DayInfo(1, 'Monday', Icons.looks_one_outlined),
    _DayInfo(2, 'Tuesday', Icons.looks_two_outlined),
    _DayInfo(3, 'Wednesday', Icons.looks_3_outlined),
    _DayInfo(4, 'Thursday', Icons.looks_4_outlined),
    _DayInfo(5, 'Friday', Icons.looks_5_outlined),
    _DayInfo(6, 'Saturday', Icons.looks_6_outlined),
  ];

  final _service = FirestoreService();

  Future<void> _openDay(int weekday) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayTablePage(
          schedule: widget.schedule,
          weekday: weekday,
          userId: widget.userId,
        ),
      ),
    );
    await _service.saveSchedule(widget.schedule, widget.userId);
    if (mounted) setState(() {});
  }

  int _classCount(int weekday) {
    return widget.schedule.days[weekday]?.length ?? 0;
  }

  bool _isToday(int weekday) {
    return DateTime.now().weekday == weekday;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFDE5C),
                  Color(0xFFFFD12B),
                  Color(0xFFFFC107),
                ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(8, top + 8, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 18,
                      color: kTextPrimary,
                    ),
                    const Spacer(),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    widget.schedule.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 6),
                  child: Text(
                    'Pick a day to edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: GridView.builder(
                    itemCount: _days.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, i) {
                      final d = _days[i];
                      return _DayCard(
                        day: d,
                        classCount: _classCount(d.weekday),
                        isToday: _isToday(d.weekday),
                        onTap: () => _openDay(d.weekday),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayInfo {
  final int weekday;
  final String full;
  final IconData icon;
  const _DayInfo(this.weekday, this.full, this.icon);
}

class _DayCard extends StatelessWidget {
  final _DayInfo day;
  final int classCount;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCard({
    required this.day,
    required this.classCount,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasClasses = classCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceAlt,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isToday ? kAccent : kBorder,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasClasses ? kAccentSoft : kSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      day.icon,
                      size: 20,
                      color: hasClasses ? kTextPrimary : kTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                day.full,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasClasses
                    ? '$classCount ${classCount == 1 ? 'class' : 'classes'}'
                    : 'Free day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasClasses ? kTextPrimary : kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}