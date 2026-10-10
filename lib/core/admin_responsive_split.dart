import 'package:flutter/material.dart';

/// Two independent scrollable columns on desktop and one continuous list on
/// compact screens. Used by dense reference screens such as E6 Avisos.
class AdminResponsiveSplit extends StatelessWidget {
  const AdminResponsiveSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 960,
    this.gap = 14,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 22),
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final double breakpoint;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return ListView(
            padding: padding,
            children: [
              ...primary,
              SizedBox(height: gap),
              ...secondary,
            ],
          );
        }
        return Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: primary,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: secondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
