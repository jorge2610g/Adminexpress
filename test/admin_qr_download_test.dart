import 'dart:io';
import 'dart:ui' as ui;

import 'package:adminexpress/admin_qr_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// El QR de los enlaces de descarga se genera, se descarga y se comparte desde el panel.
void main() {
  const url = 'https://expressviajes.online/app/';

  test('la matriz del QR es cuadrada y tiene los tres cuadros de posición', () {
    final modules = adminQrModules(url);
    expect(modules, isNotEmpty);
    for (final row in modules) {
      expect(row.length, modules.length);
    }
    final last = modules.length - 1;
    // Esquina de cada cuadro de posición (superior izquierda, derecha y abajo).
    expect(modules[0][0], isTrue);
    expect(modules[0][last], isTrue);
    expect(modules[last][0], isTrue);
  });

  test('el QR cambia cuando cambia el enlace', () {
    final a = adminQrModules('https://play.google.com/store/apps/details?id=com.express.usuario1');
    final b = adminQrModules('https://apps.apple.com/app/express/id1');
    expect(a.toString() == b.toString(), isFalse);
  });

  test('el SVG es vectorial, con margen blanco y sin datos del servidor', () {
    final svg = adminQrSvg(url);
    expect(svg, startsWith('<?xml'));
    expect(svg, contains('viewBox="0 0 '));
    expect(svg, contains('fill="#ffffff"'));
    expect(svg, contains('fill="#000000"'));
  });

  testWidgets('el PNG se genera con la firma PNG y tamaño grande', (tester) async {
    await tester.runAsync(() async {
      final bytes = await adminQrPng(url);
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, frame.image.height);
      expect(frame.image.width, greaterThanOrEqualTo(1000));
    });
  });

  test('la pantalla de enlaces ofrece descargar, compartir y copiar el QR', () {
    final screen = File('lib/admin_app_download_links.dart').readAsStringSync();
    expect(screen, contains('AdminQrPanel('));
    expect(screen, contains("'Descargar PNG'"));
    expect(screen, contains("'Descargar SVG'"));
    expect(screen, contains("'Compartir'"));
    expect(screen, contains("'Copiar enlace'"));
    // Hay un solo QR (el permanente) y no uno por plataforma.
    expect('AdminQrPanel('.allMatches(screen).length, 2); // uso + definición de clase no cuenta
    expect(screen, isNot(contains("'qr-express-\$platform'")));
    expect(screen, contains("fileBase: 'qr-express-app'"));
    // El QR permanente sigue apuntando a la página /app.
    expect(screen, contains("static const qrUrl = 'https://expressviajes.online/app/'"));
  });
}
