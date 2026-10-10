import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

class AdminPageHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final String? badge;

  const AdminPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.bolt_rounded,
    this.trailing,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 9,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.ok,
                      borderRadius: BorderRadius.circular(AdminRadius.pill),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AdminColors.headerMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        );

        final emblem = Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Icon(icon, color: Colors.white, size: compact ? 21 : 24),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 22,
            18,
            compact ? 16 : 22,
            18,
          ),
          decoration: BoxDecoration(
            gradient: AdminGradients.hero,
            borderRadius: BorderRadius.circular(AdminRadius.hero),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33174B91),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        emblem,
                        const SizedBox(width: 12),
                        Expanded(child: heading),
                      ],
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    emblem,
                    const SizedBox(width: 14),
                    Expanded(child: heading),
                    if (trailing != null) ...[
                      const SizedBox(width: 14),
                      trailing!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool elevated;
  final double radius;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.elevated = false,
    this.radius = AdminRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AdminColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AdminColors.border),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class AdminSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const AdminSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.blueSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AdminColors.blue, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminText.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AdminText.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

enum AdminStatusTone { neutral, info, success, warning, danger, purple }

class AdminStatusChip extends StatelessWidget {
  final String label;
  final AdminStatusTone tone;
  final bool dot;

  const AdminStatusChip(
    this.label, {
    super.key,
    this.tone = AdminStatusTone.neutral,
    this.dot = true,
  });

  (Color, Color) get colors => switch (tone) {
        AdminStatusTone.info => (AdminColors.blueSoft, AdminColors.blue),
        AdminStatusTone.success => (AdminColors.okSoft, AdminColors.ok),
        AdminStatusTone.warning => (AdminColors.warnSoft, AdminColors.warn),
        AdminStatusTone.danger => (AdminColors.dangerSoft, AdminColors.danger),
        AdminStatusTone.purple => (AdminColors.purpleSoft, AdminColors.purple),
        AdminStatusTone.neutral => (
            const Color(0xFFF2F4F7),
            const Color(0xFF475467),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final pair = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: pair.$1,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: pair.$2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: pair.$2,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int desktopColumns;
  final int tabletColumns;

  const AdminResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 14,
    this.desktopColumns = 4,
    this.tabletColumns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AdminBreakpoints.phone
            ? 1
            : width < AdminBreakpoints.desktop
                ? tabletColumns
                : desktopColumns;
        final itemWidth =
            (width - (spacing * (columns - 1))) / columns.clamp(1, 99);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AdminEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AdminColors.blueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AdminColors.blue, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AdminText.caption,
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AdminEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'No se pudo cargar',
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Reintentar'),
            ),
    );
  }
}
