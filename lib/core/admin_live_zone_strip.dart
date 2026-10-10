import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Live operation zone selector. Shows every backend zone and provides
/// explicit previous/next controls for cramped desktop and touch layouts.
/// This component has no networking or filtering side effects: it reports
/// only the requested zone ID to the parent.
class AdminLiveZoneStrip extends StatefulWidget {
  final List<Map<String, dynamic>> zones;
  final String? selectedZoneId;
  final ValueChanged<String?> onSelected;

  const AdminLiveZoneStrip({
    super.key,
    required this.zones,
    required this.selectedZoneId,
    required this.onSelected,
  });

  @override
  State<AdminLiveZoneStrip> createState() => _AdminLiveZoneStripState();
}

class _AdminLiveZoneStripState extends State<AdminLiveZoneStrip> {
  final ScrollController _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshArrows());
  }

  @override
  void didUpdateWidget(covariant AdminLiveZoneStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zones.length != widget.zones.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshArrows());
    }
  }

  void _refreshArrows() {
    if (!mounted || !_controller.hasClients) return;
    final pos = _controller.position;
    final back = pos.pixels > pos.minScrollExtent + 2;
    final forward = pos.pixels < pos.maxScrollExtent - 2;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _scroll(bool forward) {
    if (!_controller.hasClients) return;
    final current = _controller.offset;
    final target = (current + (forward ? 210 : -210)).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    ).toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshArrows);
    _controller.dispose();
    super.dispose();
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? dot,
    IconData? icon,
  }) {
    return Material(
      color: selected ? AdminColors.blue : AdminColors.surfaceSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 39),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AdminColors.blue : AdminColors.borderSoft,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : AdminColors.muted,
                )
              else if (dot != null)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AdminColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF0B57D0),
      Color(0xFF12B76A),
      Color(0xFFF79009),
      Color(0xFF7A2CF3),
      Color(0xFF06AED4),
      Color(0xFFEF4444),
    ];

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.borderSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _chip(
            label: 'Todas las zonas',
            selected: widget.selectedZoneId == null,
            icon: Icons.grid_view_rounded,
            onTap: () => widget.onSelected(null),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ver zonas anteriores',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _canBack ? () => _scroll(false) : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: ListView.separated(
              key: const ValueKey('admin-live-zones-scroll'),
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: widget.zones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final zone = widget.zones[index];
                final id = zone['id']?.toString() ?? '';
                return _chip(
                  label: zone['name']?.toString() ?? 'Zona',
                  selected: id.isNotEmpty && id == widget.selectedZoneId,
                  dot: palette[index % palette.length],
                  onTap: () => widget.onSelected(id.isEmpty ? null : id),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Ver más zonas',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _canForward ? () => _scroll(true) : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
