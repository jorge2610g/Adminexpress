import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Four real, normalized ranking indicators arranged like the E4 Claude
/// artboard. Only visual presentation changes; no priority calculations.
class AdminPriorityMetrics extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const AdminPriorityMetrics({super.key, required this.metrics});

  static double value(Object? raw) {
    final parsed = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return parsed.clamp(0.0, 100.0).toDouble();
  }

  Widget _meter(String label, double rawValue) {
    final number = rawValue.clamp(0.0, 100.0).toDouble();
    final color = number >= 75
        ? AdminColors.ok
        : number >= 50
            ? AdminColors.warn
            : AdminColors.danger;
    return Semantics(
      label: '$label: ${number.toStringAsFixed(0)} de 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                number.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: number / 100,
              minHeight: 6,
              backgroundColor: AdminColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const names = <(String, String)>[
      ('rating', 'Reputación'),
      ('reviews', 'Reseñas'),
      ('experience', 'Experiencia'),
      ('frequency', 'Frecuencia'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 470 ? 4 : width >= 240 ? 2 : 1;
        const gap = 12.0;
        final itemWidth = (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final item in names)
              SizedBox(
                width: itemWidth,
                child: _meter(item.$2, value(metrics[item.$1])),
              ),
          ],
        );
      },
    );
  }
}
