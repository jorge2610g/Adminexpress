import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/admin_landing_banners.dart';
import '../lib/banner_calendar_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://banner-test.example',
        anonKey: 'test',
        httpClient: MockClient((_) async => http.Response('[]', 200,
            headers: {'content-type': 'application/json'})));
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('invalid save keeps the dialog open and preserves draft',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AdminLandingBannersPage(
                channel: 'preview', zoneId: 'test-zone'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear Banner'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Crear Banner').last;
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('El título interno es obligatorio.'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Título interno *');
    final description = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == 'Descripción interna');
    await tester.enterText(title, 'Promoción guardada en borrador');
    await tester.enterText(description, 'Mi nota interna');
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Sube una imagen para el banner.'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.widget<TextField>(title).controller!.text,
        'Promoción guardada en borrador');
    expect(tester.widget<TextField>(description).controller!.text,
        'Mi nota interna');
    expect(find.text('URL de imagen (opcional)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dates are picked from calendar and can be cleared',
      (tester) async {
    DateTime? selected = DateTime(2026, 11, 1);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, update) => BannerCalendarField(
          label: 'Inicio',
          value: selected,
          onChanged: (date) => update(() => selected = date)),
    ))));
    await tester.tap(find.byTooltip('Abrir calendario'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 11, 15));
    expect(find.text('15/11/2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar fecha'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Seleccionar fecha'), findsOneWidget);
  });
}
