import 'dart:io';
import 'dart:typed_data';

import 'package:adminexpress/admin_delivery_unified.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _fonts() async {
  const root = '/root/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
  Future<ByteData> r(String n) async =>
      ByteData.view(Uint8List.fromList(await File('$root/$n').readAsBytes()).buffer);
  final f = FontLoader('Roboto')
    ..addFont(r('Roboto-Regular.ttf'))
    ..addFont(r('Roboto-Medium.ttf'))
    ..addFont(r('Roboto-Bold.ttf'));
  await f.load();
  final i = FontLoader('MaterialIcons')..addFont(r('MaterialIcons-Regular.otf'));
  await i.load();
}

/// Captura de diseño en teléfono; solo con EXPRESS_GOLDEN=1.
final bool _skip = Platform.environment['EXPRESS_GOLDEN'] != '1';

void main() {
  if (_skip) return;
  setUpAll(() async {
    await _fonts();
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://127.0.0.1:1', anonKey: 'x');
  });
  testWidgets('Restaurantes y Delivery en teléfono', (tester) async {
    tester.view.physicalSize = const Size(390, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const Scaffold(
        body: AdminDeliveryUnifiedPage(channel: 'production', zoneId: 'z', countryCode: 'CL'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/admin_delivery_movil.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
