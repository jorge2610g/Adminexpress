import 'package:flutter/material.dart';

/// Layout-only replacement for fixed horizontal field rows in E7 dialogs.
class AdminResponsiveFormGrid extends StatelessWidget {
  const AdminResponsiveFormGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 620
            ? children.length
            : width >= 370
                ? 2
                : 1;
        const gap = 8.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
