import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final panel = File('lib/admin_panel.dart').readAsStringSync();

  test('Beneficios usa el último índice real y abre su página', () {
    final sectionsStart = panel.indexOf(
      'static const sections = <(String, IconData)>[',
    );
    final sectionsEnd = panel.indexOf('\n  ];', sectionsStart);
    expect(sectionsStart, isNonNegative);
    expect(sectionsEnd, greaterThan(sectionsStart));
    final sectionBlock = panel.substring(sectionsStart, sectionsEnd);
    final labels = RegExp(r"\('([^']+)',\s*Icons\.[^)]+\)")
        .allMatches(sectionBlock)
        .map((match) => match.group(1)!)
        .toList();

    expect(labels, hasLength(42));
    expect(labels[24], 'Delivery Fase 2 / Express Plus');
    expect(labels[35], 'Beneficios Express');
    expect(labels[36], 'Publicidad de pasajeros');
    expect(labels[37], 'Asesores de ventas');
    expect(labels[38], 'Billeteras');
    expect(labels[39], 'Viajes sospechosos');
    expect(labels[40], 'Solicitudes de conductores');
    expect(labels[41], 'Soporte');
    expect(panel, contains("39: 'trips'"));
    expect(panel, contains("35: 'benefits'"));
    expect(panel, contains("if (index == 35 && adminAccess['role'] == 'super_admin')"));
    expect(panel, contains("36: 'passenger_ads'"));
    expect(panel, contains("if (index == 36 && adminAccess['role'] == 'super_admin')"));
    expect(panel, contains('case 35:\n        return AdminBenefitsPage('));
    expect(panel, contains('_sectionChannel(35)'));

    final environmentBlock = RegExp(
      r'static const Set<int> _environmentFilteredSections = <int>\{([^}]+)\}',
    ).firstMatch(panel);
    expect(environmentBlock, isNotNull);
    final environmentIndices = RegExp(r'\d+')
        .allMatches(environmentBlock!.group(1)!)
        .map((match) => int.parse(match.group(0)!))
        .toSet();
    expect(environmentIndices, contains(35));
  });

  test('el menú fusiona Restaurantes con Delivery y conserva Beneficios', () {
    final moduleGroup = RegExp(r"\('MÓDULOS', \[([^\]]+)\]\)")
        .firstMatch(panel);
    expect(moduleGroup, isNotNull);
    final indices = RegExp(r'\d+')
        .allMatches(moduleGroup!.group(1)!)
        .map((match) => int.parse(match.group(0)!))
        .toList();

    // «Restaurantes y Delivery» (23) reúne lo de Restaurantes (30) y Requisitos (34).
    expect(indices, [23, 25, 29, 35, 36, 37]);
    expect(indices, isNot(contains(24)));
    expect(indices, isNot(contains(26)));
    expect(indices, isNot(contains(30)));
    expect(indices, isNot(contains(34)));
  });

  test('Billeteras aparece en el menú, dentro de Finanzas', () {
    final panel = File('lib/admin_panel.dart').readAsStringSync();
    expect(panel, contains("('FINANZAS', [9, 38, 8, 22, 33])"));
  });
}
