import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/open_window.dart';
import 'core/supabase_client.dart';

const _restaurantPortalUrl = 'https://expressviajes.online/restaurantes/';

/// «Ir al panel del restaurante»: abre el portal real de restaurantes con un acceso
/// temporal (30 minutos) como la cuenta dueña. Desde ahí se editan productos, horarios,
/// perfil y todo lo demás, igual que lo ve el restaurante. Cada acceso queda registrado.
Future<void> goToRestaurantPanel(
    BuildContext context, Map<String, dynamic> merchant) async {
  final messenger = ScaffoldMessenger.of(context);
  // Se abre ya, durante el clic, para que el navegador no bloquee la ventana.
  final window = openBlankWindow();
  try {
    final result = await supabase.functions.invoke(
      'admin-restaurant-access',
      body: {'action': 'enter_panel', 'merchant_id': merchant['id']},
    );
    final data = result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : <String, dynamic>{};
    final token = data['token_hash']?.toString();
    if (result.status < 200 || result.status >= 300 || token == null) {
      throw StateError(
          data['error']?.toString() ?? 'No se pudo crear el acceso temporal.');
    }
    final url = Uri.parse(_restaurantPortalUrl)
        .replace(queryParameters: {'admin_access': token}).toString();
    if (!navigateWindow(window, url)) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    }
    messenger.showSnackBar(SnackBar(
        content: Text(
            'Entrando al panel de ${merchant['name'] ?? 'el restaurante'} (acceso temporal de 30 minutos).')));
  } catch (error) {
    closeWindow(window);
    var message = error.toString().replaceFirst('Bad state: ', '');
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] != null) {
        message = details['error'].toString();
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
