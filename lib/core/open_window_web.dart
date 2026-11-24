import 'dart:html' as html;

Object? openBlankWindow() {
  try {
    return html.window.open('about:blank', '_blank');
  } catch (_) {
    return null;
  }
}

bool navigateWindow(Object? window, String url) {
  if (window is! html.WindowBase) return false;
  try {
    window.location.href = url;
    return true;
  } catch (_) {
    return false;
  }
}

void closeWindow(Object? window) {
  if (window is html.WindowBase) {
    try {
      window.close();
    } catch (_) {}
  }
}
