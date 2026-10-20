/// Only the operational and QA modules are shown when an admin account is
/// bound to Preview. Shared business settings remain centrally administered
/// by Production; no service zones or database records are duplicated here.
///
/// This is a navigation policy, not a replacement for Supabase permissions.
const Set<int> previewOperationalSections = <int>{
  0,  // Dashboard
  1,  // Operación en vivo
  2,  // Viajes
  3,  // Delivery: solicitudes y entregas de prueba
  4,  // Conductores
  5,  // Usuarios
  6,  // Seguridad / SOS operativa
  13, // Despacho manual
  20, // Entornos de prueba
  21, // Prueba de carga
  25, // Prioridad conductores
  29, // Campeonato Express
};

/// Production keeps its existing navigation and role/module checks unchanged.
bool isSectionVisibleForRuntime(String runtime, int index) =>
    runtime != 'preview' || previewOperationalSections.contains(index);
