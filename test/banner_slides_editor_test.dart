import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/banner_placement_dimensions.dart';
import '../lib/banner_slides_editor.dart';

void main() {
  test('recomienda medidas y marco según la posición', () {
    expect(bannerRecommendedDimensions('popup'), '1080 × 1920 px');
    expect(bannerFrameAspectRatio('popup'), 9 / 16);
    expect(bannerRecommendedDimensions('map_home'), '1280 × 400 px');
    expect(bannerFrameAspectRatio('map_home'), 3.2);
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
