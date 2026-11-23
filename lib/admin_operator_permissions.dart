import 'package:flutter/material.dart';

/// Permiso fino de un operador de zona (por ejemplo «Aprobar conductores»).
/// El catálogo viene del servidor (`admin_permission_catalog_v1`) para que el
/// panel y las reglas del servidor siempre coincidan.
class OperatorPermission {
  const OperatorPermission({
    required this.key,
    required this.moduleKey,
    required this.group,
    required this.label,
    this.sensitive = false,
  });

  final String key;
  final String moduleKey;
  final String group;
  final String label;
  final bool sensitive;
}

List<OperatorPermission> parseOperatorPermissionCatalog(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (row) => OperatorPermission(
          key: row['key'].toString(),
          moduleKey: row['module_key'].toString(),
          group: row['group_label'].toString(),
          label: row['label'].toString(),
          sensitive: row['sensitive'] == true,
        ),
      )
      .toList();
}

/// Módulos del menú que se manejan con permisos finos.
Set<String> operatorPermissionModules(List<OperatorPermission> catalog) =>
    catalog.map((p) => p.moduleKey).toSet();

String _moduleOf(String key) => key.split('.').first;

/// Un permiso sin el «Ver» de su módulo no tiene sentido: marcarlo completa el
/// «Ver». Quitar el «Ver» quita todo el módulo. Operación en vivo y SOS piden
/// Dashboard y Conductores (igual que en el servidor).
Set<String> operatorPermissionsToggled(
  Iterable<String> current,
  String key,
  bool enabled,
) {
  final result = {...current};
  final module = _moduleOf(key);
  final viewKey = '$module.view';
  if (enabled) {
    result
      ..add(key)
      ..add(viewKey);
    if (key == 'live_operations.view' || key == 'safety_sos.view') {
      result.addAll(const ['dashboard.view', 'drivers.view']);
    }
  } else {
    result.remove(key);
    if (key == viewKey) {
      result.removeWhere((k) => _moduleOf(k) == module);
    }
    if (key == 'dashboard.view' || key == 'drivers.view') {
      result
        ..remove('live_operations.view')
        ..remove('safety_sos.view');
    }
  }
  return result;
}

/// Marca o desmarca todos los permisos de un módulo.
Set<String> operatorPermissionsSetModule(
  Iterable<String> current,
  List<OperatorPermission> catalog,
  String moduleKey,
  bool enabled,
) {
  var result = {...current};
  final keys = catalog.where((p) => p.moduleKey == moduleKey).map((p) => p.key);
  if (enabled) {
    for (final key in keys) {
      result = operatorPermissionsToggled(result, key, true);
    }
  } else {
    result.removeAll(keys);
    if (moduleKey == 'dashboard' || moduleKey == 'drivers') {
      result
        ..remove('live_operations.view')
        ..remove('safety_sos.view');
    }
  }
  return result;
}

/// «Ver» de cada módulo con permisos finos que ya tiene asignado (para cuentas
/// nuevas o antiguas que solo tenían la lista de módulos).
Set<String> operatorViewPermissionsFor(
  Iterable<String> modules,
  List<OperatorPermission> catalog,
) {
  final have = modules.toSet();
  return catalog
      .where((p) => p.key == '${p.moduleKey}.view' && have.contains(p.moduleKey))
      .map((p) => p.key)
      .toSet();
}

const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _blue = Color(0xFF2563EB);

/// Lista de permisos por grupo, con contador, «Seleccionar todos» y
/// «Quitar todos».
class OperatorPermissionPicker extends StatelessWidget {
  const OperatorPermissionPicker({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<OperatorPermission> catalog;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OperatorPermission>>{};
    for (final p in catalog) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    final total = catalog.length;
    final count = catalog.where((p) => selected.contains(p.key)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$count de $total permisos seleccionados',
                key: const ValueKey('operator-permission-count'),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('operator-permission-all'),
              onPressed: enabled
                  ? () => onChanged({
                        ...selected,
                        ...catalog.map((p) => p.key),
                      })
                  : null,
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Seleccionar todos'),
            ),
            TextButton.icon(
              key: const ValueKey('operator-permission-none'),
              onPressed: enabled
                  ? () => onChanged(
                        selected
                            .where((k) => !catalog.any((p) => p.key == k))
                            .toSet(),
                      )
                  : null,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Quitar todos'),
            ),
          ],
        ),
        for (final entry in groups.entries)
          _group(entry.key, entry.value),
      ],
    );
  }

  Widget _group(String title, List<OperatorPermission> items) {
    final moduleKey = items.first.moduleKey;
    final on = items.where((p) => selected.contains(p.key)).length;
    final all = on == items.length;
    final none = on == 0;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('operator-permission-group-$moduleKey'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.fromLTRB(28, 0, 8, 6),
          leading: Checkbox(
            tristate: true,
            value: all ? true : (none ? false : null),
            onChanged: enabled
                ? (_) => onChanged(
                      operatorPermissionsSetModule(
                        selected,
                        catalog,
                        moduleKey,
                        !all,
                      ),
                    )
                : null,
          ),
          title: Text(
            '$title ($on/${items.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _dark),
          ),
          children: [
            for (final p in items)
              CheckboxListTile(
                key: ValueKey('operator-permission-${p.key}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _blue,
                value: selected.contains(p.key) ||
                    (p.key == 'users.view' && moduleKey == 'users'),
                title: Text(p.label),
                subtitle: p.sensitive
                    ? const Text(
                        'Dato sensible',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB54708)),
                      )
                    : (p.key == 'users.view'
                        ? const Text(
                            'Siempre incluido',
                            style: TextStyle(fontSize: 11, color: _muted),
                          )
                        : null),
                onChanged: !enabled || p.key == 'users.view'
                    ? null
                    : (value) => onChanged(
                          operatorPermissionsToggled(
                            selected,
                            p.key,
                            value == true,
                          ),
                        ),
              ),
          ],
        ),
      ),
    );
  }
}
