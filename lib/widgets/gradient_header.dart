import 'package:flutter/material.dart';
import '../theme.dart';

const kHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFDE5C),
    Color(0xFFFFD12B),
    Color(0xFFFFC107),
  ],
);

class GradientHeaderScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? action;
  final bool showBack;

  const GradientHeaderScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.action,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    const radius = 28.0;

    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: kHeaderGradient),
            padding: EdgeInsets.fromLTRB(24, top + 14, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        iconSize: 18,
                        color: kTextPrimary,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      )
                    else if (leading != null)
                      leading!,
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (action != null)
                      action!
                    else
                      const SizedBox(width: 32),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTextPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                const SizedBox(height: 44),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -radius),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}