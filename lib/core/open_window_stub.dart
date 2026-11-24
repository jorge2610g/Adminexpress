/// Abre una pestaña en blanco (solo en navegador). Devuelve null si no se pudo.
Object? openBlankWindow() => null;

/// Lleva la pestaña a [url]. Devuelve false si no hay pestaña.
bool navigateWindow(Object? window, String url) => false;

void closeWindow(Object? window) {}
