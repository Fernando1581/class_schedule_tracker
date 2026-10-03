import 'package:flutter/material.dart';
import '../theme.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: const SafeArea(child: SizedBox.shrink()),
    );
  }
}