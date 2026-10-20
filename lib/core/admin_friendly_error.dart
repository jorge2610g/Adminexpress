/// Convierte un error técnico en un mensaje claro para el administrador.
///
/// El detalle técnico no se muestra en pantalla: quien administra necesita saber qué
/// pasó y qué puede hacer, no el nombre de una función ni un código de la base de datos.
String friendlyError(Object? error) {
  final raw = (error ?? '').toString().toLowerCase();
  if (raw.contains('invalid login') || raw.contains('invalid_credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (raw.contains('no autorizado') ||
      raw.contains('permission denied') ||
      raw.contains('not authorized') ||
      raw.contains('forbidden')) {
    return 'Tu cuenta no tiene acceso a esta información.';
  }
  if (raw.contains('jwt') ||
      raw.contains('session expired') ||
      raw.contains('sesión')) {
    return 'Tu sesión venció. Vuelve a entrar al panel.';
  }
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network') ||
      raw.contains('connection') ||
      raw.contains('timeout')) {
    return 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';
  }
  return 'No se pudo completar la acción. Intenta de nuevo.';
}
