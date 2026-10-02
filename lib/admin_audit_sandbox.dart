import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const Color _auditBlue = Color(0xFF2563EB);
const Color _auditDark = Color(0xFF0F172A);
const Color _auditMuted = Color(0xFF64748B);

List<Map<String, dynamic>> _auditMaps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

class AdminAuditSandboxPage extends StatefulWidget {
  const AdminAuditSandboxPage({super.key});

  @override
  State<AdminAuditSandboxPage> createState() => _AdminAuditSandboxPageState();
}

class _AdminAuditSandboxPageState extends State<AdminAuditSandboxPage> {
  int revision = 0;
  bool saving = false;

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc('admin_audit_sandbox_state');
    if (value is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(value);
  }

  void _refresh() => setState(() => revision++);

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : _auditDark,
      ),
    );
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();

    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo entorno de prueba'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Auditoría Cuba',
                ),
                onChanged: (value) {
                  if (slugController.text.isNotEmpty) return;
                  final slug = value
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                      .replaceAll(RegExp(r'^-+|-+$'), '');
                  slugController.text = slug;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slugController,
                decoration: const InputDecoration(
                  labelText: 'Identificador',
                  hintText: 'auditoria-cuba',
                  helperText: 'Solo letras minúsculas, números, guion y guion bajo.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear'),
          ),
        ],
      ),
    );

    if (create != true) {
      nameController.dispose();
      slugController.dispose();
      return;
    }

    try {
      setState(() => saving = true);
      await supabase.rpc(
        'admin_upsert_audit_group',
        params: {
          'p_group_id': null,
          'p_name': nameController.text.trim(),
          'p_slug': slugController.text.trim(),
          'p_active': true,
        },
      );
      _snack('Entorno de prueba creado.');
      _refresh();
    } catch (error) {
      _snack('No se pudo crear el entorno: $error', error: true);
    } finally {
      nameController.dispose();
      slugController.dispose();
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _toggleGroup(Map<String, dynamic> group, bool active) async {
    try {
      await supabase.rpc(
        'admin_set_audit_group_active',
        params: {
          'p_group_id': group['id'],
          'p_active': active,
        },
      );
      _snack(active
          ? 'Entorno activado. El aislamiento está operativo.'
          : 'Entorno desactivado. Sus miembros vuelven al alcance normal de producción.');
      _refresh();
    } catch (error) {
      _snack('No se pudo actualizar el entorno: $error', error: true);
    }
  }

  Future<void> _addMember(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> candidates,
    String role,
  ) async {
    final roleLabel = role == 'driver' ? 'conductor' : 'pasajero';
    final eligible = candidates.where((candidate) {
      final id = candidate['id']?.toString();
      if (id == null || id.isEmpty) return false;
      final currentGroup = candidate['group_id']?.toString();
      return currentGroup == null ||
          currentGroup.isEmpty ||
          currentGroup == group['id']?.toString();
    }).toList();

    if (eligible.isEmpty) {
      _snack('No hay usuarios disponibles para asignar.', error: true);
      return;
    }

    String? selectedId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Añadir $roleLabel'),
          content: SizedBox(
            width: 520,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedId,
              decoration: InputDecoration(
                labelText: 'Cuenta de $roleLabel',
                helperText:
                    'Esta cuenta quedará aislada junto con los demás miembros del grupo.',
              ),
              items: eligible.map((candidate) {
                final name =
                    candidate['full_name']?.toString().trim() ?? '';
                final email = candidate['email']?.toString() ?? '';
                final label = name.isEmpty ? email : '$name · $email';
                return DropdownMenuItem<String>(
                  value: candidate['id'].toString(),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => setLocal(() => selectedId = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedId == null) return;

    try {
      await supabase.rpc(
        'admin_set_audit_group_member',
        params: {
          'p_group_id': group['id'],
          'p_user_id': selectedId,
          'p_role': role,
          'p_enabled': true,
        },
      );
      _snack('Cuenta añadida al entorno de prueba.');
      _refresh();
    } catch (error) {
      _snack('No se pudo asignar la cuenta: $error', error: true);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final label = (member['full_name']?.toString().trim().isNotEmpty ?? false)
        ? member['full_name'].toString()
        : (member['email'] ?? 'esta cuenta').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar del entorno'),
        content: Text(
          '¿Quitar a $label? Al salir del sandbox volverá al alcance normal de producción.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.rpc(
        'admin_remove_audit_group_member',
        params: {'p_user_id': member['user_id']},
      );
      _snack('Cuenta retirada del entorno.');
      _refresh();
    } catch (error) {
      _snack('No se pudo retirar la cuenta: $error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 36,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No se pudo cargar Entornos de prueba',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _auditMuted),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final state = snapshot.data ?? const <String, dynamic>{};
        final groups = _auditMaps(state['groups']);
        final candidates = _auditMaps(state['candidates']);

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
          children: [
            _AuditHero(
              groupCount: groups.length,
              memberCount: groups.fold<int>(
                0,
                (total, group) =>
                    total + _auditMaps(group['members']).length,
              ),
              onCreate: saving ? null : _createGroup,
            ),
            const SizedBox(height: 16),
            const _IsolationNotice(),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              _EmptyAuditState(onCreate: saving ? null : _createGroup)
            else
              for (final group in groups) ...[
                _AuditGroupCard(
                  group: group,
                  candidates: candidates,
                  onToggle: (active) => _toggleGroup(group, active),
                  onAddPassenger: () =>
                      _addMember(group, candidates, 'passenger'),
                  onAddDriver: () =>
                      _addMember(group, candidates, 'driver'),
                  onRemoveMember: _removeMember,
                ),
                const SizedBox(height: 14),
              ],
          ],
        );
      },
    );
  }
}

class _AuditHero extends StatelessWidget {
  final int groupCount;
  final int memberCount;
  final VoidCallback? onCreate;

  const _AuditHero({
    required this.groupCount,
    required this.memberCount,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF174B91), Color(0xFF0D6B8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B174B91),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroStat(label: 'ENTORNOS', value: groupCount.toString()),
              const SizedBox(width: 10),
              _HeroStat(label: 'CUENTAS QA', value: memberCount.toString()),
            ],
          );

          final copy = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entornos de prueba',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Prueba la aplicación real sin enviar solicitudes, ofertas ni notificaciones a usuarios de producción.',
                style: TextStyle(
                  color: Color(0xFFD7E7FA),
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _AuditIcon(),
                    SizedBox(width: 13),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 16),
                summary,
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo entorno'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _auditBlue,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              const _AuditIcon(),
              const SizedBox(width: 13),
              const Expanded(child: copy),
              summary,
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo entorno'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _auditBlue,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuditIcon extends StatelessWidget {
  const _AuditIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: const Icon(Icons.science_rounded, color: Colors.white, size: 23),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC4D8F2),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _IsolationNotice extends StatelessWidget {
  const _IsolationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFABEFC6)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF067647)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Aislamiento activo en backend: viajes, ofertas, Realtime, push, conductores cercanos y delivery solo cruzan entre cuentas del mismo entorno. Las cuentas sin entorno continúan operando normalmente en producción.',
              style: TextStyle(
                color: Color(0xFF05603A),
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> candidates;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAddPassenger;
  final VoidCallback onAddDriver;
  final ValueChanged<Map<String, dynamic>> onRemoveMember;

  const _AuditGroupCard({
    required this.group,
    required this.candidates,
    required this.onToggle,
    required this.onAddPassenger,
    required this.onAddDriver,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final active = group['active'] == true;
    final members = _auditMaps(group['members']);
    final passengers =
        members.where((member) => member['role'] == 'passenger').toList();
    final drivers =
        members.where((member) => member['role'] == 'driver').toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: active
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFDDE6F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.science_rounded,
                      color: active ? _auditBlue : _auditMuted,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (group['name'] ?? 'Entorno QA').toString(),
                          style: const TextStyle(
                            color: _auditDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (group['slug'] ?? '').toString(),
                          style: const TextStyle(
                            color: _auditMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final toggle = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFECFDF3)
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active ? 'AISLADO / ACTIVO' : 'DESACTIVADO',
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF067647)
                            : _auditMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(value: active, onChanged: onToggle),
                ],
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    toggle,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  toggle,
                ],
              );
            },
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final passengerColumn = _RoleColumn(
                title: 'Pasajeros de prueba',
                icon: Icons.person_outline_rounded,
                roleTone: const Color(0xFF2563EB),
                members: passengers,
                emptyText: 'Sin pasajero asignado',
                addLabel: 'Añadir pasajero',
                onAdd: onAddPassenger,
                onRemoveMember: onRemoveMember,
              );
              final driverColumn = _RoleColumn(
                title: 'Conductores de prueba',
                icon: Icons.drive_eta_rounded,
                roleTone: const Color(0xFF0F9F68),
                members: drivers,
                emptyText: 'Sin conductor asignado',
                addLabel: 'Añadir conductor',
                onAdd: onAddDriver,
                onRemoveMember: onRemoveMember,
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    passengerColumn,
                    const SizedBox(height: 12),
                    driverColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: passengerColumn),
                  const SizedBox(width: 12),
                  Expanded(child: driverColumn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color roleTone;
  final List<Map<String, dynamic>> members;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onRemoveMember;

  const _RoleColumn({
    required this.title,
    required this.icon,
    required this.roleTone,
    required this.members,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: roleTone, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _auditDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  members.length.toString(),
                  style: const TextStyle(
                    color: _auditMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                emptyText,
                style: const TextStyle(
                  color: _auditMuted,
                  fontSize: 10,
                ),
              ),
            )
          else
            for (final member in members)
              _MemberTile(
                member: member,
                tone: roleTone,
                onRemove: () => onRemoveMember(member),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final Color tone;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.tone,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = member['full_name']?.toString().trim() ?? '';
    final email = member['email']?.toString() ?? '';
    final enabled = member['enabled'] != false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: tone.withOpacity(.12),
            child: Icon(Icons.person_rounded, color: tone, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? email : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _auditDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _auditMuted,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF12B76A)
                  : const Color(0xFF98A2B3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Quitar del entorno',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _EmptyAuditState extends StatelessWidget {
  final VoidCallback? onCreate;

  const _EmptyAuditState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFDDE6F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.science_outlined, size: 42, color: _auditMuted),
          const SizedBox(height: 10),
          const Text(
            'No hay entornos de prueba',
            style: TextStyle(
              color: _auditDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Crea uno y asigna al menos un pasajero y un conductor.',
            style: TextStyle(color: _auditMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear entorno'),
          ),
        ],
      ),
    );
  }
}
