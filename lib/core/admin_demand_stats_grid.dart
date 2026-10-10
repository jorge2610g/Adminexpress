import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Seven read-only price-demand indicators shown at the artboard width.
/// Uses values already returned by the existing scope-aware RPC.
class AdminDemandStatsGrid extends StatelessWidget {
  const AdminDemandStatsGrid({super.key, required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 7 : width >= 580 ? 4 : 2;
        const gap = 10.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 12),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    border: Border.all(color: AdminColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AdminColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
