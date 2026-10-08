import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _bg = Color(0xFFF1F5F9);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);
const _green = Color(0xFF14804A);
const _amber = Color(0xFFB54708);
const _red = Color(0xFFB42318);
const _violet = Color(0xFF6941C6);

class AdminDiditPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminDiditPage({
    super.key,
    required this.channel,
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminDiditPage> createState() => _AdminDiditPageState();
}

class _AdminDiditPageState extends State<AdminDiditPage> {
  final searchController = TextEditingController();
  int revision = 0;
  String statusFilter = 'all';
  String countryFilter = 'all';

  bool get isPreview => widget.channel == 'preview';
  String get providerEnvironment => isPreview ? 'sandbox' : 'production';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await supabase.rpc(
      'admin_identity_verification_list_scoped',
      params: {
        'p_limit': 250,
        'p_country_code': widget.countryCode,
        'p_zone_id': widget.zoneId,
        'p_provider': 'didit',
        'p_provider_environment': providerEnvironment,
      },
    );

    final sessions = _list(raw);
    final names = <String, String>{};
    for (final row in sessions) {
      final id = row['user_id']?.toString();
      final name = row['full_name']?.toString().trim();
      if (id != null &&
          id.isNotEmpty &&
          name != null &&
          name.isNotEmpty) {
        names[id] = name;
      }
    }

    return {
      'sessions': sessions,
      'names': names,
    };
  }

  List<Map<String, dynamic>> _filtered(
    List<Map<String, dynamic>> sessions,
    Map<String, String> names,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return sessions.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      final country = (row['country_code'] ?? '').toString().toUpperCase();

      if (statusFilter != 'all' && status != statusFilter) return false;
      if (countryFilter != 'all' && country != countryFilter) return false;

      if (query.isEmpty) return true;

      final userId = (row['user_id'] ?? '').toString();
      final haystack = [
        userId,
        names[userId] ?? '',
        row['provider_session_id'] ?? '',
        row['workflow_id'] ?? '',
        row['provider_status'] ?? '',
        row['document_type'] ?? '',
        country,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _score(dynamic value) {
    if (value == null) return '—';
    final n = num.tryParse(value.toString());
    if (n == null) return value.toString();
    final display = n <= 1 ? n * 100 : n;
    return '${display.toStringAsFixed(display % 1 == 0 ? 0 : 1)}%';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return _green;
      case 'rejected':
        return _red;
      case 'review':
        return _violet;
      case 'processing':
      case 'pending':
        return _amber;
      default:
        return _muted;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'VERIFICADO';
      case 'rejected':
        return 'RECHAZADO';
      case 'review':
        return 'EN REVISIÓN';
      case 'processing':
        return 'PROCESANDO';
      case 'pending':
        return 'PENDIENTE';
      default:
        return status.isEmpty ? 'SIN ESTADO' : status.toUpperCase();
    }
  }

  Widget _badge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .35,
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .10),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, dynamic value, {bool mono = false}) {
    final text = value == null || value.toString().trim().isEmpty
        ? '—'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                color: _ink,
                fontSize: mono ? 10 : 11,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleState(String label, dynamic value) {
    final text = (value ?? '—').toString();
    final lower = text.toLowerCase();
    final color = lower.contains('approved') ||
            lower.contains('verified') ||
            lower == 'passed'
        ? _green
        : lower.contains('declined') ||
                lower.contains('failed') ||
                lower.contains('reject')
            ? _red
            : _muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        '$label · $text',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showDetails(
    Map<String, dynamic> row,
    String? driverName,
  ) {
    final result = _map(row['result']);
    final modules = _map(result['modules']);
    final warnings = _list(result['warnings']);
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2FF),
                        child: Icon(Icons.verified_user_rounded, color: _blue),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName?.isNotEmpty == true
                                  ? driverName!
                                  : 'Verificación Didit',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Detalle de la verificación de identidad',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _badge((row['status'] ?? '').toString()),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final sent = _detailPanel(
                          title: 'Enviado a Didit',
                          icon: Icons.upload_rounded,
                          children: [
                            _field(
                              'Entorno',
                              isPreview ? 'Prueba' : 'Producción',
                            ),
                            _field(
                              'Conductor',
                              driverName?.isNotEmpty == true
                                  ? driverName
                                  : 'Conductor de Express',
                            ),
                            _field('País', row['country_code']),
                            _field('Tipo de documento', row['document_type']),
                            _field(
                              'URL de verificación',
                              (row['verification_url'] ?? '').toString().isEmpty
                                  ? 'No disponible'
                                  : 'Generada por Didit',
                            ),
                            _field('Creado', _fmtDate(row['created_at'])),
                          ],
                        );

                        final received = _detailPanel(
                          title: 'Recibido de Didit',
                          icon: Icons.download_rounded,
                          children: [
                            _field(
                              'Resultado de Didit',
                              _statusLabel(
                                (row['provider_status'] ?? '').toString(),
                              ),
                            ),
                            _field(
                              'Estado en Express',
                              _statusLabel((row['status'] ?? '').toString()),
                            ),
                            _field('Documento detectado', result['document_type']),
                            _field('País emisor', result['issuing_state']),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _moduleState('Documento', modules['id_verification']),
                                _moduleState('Coincidencia facial', modules['face_match']),
                                _moduleState('Prueba de vida', modules['liveness']),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _field('Confianza del documento', _score(row['document_score'])),
                            _field('Coincidencia facial', _score(row['face_match_score'])),
                            _field('Prueba de vida', _score(row['liveness_score'])),
                            _field('Actualizado', _fmtDate(row['updated_at'])),
                            _field('Completado', _fmtDate(row['completed_at'])),
                          ],
                        );

                        final columns = wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: sent),
                                  const SizedBox(width: 14),
                                  Expanded(child: received),
                                ],
                              )
                            : Column(
                                children: [
                                  sent,
                                  const SizedBox(height: 14),
                                  received,
                                ],
                              );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            columns,
                            if (warnings.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _detailPanel(
                                title: 'Advertencias Didit',
                                icon: Icons.warning_amber_rounded,
                                children: [
                                  for (final warning in warnings)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        [
                                          warning['risk'],
                                          warning['log_type'],
                                          warning['short_description'],
                                        ]
                                            .where((value) =>
                                                value != null &&
                                                value.toString().trim().isNotEmpty)
                                            .join(' · '),
                                        style: const TextStyle(
                                          color: _ink,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            const Text(
                              'Por seguridad este panel nunca muestra API Keys, '
                              'Signing Secrets, tokens temporales ni imágenes biométricas.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailPanel({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: _blue),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _sessionCard(
    Map<String, dynamic> row,
    String? driverName,
  ) {
    final result = _map(row['result']);
    final modules = _map(result['modules']);
    final userId = (row['user_id'] ?? '').toString();
    final status = (row['status'] ?? '').toString();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(row, driverName),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEAF2FF),
                        child: Text(
                          (row['country_code'] ?? '—').toString(),
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName?.isNotEmpty == true
                                  ? driverName!
                                  : 'Conductor ${userId.isEmpty ? '—' : userId.substring(0, userId.length < 8 ? userId.length : 8)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Didit · ${row['provider_status'] ?? 'Sin estado proveedor'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _badge(status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _moduleState('Documento', modules['id_verification']),
                      _moduleState('Rostro', modules['face_match']),
                      _moduleState('Vida', modules['liveness']),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Actualizado: ${_fmtDate(row['updated_at'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              );

              final scores = SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Documento', _score(row['document_score'])),
                    _field('Coincidencia facial', _score(row['face_match_score'])),
                    _field('Prueba de vida', _score(row['liveness_score'])),
                    _field('Creado', _fmtDate(row['created_at'])),
                  ],
                ),
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    main,
                    const Divider(height: 22),
                    scores,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 18),
                  scores,
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey('${widget.channel}-$revision'),
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                  onPressed: () => setState(() => revision++),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('No se pudo cargar · Reintentar'),
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final sessions = _list(data['sessions']);
          final namesRaw = data['names'];
          final names = namesRaw is Map
              ? namesRaw.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : <String, String>{};
          final filtered = _filtered(sessions, names);

          int count(String status) => sessions
              .where((row) =>
                  (row['status'] ?? '').toString().toLowerCase() == status)
              .length;

          final environmentLabel = isPreview ? 'SANDBOX / PRUEBA' : 'LIVE / PRODUCCIÓN';

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFEAF2FF),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: _blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Didit · Centro de identidad',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sesiones, estados, Face Match, liveness y trazabilidad '
                          'de lo enviado y recibido.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isPreview
                          ? const Color(0xFFFFF7E6)
                          : const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      environmentLabel,
                      style: TextStyle(
                        color: isPreview ? _amber : _green,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7DAFF)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: _blue, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        isPreview
                            ? 'Mostrando únicamente sesiones Didit Sandbox. '
                                'La API Key y el Signing Secret permanecen fuera del panel.'
                            : 'Mostrando únicamente sesiones Didit Producción. '
                                'La API Key y el Signing Secret permanecen fuera del panel.',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width < 650
                      ? width
                      : width < 1000
                          ? (width - 12) / 2
                          : (width - 36) / 4;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _metric(
                          'Sesiones',
                          sessions.length,
                          Icons.badge_outlined,
                          _blue,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metric(
                          'Verificadas',
                          count('verified'),
                          Icons.verified_rounded,
                          _green,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metric(
                          'En revisión / proceso',
                          count('review') + count('processing') + count('pending'),
                          Icons.hourglass_top_rounded,
                          _amber,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metric(
                          'Rechazadas',
                          count('rejected'),
                          Icons.cancel_outlined,
                          _red,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            hintText: 'Buscar conductor, país o estado',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: statusFilter,
                          decoration: const InputDecoration(labelText: 'Estado'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Todos')),
                            DropdownMenuItem(value: 'verified', child: Text('Verificado')),
                            DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                            DropdownMenuItem(value: 'processing', child: Text('Procesando')),
                            DropdownMenuItem(value: 'review', child: Text('En revisión')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rechazado')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => statusFilter = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: countryFilter,
                          decoration: const InputDecoration(labelText: 'País'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Todos')),
                            DropdownMenuItem(value: 'BO', child: Text('Bolivia')),
                            DropdownMenuItem(value: 'CL', child: Text('Chile')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => countryFilter = value);
                            }
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => revision++),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Actualizar'),
                      ),
                      Text(
                        '${filtered.length} resultado(s)',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.fingerprint_outlined,
                          color: _muted,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sessions.isEmpty
                              ? 'Todavía no hay sesiones Didit en $environmentLabel.'
                              : 'No hay sesiones que coincidan con los filtros.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((row) {
                  final userId = (row['user_id'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _sessionCard(row, names[userId]),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
