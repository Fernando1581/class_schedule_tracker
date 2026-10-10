import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/gradient_header.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _service = FirestoreService();
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  DateTime _phToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _editNote(String docId, Note n) async {
    final textController = TextEditingController(text: n.text);
    DateTime picked = n.date;

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
                    'Edit note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final today = _phToday();
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: picked.isBefore(today) ? today : picked,
                        firstDate: today,
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
      await _service.updateNote(docId, result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteNote(String docId) async {
    await _service.deleteNote(docId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final today = _phToday();
    final tomorrow = today.add(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    return GradientHeaderScaffold(
      title: 'Notes',
      subtitle: 'Reminders for upcoming deadlines',
      child: StreamBuilder<List<MapEntry<String, Note>>>(
        stream: _service.streamNotes(_userId),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];

          final keep = <MapEntry<String, Note>>[];
          for (final e in all) {
            final d = DateTime(
                e.value.date.year, e.value.date.month, e.value.date.day);
            if (d.isBefore(twoDaysAgo)) {
              _service.deleteNote(e.key);
            } else {
              keep.add(e);
            }
          }

          final todayNotes = <MapEntry<String, Note>>[];
          final tomorrowNotes = <MapEntry<String, Note>>[];
          final upcomingNotes = <MapEntry<String, Note>>[];

          for (final e in keep) {
            final d = DateTime(
                e.value.date.year, e.value.date.month, e.value.date.day);
            if (d == today) {
              todayNotes.add(e);
            } else if (d == tomorrow) {
              tomorrowNotes.add(e);
            } else if (d.isAfter(tomorrow)) {
              upcomingNotes.add(e);
            }
          }

          upcomingNotes.sort((a, b) => a.value.date.compareTo(b.value.date));

          if (todayNotes.isEmpty &&
              tomorrowNotes.isEmpty &&
              upcomingNotes.isEmpty) {
            return _buildEmpty();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              _buildSection('Today', todayNotes),
              _buildSection('Tomorrow', tomorrowNotes),
              _buildSection('Upcoming', upcomingNotes),
            ],
          );
        },
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
                Icons.sticky_note_2_outlined,
                size: 36,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Add note" during a class\nto create a reminder.',
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

  Widget _buildSection(String title, List<MapEntry<String, Note>> notes) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ),
        ...notes.map((e) => _NoteBlock(
              note: e.value,
              onEdit: () => _editNote(e.key, e.value),
              onDelete: () => _deleteNote(e.key),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteBlock({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 90),
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
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 22,
                    color: kTextPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.text,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: kTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _fmtDate(note.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}