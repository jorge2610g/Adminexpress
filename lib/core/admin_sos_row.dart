import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// SOS list presentation from page 9 of Claude's 54-page Express PDF.
///
/// Channel-sensitive resolution and role checks are owned by the parent.
class AdminSosRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback? onResolve;

  const AdminSosRow({
    super.key,
    required this.row,
    this.onResolve,
  });

  String read(String key, [String fallback = '—']) {
    final raw = row[key]?.toString().trim();
    return raw == null || raw.isEmpty ? fallback : raw;
  }

  @override
  Widget build(BuildContext context) {
    final status = read('status', 'open').toLowerCase();
    final open = status == 'open';
    final statusText = switch (status) {
      'open' => 'Abierta',
      'acknowledged' => 'Atendida',
      'resolved' => 'Resuelta',
      _ => read('status'),
    };
    final when = DateTime.tryParse(read('created_at', ''))?.toLocal();
    final dateText = when == null
        ? read('created_at')
        : '${when.day.toString().padLeft(2, '0')}/'
            '${when.month.toString().padLeft(2, '0')}/${when.year} '
            '${when.hour.toString().padLeft(2, '0')}:'
            '${when.minute.toString().padLeft(2, '0')}';
    final accent = open ? AdminColors.danger : AdminColors.warn;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: accent),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 17,
              backgroundColor:
                  open ? AdminColors.dangerSoft : AdminColors.warnSoft,
              child: Icon(
                Icons.sos_rounded,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      read('user_name', 'Usuario Express'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '● $statusText',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          dateText,
                          style: const TextStyle(
                            color: AdminColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onResolve != null)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 14),
                child: FilledButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Resolver'),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
