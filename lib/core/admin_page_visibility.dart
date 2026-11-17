import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Indica si la pestaña del panel está visible. Los sondeos automáticos (mapa
/// en vivo y SOS) se pausan con la pestaña oculta y se reanudan solos al volver,
/// en el siguiente tick. Fuera de la web se considera siempre visible.
bool adminPageIsVisible() {
  if (!kIsWeb) return true;
  return !web.document.hidden;
}
