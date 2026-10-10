import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/gradient_header.dart';
import 'schedule_days_page.dart';

class ScheduleListPage extends StatefulWidget {
  const ScheduleListPage({super.key});

  @override
  State<ScheduleListPage> createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  final _service = FirestoreService();
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _addSchedule() async {
    final name = await _promptName();
    if (name == null || name.isEmpty) return;

    final schedule = ClassSchedule(name: name);
    await _service.saveSchedule(schedule, _userId);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editSchedule(ClassSchedule s) async {
    final name = await _promptName(initial: s.name);
    if (name == null || name.isEmpty || name == s.name) return;

    await _service.deleteSchedule(_userId, s.name);
    final renamed = ClassSchedule(name: name, days: s.days);
    await _service.saveSchedule(renamed, _userId);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSchedule(ClassSchedule s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete schedule?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('"${s.name}" and all its classes will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: kDanger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _service.deleteSchedule(_userId, s.name);
    await _service.setActiveSchedule(_userId, null);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActive(ClassSchedule s, String? currentActive) async {
    final newValue = currentActive == s.name ? null : s.name;
    await _service.setActiveSchedule(_userId, newValue);
    if (!mounted) return;
    setState(() {});
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
          initial.isEmpty ? 'New schedule' : 'Rename schedule',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. First term',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSchedule(ClassSchedule s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleDaysPage(schedule: s, userId: _userId),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderScaffold(
      title: 'Schedule list',
      subtitle: 'Manage your classes',
      child: Stack(
        children: [
          StreamBuilder<List<ClassSchedule>>(
            stream: _service.streamSchedules(_userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: kAccent),
                );
              }

              final list = snapshot.data ?? [];

              if (list.isEmpty) {
                return _buildEmpty();
              }

              return StreamBuilder<String?>(
                stream: _service.streamActiveSchedule(_userId),
                builder: (context, activeSnap) {
                  final active = activeSnap.data;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final isActive = s.name == active;
                      return _ScheduleCard(
                        schedule: s,
                        isActive: isActive,
                        onTap: () => _openSchedule(s),
                        onEdit: () => _editSchedule(s),
                        onDelete: () => _deleteSchedule(s),
                        onActivate: () => _setActive(s, active),
                      );
                    },
                  );
                },
              );
            },
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
                child: const Icon(
                  Icons.add,
                  color: kTextPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: kAccentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No schedules yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the + button to create your\nfirst schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: kTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ClassSchedule schedule;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onActivate;

  const _ScheduleCard({
    required this.schedule,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? kAccentSoft : kSurfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? kAccent : kBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onActivate,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? kAccent : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? kAccent : kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_rounded
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: isActive ? kTextPrimary : kTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      schedule.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    if (isActive)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Active on timer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: kTextPrimary,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: kDanger,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  } 
}