import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Exclusive zone coverage selector, matching Claude's E7 territory editor.
///
/// The value remains owned by the existing form; selecting either option
/// changes only the UI's active coverage mode, not the saved zone itself.
class AdminZoneCoverageModeSelector extends StatelessWidget {
  const AdminZoneCoverageModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final String mode;
  final ValueChanged<String> onChanged;

  Widget _option({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required double width,
  }) {
    final selected = mode == value;
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? AdminColors.blueSoft : AdminColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? AdminColors.blue : AdminColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!selected) onChanged(value);
          },
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 24,
                    color: selected ? AdminColors.blue : AdminColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.ink,
                        )),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: selected ? AdminColors.blue : AdminColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = constraints.maxWidth;
        final itemWidth = width < 530 ? width : (width - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _option(
              value: 'radius',
              title: 'Radio',
              description: 'Centro y distancia en kilómetros.',
              icon: Icons.radar_rounded,
              width: itemWidth,
            ),
            _option(
              value: 'polygon',
              title: 'Polígono',
              description: 'Perímetro exacto dibujado en el mapa.',
              icon: Icons.polyline_rounded,
              width: itemWidth,
            ),
          ],
        );
      },
    );
  }
}
