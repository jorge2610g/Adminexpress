import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/banner_slides_editor.dart';
import 'dart:ui' as ui;

void main() {
  test('solo acepta imágenes de 1280 por 400 píxeles', () async {
    for (final size in [
      const ui.Size(1280, 400),
      const ui.Size(1200, 400),
    ]) {
      final bytes = await _png(size);
      expect(
        await isBannerImage1280x400(bytes),
        size == const ui.Size(1280, 400),
      );
    }
  });

  testWidgets('permite reordenar, cambiar enlace y quitar slides',
      (tester) async {
    final slides = [
      BannerSlideDraft(
          imageUrl: 'https://cdn.example/a.webp',
          targetUrl: 'https://a.example'),
      BannerSlideDraft(
          imageUrl: 'https://cdn.example/b.webp',
          targetUrl: 'https://b.example'),
    ];
    var changed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BannerSlidesEditor(
            slides: slides,
            onChanged: () => changed++,
            onError: fail,
          ),
        ),
      ),
    ));

    expect(find.textContaining('1280 × 400 px'), findsOneWidget);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio,
      3.2,
    );

    await tester.tap(find.byTooltip('Subir imagen de posición').last);
    await tester.pumpAndSettle();
    expect(slides.first.imageUrl, 'https://cdn.example/b.webp');
    expect(changed, 1);

    await tester.enterText(
        find.byType(TextFormField).first, 'https://new.example');
    expect(slides.first.targetUrl, 'https://new.example');

    await tester.tap(find.byTooltip('Quitar imagen 1'));
    await tester.pumpAndSettle();
    expect(slides, hasLength(1));
    expect(slides.single.imageUrl, 'https://cdn.example/a.webp');
    expect(tester.takeException(), isNull);
  });
}

Future<Uint8List> _png(ui.Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
