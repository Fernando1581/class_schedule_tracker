import 'package:flutter/material.dart';
import '../models/class_schedule.dart';
import '../theme.dart';
import 'day_table_page.dart';

class ScheduleDaysPage extends StatefulWidget {
  final ClassSchedule schedule;

  const ScheduleDaysPage({super.key, required this.schedule});

  @override
  State<ScheduleDaysPage> createState() => _ScheduleDaysPageState();
}

class _ScheduleDaysPageState extends State<ScheduleDaysPage> {
  static const _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  Future<void> _openDay(int weekday) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayTablePage(
          schedule: widget.schedule,
          weekday: weekday,
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextPrimary),
        title: Text(
          widget.schedule.name,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.builder(
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              final weekday = i + 1;
              return InkWell(
                onTap: () => _openDay(weekday),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _dayNames[weekday]!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}