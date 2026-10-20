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

/// Account-specific access is always the intersection of the visible runtime
/// menu, the role, and the server-provided *effective* modules. In particular,
/// 'assigned_modules' (including modules not yet runtime-ready) must not be
/// substituted for 'allowed_modules' returned by admin_access_context.
bool isAdminSectionAllowed({
  required String runtime,
  required int section,
  required String role,
  required Set<String> effectiveModules,
  required Map<int, String> moduleKeys,
}) {
  if (!isSectionVisibleForRuntime(runtime, section)) return false;
  if (section == 18 || section == 27) return false;
  if (section == 32 && role != 'super_admin') return false;
  if (section == 23 && role == 'operator') return false;
  final module = moduleKeys[section];
  if (module == null) return false;
  return effectiveModules.contains('*') || effectiveModules.contains(module);
}
