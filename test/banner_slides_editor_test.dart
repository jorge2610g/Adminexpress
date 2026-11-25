import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/banner_slides_editor.dart';

void main() {
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
