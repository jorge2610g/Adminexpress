// Abrir otra pestaña desde el panel. El navegador solo permite abrirla de inmediato
// al pulsar un botón, así que se abre en blanco y luego se le pone la dirección.
export 'open_window_stub.dart' if (dart.library.html) 'open_window_web.dart';
