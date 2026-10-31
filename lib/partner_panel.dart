import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_dropdown_field.dart';

import 'core/supabase_client.dart';

const Color _partnerBlue = Color(0xFF2563EB);
const Color _partnerDark = Color(0xFF0F172A);
const Color _partnerMuted = Color(0xFF64748B);
const Color _partnerSoft = Color(0xFFF8FAFC);

List<Map<String, dynamic>> _partnerList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

double _partnerDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

String _partnerDate(Object? raw) {
  final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (dt == null) return '—';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/${dt.year} · $h:$min';
}

class PartnerExpressPanel extends StatefulWidget {
  final VoidCallback onExit;
  final String? initialPartnerId;

  const PartnerExpressPanel({super.key, required this.onExit, this.initialPartnerId});

  @override
  State<PartnerExpressPanel> createState() => _PartnerExpressPanelState();
}

class _PartnerExpressPanelState extends State<PartnerExpressPanel> {
  int section = 0;
  int revision = 0;
  String? selectedPartnerId;

  @override
  void initState() {
    super.initState();
    selectedPartnerId = widget.initialPartnerId;
  }

  Future<List<Map<String, dynamic>>> _dashboard() async {
    final value = await supabase.rpc('partner_my_dashboard');
    return _partnerList(value);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(revision),
      future: _dashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 46,
                          color: Color(0xFFD92D20),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No se pudo abrir el panel de la organización',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friendlyError(snapshot.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() => revision++),
                          child: const Text('Reintentar'),
                        ),
                        TextButton(
                          onPressed: widget.onExit,
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final partners = snapshot.data ?? const <Map<String, dynamic>>[];
        if (partners.isEmpty) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Sin organización asignada',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pide al administrador de Express que asigne tu cuenta a una empresa, sindicato o cooperativa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _partnerMuted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: widget.onExit,
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        var partnerId = selectedPartnerId;
        if (partnerId == null ||
            !partners.any((row) => row['partner_id']?.toString() == partnerId)) {
          partnerId = partners.first['partner_id']?.toString();
          selectedPartnerId = partnerId;
        }

        final partner = partners.firstWhere(
          (row) => row['partner_id']?.toString() == partnerId,
        );

        return _PartnerShell(
          partner: partner,
          partners: partners,
          section: section,
          onSection: (value) => setState(() => section = value),
          onPartner: (value) {
            setState(() {
              selectedPartnerId = value;
              section = 0;
            });
          },
          onRefresh: () => setState(() => revision++),
          onExit: widget.onExit,
        );
      },
    );
  }
}

class _PartnerShell extends StatelessWidget {
  final Map<String, dynamic> partner;
  final List<Map<String, dynamic>> partners;
  final int section;
  final ValueChanged<int> onSection;
  final ValueChanged<String> onPartner;
  final VoidCallback onRefresh;
  final VoidCallback onExit;

  const _PartnerShell({
    required this.partner,
    required this.partners,
    required this.section,
    required this.onSection,
    required this.onPartner,
    required this.onRefresh,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final pages = [
      _PartnerOverview(partner: partner, onRefresh: onRefresh),
      _PartnerDrivers(partner: partner),
      _PartnerJoinRequests(partner: partner),
      _PartnerPayments(partner: partner),
      _PartnerAnnouncements(partner: partner),
      _PartnerIdentity(partner: partner, onSaved: onRefresh),
    ];

    final body = IndexedStack(index: section, children: pages);
    if (compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(partner['name']?.toString() ?? 'Express Aliados'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onExit,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: section,
          onDestinationSelected: onSection,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Resumen',
            ),
            NavigationDestination(
              icon: Icon(Icons.two_wheeler_outlined),
              selectedIcon: Icon(Icons.two_wheeler_rounded),
              label: 'Conductores',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_add_alt_outlined),
              selectedIcon: Icon(Icons.person_add_alt_rounded),
              label: 'Solicitudes',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Pagos',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Avisos',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded),
              label: 'Identidad',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 270,
            color: const Color(0xFF0B2C5B),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.bolt_rounded, color: _partnerBlue),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'EXPRESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: AdminDropdownField<String>(
                      initialValue: partner['partner_id']?.toString(),
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Organización',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: partners
                          .map(
                            (row) => DropdownMenuItem(
                              value: row['partner_id']?.toString(),
                              child: Text(row['name']?.toString() ?? 'Organización'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onPartner(value);
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  _PartnerNav(
                    icon: Icons.dashboard_rounded,
                    label: 'Resumen',
                    selected: section == 0,
                    onTap: () => onSection(0),
                  ),
                  _PartnerNav(
                    icon: Icons.two_wheeler_rounded,
                    label: 'Conductores',
                    selected: section == 1,
                    onTap: () => onSection(1),
                  ),
                  _PartnerNav(
                    icon: Icons.person_add_alt_rounded,
                    label: 'Solicitudes',
                    selected: section == 2,
                    onTap: () => onSection(2),
                  ),
                  _PartnerNav(
                    icon: Icons.payments_rounded,
                    label: 'Pagos y comisiones',
                    selected: section == 3,
                    onTap: () => onSection(3),
                  ),
                  _PartnerNav(
                    icon: Icons.notifications_active_rounded,
                    label: 'Avisos push',
                    selected: section == 4,
                    onTap: () => onSection(4),
                  ),
                  _PartnerNav(
                    icon: Icons.badge_rounded,
                    label: 'Identidad',
                    selected: section == 5,
                    onTap: () => onSection(5),
                  ),
                  const Spacer(),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    title: const Text(
                      'Actualizar',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: onRefresh,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: onExit,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _PartnerNav extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PartnerNav({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: selected ? Colors.white : Colors.white70),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PartnerPageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _PartnerPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _partnerDark,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _partnerMuted),
                  ),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _PartnerOverview extends StatelessWidget {
  final Map<String, dynamic> partner;
  final VoidCallback onRefresh;

  const _PartnerOverview({
    required this.partner,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final generated = _partnerDouble(partner['commission_generated']);
    final paid = _partnerDouble(partner['commission_paid']);
    return _PartnerPageFrame(
      title: partner['name']?.toString() ?? 'Mi organización',
      subtitle:
          'Panel restringido de empresa, sindicato o cooperativa asociada a Express.',
      action: IconButton(
        tooltip: 'Actualizar',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              final width = constraints.maxWidth < 680
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PartnerMetric(
                    width: width,
                    icon: Icons.two_wheeler_rounded,
                    label: 'Conductores activos',
                    value: (partner['drivers_active'] ?? 0).toString(),
                  ),
                  _PartnerMetric(
                    width: width,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Comisión generada',
                    value: generated.toStringAsFixed(2),
                  ),
                  _PartnerMetric(
                    width: width,
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Comisión pagada',
                    value: paid.toStringAsFixed(2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: _partnerSoft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PartnerInfoRow(
                    'Rol de acceso',
                    partner['role']?.toString() ?? '—',
                  ),
                  _PartnerInfoRow(
                    'Comisión',
                    (partner['commission_percent'] ?? 0).toString() + '%',
                  ),
                  _PartnerInfoRow(
                    'Zona ID',
                    partner['zone_id']?.toString() ?? '—',
                  ),
                  const _PartnerInfoRow(
                    'Permisos',
                    'Solo información y acciones de esta organización',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerMetric extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _PartnerMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(icon, color: _partnerBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: _partnerMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _PartnerInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: _partnerMuted),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _PartnerDrivers extends StatefulWidget {
  final Map<String, dynamic> partner;
  const _PartnerDrivers({required this.partner});

  @override
  State<_PartnerDrivers> createState() => _PartnerDriversState();
}

class _PartnerDriversState extends State<_PartnerDrivers> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'partner_driver_list',
      params: {'p_partner_id': widget.partner['partner_id']},
    );
    return _partnerList(value);
  }

  Future<void> _status(Map<String, dynamic> driver, String status) async {
    try {
      await supabase.rpc(
        'partner_set_membership_status',
        params: {
          'p_partner_id': widget.partner['partner_id'],
          'p_driver_id': driver['driver_id'],
          'p_status': status,
        },
      );
      if (mounted) setState(() => revision++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _addExistingDriver() async {
    final query = TextEditingController();
    var results = <Map<String, dynamic>>[];
    var searched = false;
    var loading = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Agregar conductor existente'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: query,
                  decoration: InputDecoration(
                    labelText: 'Nombre, teléfono o correo',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: loading
                          ? null
                          : () async {
                              if (query.text.trim().length < 2) return;
                              setDialog(() => loading = true);
                              try {
                                final value = await supabase.rpc(
                                  'partner_search_drivers',
                                  params: {
                                    'p_partner_id': widget.partner['partner_id'],
                                    'p_query': query.text.trim(),
                                  },
                                );
                                results = _partnerList(value);
                                searched = true;
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(friendlyError(e))),
                                  );
                                }
                              } finally {
                                setDialog(() => loading = false);
                              }
                            },
                    ),
                  ),
                  onSubmitted: (_) async {
                    if (query.text.trim().length < 2 || loading) return;
                    setDialog(() => loading = true);
                    try {
                      final value = await supabase.rpc(
                        'partner_search_drivers',
                        params: {
                          'p_partner_id': widget.partner['partner_id'],
                          'p_query': query.text.trim(),
                        },
                      );
                      results = _partnerList(value);
                      searched = true;
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyError(e))),
                        );
                      }
                    } finally {
                      setDialog(() => loading = false);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (loading) const LinearProgressIndicator(),
                if (searched && results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No se encontraron conductores elegibles en esta zona.'),
                  ),
                if (results.isNotEmpty)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, index) {
                        final row = results[index];
                        return ListTile(
                          leading: const Icon(Icons.two_wheeler_rounded),
                          title: Text(row['full_name']?.toString() ?? 'Conductor'),
                          subtitle: Text(row['phone']?.toString() ?? ''),
                          onTap: () async {
                            final number = await _askMemberNumber(row['full_name']?.toString());
                            if (number == null || !dialogContext.mounted) return;
                            try {
                              await supabase.rpc('partner_add_driver', params: {
                                'p_partner_id': widget.partner['partner_id'],
                                'p_driver_id': row['driver_id'],
                                'p_member_number': number,
                              });
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              if (mounted) setState(() => revision++);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendlyError(e))),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
          ],
        ),
      ),
    );
    query.dispose();
  }

  Future<int?> _askMemberNumber(String? driverName) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Asignar número de socio${driverName == null ? '' : ' a $driverName'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Número de socio', helperText: 'Del 1 al 100'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1 && value <= 100) Navigator.pop(dialogContext, value);
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    final canModerate = role == 'owner' || role == 'manager' || role == 'admin';
    return _PartnerPageFrame(
      title: 'Conductores',
      subtitle: 'Solo conductores vinculados a tu organización.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canModerate)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addExistingDriver,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Agregar conductor'),
              ),
            ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _load(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text(friendlyError(snapshot.error));
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('No hay conductores afiliados todavía.'),
              ),
            );
          }
          return Column(
            children: rows.map((row) {
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF2FF),
                    child: Icon(Icons.two_wheeler_rounded, color: _partnerBlue),
                  ),
                  title: Text(
                    '${row['full_name']?.toString() ?? 'Conductor'} · SOCIOS ${row['member_number'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    (row['phone'] ?? 'Sin teléfono').toString() +
                        ' · ★ ' +
                        (row['rating'] ?? '—').toString() +
                        ' · ' +
                        (row['completed_trips'] ?? 0).toString() +
                        ' viajes\n' +
                        (row['status'] ?? row['approval_status'] ?? '—').toString() +
                        ' · ' +
                        (row['online_status'] ?? 'offline').toString(),
                  ),
                  isThreeLine: true,
                  trailing: canModerate
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _status(row, value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'active',
                              child: Text('Activar en sindicato'),
                            ),
                            PopupMenuItem(
                              value: 'suspended',
                              child: Text('Desactivar en sindicato'),
                            ),
                            PopupMenuItem(
                              value: 'removed',
                              child: Text('Quitar del sindicato'),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }).toList(),
          );
        },
          ),
        ],
      ),
    );
  }
}

class _PartnerJoinRequests extends StatefulWidget {
  final Map<String, dynamic> partner;
  const _PartnerJoinRequests({required this.partner});

  @override
  State<_PartnerJoinRequests> createState() => _PartnerJoinRequestsState();
}

class _PartnerJoinRequestsState extends State<_PartnerJoinRequests> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'partner_join_request_list',
      params: {'p_partner_id': widget.partner['partner_id']},
    );
    return _partnerList(value);
  }

  Future<void> _review(Map<String, dynamic> row, bool approve) async {
    int? memberNumber;
    if (approve) {
      final controller = TextEditingController();
      memberNumber = await showDialog<int>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar conductor al sindicato'),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de socio', helperText: 'Del 1 al 100')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () { final value = int.tryParse(controller.text); if (value != null && value >= 1 && value <= 100) Navigator.pop(dialogContext, value); }, child: const Text('Asignar'))],
      ));
      controller.dispose();
      if (memberNumber == null) return;
    }
    try {
      await supabase.rpc('partner_approve_join_request', params: {
        'p_request_id': row['id'],
        'p_approve': approve,
        'p_notes': approve ? 'Aprobado desde panel del sindicato' : 'Rechazado desde panel del sindicato',
        'p_member_number': memberNumber,
      });
      if (mounted) setState(() => revision++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    final canReview =
        role == 'owner' || role == 'manager' || role == 'operator' || role == 'admin';

    if (!canReview) {
      return const _PartnerPageFrame(
        title: 'Solicitudes',
        subtitle: 'Afiliaciones pendientes.',
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text('Tu rol no permite revisar afiliaciones.'),
          ),
        ),
      );
    }

    return _PartnerPageFrame(
      title: 'Solicitudes de afiliación',
      subtitle: 'Aprueba o rechaza conductores que quieren pertenecer a tu organización.',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _load(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) return Text(friendlyError(snapshot.error));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('No hay solicitudes pendientes.'),
              ),
            );
          }
          return Column(
            children: rows.map((row) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_rounded, color: _partnerBlue),
                title: Text(
                  row['driver_name']?.toString() ?? 'Conductor',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Solicitado ' + _partnerDate(row['requested_at']) +
                      (row['notes']?.toString().isNotEmpty == true
                          ? '\n' + row['notes'].toString()
                          : ''),
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      tooltip: 'Rechazar',
                      onPressed: () => _review(row, false),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFD92D20)),
                    ),
                    IconButton(
                      tooltip: 'Aprobar',
                      onPressed: () => _review(row, true),
                      icon: const Icon(Icons.check_rounded, color: Color(0xFF14804A)),
                    ),
                  ],
                ),
              ),
            )).toList(),
          );
        },
      ),
    );
  }
}

class _PartnerPayments extends StatefulWidget {
  final Map<String, dynamic> partner;
  const _PartnerPayments({required this.partner});

  @override
  State<_PartnerPayments> createState() => _PartnerPaymentsState();
}

class _PartnerPaymentsState extends State<_PartnerPayments> {
  int period = 1;
  int revision = 0;

  DateTimeRange _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late DateTime start;
    switch (period) {
      case 0: start = today; break;
      case 1: start = today.subtract(Duration(days: today.weekday - 1)); break;
      case 2: start = today.subtract(const Duration(days: 14)); break;
      default: start = DateTime(now.year, now.month, 1);
    }
    return DateTimeRange(start: start.toUtc(), end: today.add(const Duration(days: 1)).toUtc());
  }

  Future<Map<String, dynamic>> _load() async {
    final range = _range();
    final value = await supabase.rpc('partner_completed_plan_summary', params: {
      'p_partner_id': widget.partner['partner_id'],
      'p_from': range.start.toIso8601String(),
      'p_to': range.end.toIso8601String(),
    });
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    if (role != 'owner' && role != 'manager' && role != 'treasurer' && role != 'admin') {
      return const _PartnerPageFrame(title: 'Pagos de planes', subtitle: 'Pagos completados y comisión estimada.', child: Card(child: Padding(padding: EdgeInsets.all(22), child: Text('Tu rol no permite ver información financiera.'))));
    }
    const labels = ['Hoy', 'Semana', '15 días', 'Mes'];
    return _PartnerPageFrame(
      title: 'Pagos de planes',
      subtitle: 'Solo se incluyen pagos completados. La comisión se calcula según el porcentaje del sindicato.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: List.generate(labels.length, (i) => ChoiceChip(label: Text(labels[i]), selected: period == i, onSelected: (_) => setState(() { period = i; revision++; })))),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(key: ValueKey(revision), future: _load(), builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.hasError) return Text(friendlyError(snapshot.error));
          final data = snapshot.data ?? const <String, dynamic>{};
          final rows = _partnerList(data['payments']);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 10, children: [
              _PartnerMetric(width: 210, icon: Icons.check_circle_outline_rounded, label: 'Pagos completados', value: (data['completed_count'] ?? 0).toString()),
              _PartnerMetric(width: 210, icon: Icons.payments_rounded, label: 'Ingreso de planes', value: _partnerDouble(data['plans_total']).toStringAsFixed(2)),
              _PartnerMetric(width: 210, icon: Icons.account_balance_wallet_rounded, label: 'Comisión estimada', value: _partnerDouble(data['commission_estimated']).toStringAsFixed(2)),
            ]),
            const SizedBox(height: 12),
            if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('No hay pagos completados en este periodo.')))
            else ...rows.map((row) => Card(elevation: 0, child: ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: _partnerBlue),
              title: Text(row['driver_name']?.toString() ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Pago completado · ${_partnerDate(row['paid_at'])}'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${row['currency'] ?? ''} ${_partnerDouble(row['amount']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('Comisión ${_partnerDouble(row['commission']).toStringAsFixed(2)}', style: const TextStyle(color: _partnerMuted, fontSize: 10)),
              ]),
            ))),
          ]);
        }),
      ]),
    );
  }
}

class _PartnerIdentity extends StatefulWidget {
  final Map<String, dynamic> partner;
  final VoidCallback onSaved;
  const _PartnerIdentity({required this.partner, required this.onSaved});

  @override
  State<_PartnerIdentity> createState() => _PartnerIdentityState();
}

class _PartnerIdentityState extends State<_PartnerIdentity> {
  late final TextEditingController name;
  late final TextEditingController color;
  String? logoUrl;
  XFile? pickedLogo;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.partner['name']?.toString() ?? '');
    color = TextEditingController(text: widget.partner['brand_color']?.toString() ?? '#ED6B1F');
    logoUrl = widget.partner['logo_url']?.toString();
  }

  @override
  void dispose() { name.dispose(); color.dispose(); super.dispose(); }

  Future<void> _pickLogo() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null && mounted) setState(() => pickedLogo = image);
  }

  Future<void> _save() async {
    if (saving) return;
    final colorValue = color.text.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorValue) || name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el nombre y el color hexadecimal.')));
      return;
    }
    setState(() => saving = true);
    try {
      if (pickedLogo != null) {
        final bytes = await pickedLogo!.readAsBytes();
        final path = '${widget.partner['partner_id']}/logo-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('partner-logos').uploadBinary(path, bytes);
        logoUrl = supabase.storage.from('partner-logos').getPublicUrl(path);
      }
      await supabase.rpc('partner_save_branding', params: {
        'p_partner_id': widget.partner['partner_id'],
        'p_name': name.text.trim(),
        'p_logo_url': logoUrl,
        'p_brand_color': colorValue.toUpperCase(),
      });
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identidad del sindicato guardada.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    if (role != 'owner' && role != 'manager' && role != 'admin') return const _PartnerPageFrame(title: 'Identidad', subtitle: 'Nombre, logo y color del sindicato.', child: Card(child: Padding(padding: EdgeInsets.all(22), child: Text('Tu rol no puede editar la identidad del sindicato.'))));
    return _PartnerPageFrame(title: 'Identidad del sindicato', subtitle: 'Esta identidad aparece junto al conductor en la app del pasajero.', child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre del sindicato')),
      const SizedBox(height: 12), TextField(controller: color, decoration: const InputDecoration(labelText: 'Color de fondo para SOCIOS', hintText: '#ED6B1F')),
      const SizedBox(height: 12), Row(children: [CircleAvatar(radius: 26, backgroundColor: Colors.white, backgroundImage: logoUrl == null || logoUrl!.isEmpty ? null : NetworkImage(logoUrl!), child: logoUrl == null || logoUrl!.isEmpty ? const Icon(Icons.groups_2_rounded, color: _partnerBlue) : null), const SizedBox(width: 12), OutlinedButton.icon(onPressed: saving ? null : _pickLogo, icon: const Icon(Icons.upload_rounded), label: Text(pickedLogo == null ? 'Elegir logo' : pickedLogo!.name))]),
      const SizedBox(height: 18), FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width: 16,height: 16,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: const Text('Guardar identidad')),
    ]))));
  }
}

class _PartnerAnnouncements extends StatefulWidget {
  final Map<String, dynamic> partner;
  const _PartnerAnnouncements({required this.partner});

  @override
  State<_PartnerAnnouncements> createState() => _PartnerAnnouncementsState();
}

class _PartnerAnnouncementsState extends State<_PartnerAnnouncements> {
  final title = TextEditingController();
  final body = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = title.text.trim();
    final b = body.text.trim();
    if (t.isEmpty || b.isEmpty || sending) return;

    setState(() => sending = true);
    try {
      final value = await supabase.rpc(
        'partner_send_announcement',
        params: {
          'p_partner_id': widget.partner['partner_id'],
          'p_title': t,
          'p_body': b,
        },
      );
      final result = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
      if (!mounted) return;
      title.clear();
      body.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aviso enviado a ' +
                (result['recipients'] ?? 0).toString() +
                ' conductores.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    final canSend =
        role == 'owner' || role == 'manager' || role == 'operator' || role == 'admin';

    return _PartnerPageFrame(
      title: 'Avisos y promociones',
      subtitle:
          'Envía notificaciones push únicamente a los conductores afiliados a tu organización.',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: canSend
              ? Column(
                  children: [
                    TextField(
                      controller: title,
                      maxLength: 90,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej. Alta demanda en el centro',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: body,
                      maxLength: 1000,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        hintText:
                            'Conéctate ahora. Hay alta demanda en tu zona.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: _partnerBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'El aviso se guarda en la bandeja de Express y también se despacha como push.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: sending ? null : _send,
                        icon: sending
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Enviar aviso'),
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Tu rol no permite enviar avisos.',
                  style: TextStyle(color: _partnerMuted),
                ),
        ),
      ),
    );
  }
}
