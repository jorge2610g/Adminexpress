import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_live_zone_strip.dart';

void main() {
  testWidgets('Zone list is horizontally scrollable', (tester) async {
    String? selected;
    final rows = List<Map<String, dynamic>>.generate(9,
      (i) => {'id': 'z$i', 'name': 'Zona $i'});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 500,
          child: AdminLiveZoneStrip(
            zones: rows,
            selectedZoneId: null,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    ));
    expect(find.text('Todas las zonas'), findsOneWidget);
    expect(find.byTooltip('Ver más zonas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Zona 8'), 140,
      scrollable: find.byType(Scrollable).last, maxScrolls: 15);
    await tester.tap(find.text('Zona 8'));
    expect(selected, 'z8');
    expect(tester.takeException(), isNull);
  });
}
