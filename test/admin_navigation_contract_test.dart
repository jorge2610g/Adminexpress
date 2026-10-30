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

    expect(labels, hasLength(36));
    expect(labels[24], 'Delivery Fase 2 / Express Plus');
    expect(labels[35], 'Beneficios Express');
    expect(panel, contains("35: 'benefits'"));
    expect(panel, contains("if (index == 35 && adminAccess['role'] == 'super_admin')"));
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

  test('el menú conserva la fusión de Delivery y agrega solo Beneficios', () {
    final moduleGroup = RegExp(r"\('MÓDULOS', \[([^\]]+)\]\)")
        .firstMatch(panel);
    expect(moduleGroup, isNotNull);
    final indices = RegExp(r'\d+')
        .allMatches(moduleGroup!.group(1)!)
        .map((match) => int.parse(match.group(0)!))
        .toList();

    expect(indices, [23, 25, 29, 30, 34, 35]);
    expect(indices, isNot(contains(24)));
    expect(indices, isNot(contains(26)));
  });
}
