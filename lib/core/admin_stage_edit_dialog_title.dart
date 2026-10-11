import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Compact white form heading used by the six E4 Claude dialog artboards.
/// Purely visual: no form state, backend call or permission change.
class AdminStageEditDialogTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AdminStageEditDialogTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AdminColors.blueSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AdminColors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
