import 'package:flutter/material.dart';
import '../models/class_schedule.dart';
import '../theme.dart';
import 'schedule_days_page.dart';

class ScheduleListPage extends StatefulWidget {
  const ScheduleListPage({super.key});

  @override
  State<ScheduleListPage> createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  Future<void> _addSchedule() async {
    final name = await _promptName();
    if (name == null || name.isEmpty) return;
    setState(() => appSchedules.add(ClassSchedule(name: name)));
  }

  Future<void> _editSchedule(int i) async {
    final name = await _promptName(initial: appSchedules[i].name);
    if (name == null || name.isEmpty) return;
    setState(() => appSchedules[i].name = name);
  }

  void _deleteSchedule(int i) {
    setState(() => appSchedules.removeAt(i));
  }

  Future<String?> _promptName({String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          initial.isEmpty ? 'New Schedule' : 'Rename Schedule',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. First term'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSchedule(ClassSchedule s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScheduleDaysPage(schedule: s)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Schedule list:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: appSchedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final s = appSchedules[i];
                    return InkWell(
                      onTap: () => _openSchedule(s),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: kSurfaceAlt,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: kBorder, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _editSchedule(i),
                              icon: const Icon(Icons.edit_outlined),
                              color: kTextPrimary,
                            ),
                            IconButton(
                              onPressed: () => _deleteSchedule(i),
                              icon: const Icon(Icons.delete_outline),
                              color: kDanger,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton(
              onPressed: _addSchedule,
              backgroundColor: kAccent,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: kTextPrimary),
            ),
          ),
        ),
      ],
    );
  }
}