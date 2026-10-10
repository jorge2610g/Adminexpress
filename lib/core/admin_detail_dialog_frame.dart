import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';
import 'admin_widgets.dart';

/// White detail overlay used by the E3 driver, user and trip artboards.
/// Presentation only: permissions, channel selection and RPC calls stay in
/// their respective dialog state classes.
class AdminDetailDialogFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? status;
  final AdminStatusTone statusTone;
  final Widget child;
  final List<Widget> actions;

  const AdminDetailDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actions,
    this.icon = Icons.manage_accounts_rounded,
    this.status,
    this.statusTone = AdminStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 28).clamp(0.0, 820.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: width,
        height: size.height * .90,
        child: Material(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 540;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
                    decoration: const BoxDecoration(
                      color: AdminColors.surface,
                      border: Border(
                        bottom: BorderSide(color: AdminColors.border),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AdminColors.blueSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: AdminColors.blue, size: 21),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AdminColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (compact && status != null) ...[
                                const SizedBox(height: 8),
                                AdminStatusChip(status!, tone: statusTone),
                              ],
                            ],
                          ),
                        ),
                        if (!compact && status != null) ...[
                          const SizedBox(width: 8),
                          AdminStatusChip(status!, tone: statusTone),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: child,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                decoration: const BoxDecoration(
                  color: AdminColors.surface,
                  border: Border(
                    top: BorderSide(color: AdminColors.border),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
