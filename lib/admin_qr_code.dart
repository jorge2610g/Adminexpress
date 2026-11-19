import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Matriz de módulos de un QR (true = módulo oscuro), con corrección de
/// errores alta para que se lea aunque se imprima pequeño o se ensucie.
List<List<bool>> adminQrModules(String data) {
  final code = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.H,
  );
  final image = QrImage(code);
  return List<List<bool>>.generate(
    image.moduleCount,
    (row) => List<bool>.generate(
      image.moduleCount,
      (col) => image.isDark(row, col),
    ),
  );
}

/// QR en SVG vectorial (para imprenta o carteles). [border] son módulos de
/// margen blanco; el estándar pide al menos 4.
String adminQrSvg(String data, {int border = 4}) {
  final modules = adminQrModules(data);
  final size = modules.length + border * 2;
  final path = StringBuffer();
  for (var row = 0; row < modules.length; row++) {
    for (var col = 0; col < modules.length; col++) {
      if (modules[row][col]) {
        path.write('M${col + border},${row + border}h1v1h-1z');
      }
    }
  }
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" '
      'width="${size * 10}" height="${size * 10}" shape-rendering="crispEdges">'
      '<rect width="$size" height="$size" fill="#ffffff"/>'
      '<path d="$path" fill="#000000"/></svg>';
}

/// QR en PNG de [pixels] por lado, negro sobre blanco y con margen.
Future<Uint8List> adminQrPng(
  String data, {
  int pixels = 1200,
  int border = 4,
}) async {
  final modules = adminQrModules(data);
  final total = modules.length + border * 2;
  final cell = (pixels / total).floor().clamp(1, 100000);
  final side = cell * total;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..color = Colors.white,
  );
  final dark = Paint()
    ..color = Colors.black
    ..isAntiAlias = false;
  for (var row = 0; row < modules.length; row++) {
    for (var col = 0; col < modules.length; col++) {
      if (modules[row][col]) {
        canvas.drawRect(
          Rect.fromLTWH(
            ((col + border) * cell).toDouble(),
            ((row + border) * cell).toDouble(),
            cell.toDouble(),
            cell.toDouble(),
          ),
          dark,
        );
      }
    }
  }
  final image = await recorder.endRecording().toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) throw StateError('No se pudo generar la imagen del QR');
  return bytes.buffer.asUint8List();
}

/// Vista previa del QR dentro del panel.
class AdminQrView extends StatelessWidget {
  const AdminQrView({super.key, required this.data, this.size = 180});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final modules = adminQrModules(data);
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(size / (modules.length + 8) * 2),
      child: CustomPaint(painter: _QrPainter(modules)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.modules);

  final List<List<bool>> modules;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / modules.length;
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < modules.length; row++) {
      for (var col = 0; col < modules.length; col++) {
        if (modules[row][col]) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell + 0.4, cell + 0.4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.modules != modules;
}
