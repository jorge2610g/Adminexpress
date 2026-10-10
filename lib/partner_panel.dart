import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';
import 'core/admin_design_tokens.dart';
import 'core/admin_widgets.dart';

const Color _partnerBlue = AdminColors.blue;
const Color _partnerDark = AdminColors.ink;
const Color _partnerMuted = AdminColors.muted;
const Color _partnerSoft = AdminColors.surfaceSoft;

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

  const PartnerExpressPanel({super.key, required this.onExit});

  @override
  State<PartnerExpressPanel> createState() => _PartnerExpressPanelState();
}

class _PartnerExpressPanelState extends State<PartnerExpressPanel> {
  int section = 0;
  int revision = 0;
  String? selectedPartnerId;

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
                          snapshot.error.toString(),
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
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: Row(
        children: [
          Container(
            width: 248,
            color: AdminColors.sidebar,
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
                    child: DropdownButtonFormField<String>(
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
          Expanded(child: ColoredBox(
            color: AdminColors.bg,
            child: body,
          )),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AdminColors.sidebarActive : Colors.transparent,
              border: Border.all(
                color: selected
                    ? AdminColors.sidebarActiveBorder
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1E4E83)
                        : AdminColors.sidebarTile,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: selected ? AdminColors.cyan : AdminColors.sidebarMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC5D0DF),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AdminColors.cyan,
                    size: 17,
                  ),
              ],
            ),
          ),
        ),
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
        AdminPageHero(
          title: title,
          subtitle: subtitle,
          icon: Icons.handshake_rounded,
          trailing: action,
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
      action: FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 17),
        label: const Text('Actualizar'),
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.surface,
          foregroundColor: AdminColors.headerMid,
        ),
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
      child: AdminCard(
        padding: const EdgeInsets.all(17),
        child: Padding(
          padding: EdgeInsets.zero,
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
        'partner_set_driver_approval',
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

  @override
  Widget build(BuildContext context) {
    final role = widget.partner['role']?.toString();
    final canModerate = role == 'owner' || role == 'manager';
    return _PartnerPageFrame(
      title: 'Conductores',
      subtitle: 'Solo conductores vinculados a tu organización.',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _load(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
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
                    row['full_name']?.toString() ?? 'Conductor',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    (row['phone'] ?? 'Sin teléfono').toString() +
                        ' · ★ ' +
                        (row['rating'] ?? '—').toString() +
                        ' · ' +
                        (row['completed_trips'] ?? 0).toString() +
                        ' viajes\n' +
                        (row['approval_status'] ?? '—').toString() +
                        ' · ' +
                        (row['online_status'] ?? 'offline').toString(),
                  ),
                  isThreeLine: true,
                  trailing: canModerate
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _status(row, value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'approved',
                              child: Text('Aprobar'),
                            ),
                            PopupMenuItem(
                              value: 'pending',
                              child: Text('Marcar pendiente'),
                            ),
                            PopupMenuItem(
                              value: 'suspended',
                              child: Text('Suspender'),
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
    try {
      await supabase.rpc(
        'partner_review_join_request',
        params: {
          'p_request_id': row['id'],
          'p_approve': approve,
          'p_notes': approve ? 'Aprobado desde panel aliado' : 'Rechazado desde panel aliado',
        },
      );
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
        role == 'owner' || role == 'manager' || role == 'operator';

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
          if (snapshot.hasError) return Text(snapshot.error.toString());
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

class _PartnerPayments extends StatelessWidget {
  final Map<String, dynamic> partner;
  const _PartnerPayments({required this.partner});

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'partner_payment_list',
      params: {
        'p_partner_id': partner['partner_id'],
        'p_limit': 200,
      },
    );
    return _partnerList(value);
  }

  @override
  Widget build(BuildContext context) {
    final role = partner['role']?.toString();
    final canView =
        role == 'owner' || role == 'manager' || role == 'treasurer';

    if (!canView) {
      return const _PartnerPageFrame(
        title: 'Pagos y comisiones',
        subtitle: 'Movimientos de suscripción vinculados a la organización.',
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text('Tu rol no permite ver información financiera.'),
          ),
        ),
      );
    }

    return _PartnerPageFrame(
      title: 'Pagos y comisiones',
      subtitle: 'Suscripciones de conductores afiliados y comisión de la organización.',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) return Text(snapshot.error.toString());
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('Todavía no hay pagos asociados.'),
              ),
            );
          }
          return Column(
            children: rows.map((row) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: _partnerBlue),
                title: Text(
                  row['driver_name']?.toString() ?? 'Conductor',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  (row['status'] ?? '—').toString() +
                      ' · ' +
                      _partnerDate(row['paid_at'] ?? row['created_at']),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (row['currency_code'] ?? '').toString() +
                          ' ' +
                          _partnerDouble(row['amount']).toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Comisión ' +
                          _partnerDouble(row['partner_commission_amount'])
                              .toStringAsFixed(2),
                      style: const TextStyle(
                        color: _partnerMuted,
                        fontSize: 10,
                      ),
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
        role == 'owner' || role == 'manager' || role == 'operator';

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
