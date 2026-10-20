/// Traduce los códigos internos de estado a palabras que entiende quien administra.
///
/// Si el texto no es un código conocido se devuelve tal cual, así que es seguro usarlo
/// sobre cualquier etiqueta que ya esté en español.
const Map<String, String> _statusLabels = {
  'approved': 'Aprobado',
  'pending': 'Pendiente',
  'rejected': 'Rechazado',
  'expired': 'Vencido',
  'online': 'En línea',
  'offline': 'Desconectado',
  'busy': 'Ocupado',
  'on_trip': 'En viaje',
  'active': 'Activa',
  'inactive': 'Inactiva',
  'blocked': 'Bloqueada',
  'suspended': 'Suspendida',
  'passenger': 'Pasajero',
  'driver': 'Conductor',
  'in_progress': 'En curso',
  'completed': 'Completado',
  'cancelled': 'Cancelado',
  'canceled': 'Cancelado',
  'requested': 'Solicitado',
  'assigned': 'Asignado',
  'accepted': 'Aceptado',
  'draft': 'Borrador',
  'published': 'Publicado',
  'paused': 'Pausado',
  'open': 'Abierto',
  'resolved': 'Resuelto',
  'new': 'Nuevo',
  'ready': 'Lista',
  'building': 'En proceso',
  'queued': 'En cola',
  'failed': 'Fallida',
  'paid': 'Pagado',
  'under_review': 'En revisión',
  'driver_selected': 'Conductor asignado',
  'delivered': 'Entregado',
};

String friendlyStatus(String raw) =>
    _statusLabels[raw.trim().toLowerCase()] ?? raw;

/// Servicios de la app. Las claves vienen de service_catalog; «*» es «todos».
const Map<String, String> _serviceLabels = {
  'economy': 'Express',
  'comfort': 'Comfort',
  'xl': 'XL',
  'motorcycle': 'Moto',
  'delivery': 'Delivery',
  'parcel': 'Envíos',
  '*': 'Todos los servicios',
};

/// Nombre del servicio en español; una clave desconocida no se muestra tal cual.
String friendlyService(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return 'Servicio';
  return _serviceLabels[key] ?? 'Otro servicio';
}

const Map<String, String> _packageLabels = {
  'package': 'Paquete',
  'purchase': 'Compra',
  'document': 'Documento',
  'other': 'Otro',
};

/// Tipo de paquete de un pedido de delivery.
String friendlyPackage(String raw) =>
    _packageLabels[raw.trim().toLowerCase()] ?? 'Paquete';

final RegExp _trailingCoordinates =
    RegExp(r'\s*·\s*-?\d{1,3}\.\d+,\s*-?\d{1,3}\.\d+\s*$');

/// Quita las coordenadas numéricas del final de una dirección.
/// «Ubicación seleccionada · -20.21972, -70.14695» → «Ubicación seleccionada».
String friendlyAddress(String raw) => raw.replaceFirst(_trailingCoordinates, '').trim();

const Map<String, String> _auditLabels = {
  'driver_kyc_photo_review|driver_document': 'Revisión de documento de conductor',
  'driver_license_photo_review|driver_document': 'Revisión de foto de licencia',
  'manual_kyc_identity_decision|driver_document': 'Decisión manual de identidad',
  'upsert_driver_document|driver_document': 'Documento de conductor guardado',
  'admin_scope_confirmed|driver_document': 'Alcance de administrador confirmado',
  'upsert|driver_document_requirements': 'Requisitos de documentos actualizados',
  'update_driver_profile|driver_profile': 'Perfil de conductor actualizado',
  'admin_scope_confirmed|driver_profile': 'Alcance de administrador confirmado',
  'set_driver_approval|driver_profile': 'Aprobación de conductor actualizada',
  'driver_activate|driver_profile': 'Conductor activado',
  'upsert_zone_payment_method|service_zones': 'Método de pago de zona actualizado',
  'update_zone_landing|service_zone': 'Portada de zona actualizada',
  'upsert|service_zone_coverage': 'Cobertura de zona actualizada',
  'upsert|service_zone_polygon': 'Polígono de zona guardado',
  'upsert_special_fare_zone|special_fare_zone': 'Zona de tarifa especial guardada',
  'create|marketplace_demo_restaurant': 'Negocio de prueba creado',
  'create|build_job': 'Compilación creada',
  'create|single_app_candidate': 'Versión candidata creada',
  'approve|preview_build': 'Compilación de prueba aprobada',
  'upsert|environment_config': 'Configuración de pruebas internas actualizada',
  'upsert|driver_championship': 'Campeonato guardado',
  'update|service_catalog': 'Catálogo de servicios actualizado',
  'update|advanced_app_settings': 'Configuración avanzada actualizada',
  'update|app_settings': 'Configuración general actualizada',
  'resolve|emergency': 'Emergencia resuelta',
  'send_announcement|notifications': 'Aviso enviado',
  'manual_assign|ride_request': 'Viaje asignado manualmente',
  'assign_partner_member|partner_member': 'Miembro de socio asignado',
};

const Map<String, String> _auditVerbs = {
  'create': 'Registro creado',
  'upsert': 'Registro guardado',
  'update': 'Registro actualizado',
  'approve': 'Aprobación registrada',
  'resolve': 'Caso resuelto',
};

/// Título legible de una fila de auditoría. Nunca muestra el código interno.
String friendlyAudit(String action, String entity) {
  final a = action.trim().toLowerCase();
  final e = entity.trim().toLowerCase();
  return _auditLabels['$a|$e'] ?? _auditVerbs[a] ?? 'Cambio registrado';
}

const Map<String, String> _categoryLabels = {
  'restaurants': 'Restaurantes',
  'restaurant': 'Restaurante',
  'markets': 'Mercados',
  'market': 'Mercado',
  'pharmacies': 'Farmacias',
  'stores': 'Tiendas',
};

/// Categorías de comercios: se muestran con su nombre en español, no con la clave interna.
String friendlyCategory(String raw) =>
    _categoryLabels[raw.trim().toLowerCase()] ?? raw;

const Map<String, String> _vehicleLabels = {
  'car': 'Auto',
  'auto': 'Auto',
  'motorcycle': 'Moto',
  'moto': 'Moto',
  'xl': 'XL',
  'comfort': 'Comfort',
};

/// Tipos de vehículo; un valor vacío o desconocido se oculta en lugar de mostrar «none».
String friendlyVehicle(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty || key == 'none' || key == 'null') return '';
  return _vehicleLabels[key] ?? raw;
}

const Map<String, String> _dispatchLabels = {
  'broadcast': 'Difusión a conductores disponibles',
  'progressive': 'Progresivo',
  'nearest': 'Conductor más cercano',
  'manual': 'Manual',
};

/// Modo de despacho de viajes, en el lenguaje de la operación.
String friendlyDispatch(String raw) =>
    _dispatchLabels[raw.trim().toLowerCase()] ?? raw;
