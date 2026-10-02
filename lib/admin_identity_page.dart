import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const Color _blue = Color(0xFF0B57D0);
const Color _dark = Color(0xFF101828);
const Color _muted = Color(0xFF667085);

class AdminIdentityPage extends StatefulWidget {
  const AdminIdentityPage({super.key});

  @override
  State<AdminIdentityPage> createState() => _AdminIdentityPageState();
}

class _AdminIdentityPageState extends State<AdminIdentityPage> {
  int revision = 0;

  Future<({
    Map<String, dynamic> settings,
    List<Map<String, dynamic>> queue,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_identity_settings_get'),
      supabase.rpc(
        'admin_identity_verification_list',
        params: {'p_limit': 200},
      ),
    ]);

    return (
      settings: values[0] is Map
          ? Map<String, dynamic>.from(values[0] as Map)
          : <String, dynamic>{},
      queue: _list(values[1]),
    );
  }

  Future<void> _editSettings(Map<String, dynamic> current) async {
    var provider = current['provider']?.toString() ?? 'manual';
    if (!const ['manual', 'veriff', 'sumsub', 'custom'].contains(provider)) {
      provider = 'manual';
    }
    var documentEnabled = current['document_enabled'] != false;
    var faceEnabled = current['face_enabled'] != false;
    var faceMatchEnabled = current['face_match_enabled'] != false;
    var livenessEnabled = current['liveness_enabled'] == true;
    var requireDriver = current['require_driver'] != false;
    var requirePassenger = current['require_passenger'] == true;
    var manualReview = current['manual_review_on_fail'] != false;

    final faceScore = TextEditingController(
      text: current['min_face_score']?.toString() ?? '0.75',
    );
    final livenessScore = TextEditingController(
      text: current['min_liveness_score']?.toString() ?? '0.70',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Configurar verificación de identidad'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: provider,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor principal',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'manual',
                        child: Text('Manual / revisión interna'),
                      ),
                      DropdownMenuItem(
                        value: 'veriff',
                        child: Text('Veriff'),
                      ),
                      DropdownMenuItem(
                        value: 'sumsub',
                        child: Text('Sumsub'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Proveedor personalizado'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => provider = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFCE7B2),
                      ),
                    ),
                    child: const Text(
                      'Las credenciales privadas del proveedor no se guardan en este panel. Se conectan únicamente en backend.',
                      style: TextStyle(
                        color: Color(0xFF7A4A0B),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: documentEnabled,
                    onChanged: (value) =>
                        setLocal(() => documentEnabled = value),
                    title: const Text('Verificar documento'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: faceEnabled,
                    onChanged: (value) =>
                        setLocal(() => faceEnabled = value),
                    title: const Text('Solicitar selfie'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: faceMatchEnabled,
                    onChanged: faceEnabled
                        ? (value) =>
                            setLocal(() => faceMatchEnabled = value)
                        : null,
                    title: const Text(
                      'Comparar selfie con foto del documento/perfil',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: livenessEnabled,
                    onChanged: faceEnabled
                        ? (value) =>
                            setLocal(() => livenessEnabled = value)
                        : null,
                    title: const Text('Prueba de vida'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: requireDriver,
                    onChanged: (value) =>
                        setLocal(() => requireDriver = value),
                    title: const Text('Obligatorio para conductores'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: requirePassenger,
                    onChanged: (value) =>
                        setLocal(() => requirePassenger = value),
                    title: const Text('Obligatorio para pasajeros'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: manualReview,
                    onChanged: (value) =>
                        setLocal(() => manualReview = value),
                    title: const Text(
                      'Mandar a revisión manual si falla',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: faceScore,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Puntaje mínimo rostro (0 a 1)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: livenessScore,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Puntaje mínimo vida (0 a 1)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_identity_settings_update',
          params: {
            'p_provider': provider,
            'p_document_enabled': documentEnabled,
            'p_face_enabled': faceEnabled,
            'p_face_match_enabled': faceMatchEnabled,
            'p_liveness_enabled': livenessEnabled,
            'p_require_driver': requireDriver,
            'p_require_passenger': requirePassenger,
            'p_min_face_score':
                _num(faceScore.text).clamp(0, 1),
            'p_min_liveness_score':
                _num(livenessScore.text).clamp(0, 1),
            'p_manual_review_on_fail': manualReview,
          },
        );
        if (!mounted) return;
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      } catch (e) {
        if (!mounted) return;
        _snack(e);
      }
    }

    faceScore.dispose();
    livenessScore.dispose();
  }

  Future<void> _resolve(
    Map<String, dynamic> row,
    String status,
  ) async {
    final note = TextEditingController();
    final label = status == 'verified'
        ? 'Verificar'
        : status == 'rejected'
            ? 'Rechazar'
            : 'Mandar a revisión';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label + ' identidad'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Nota administrativa',
              hintText: 'Opcional',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(label),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.rpc(
          'admin_identity_resolve',
          params: {
            'p_verification_id': row['id'],
            'p_status': status,
            'p_review_note': note.text.trim(),
          },
        );
        if (!mounted) return;
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado: ' + _statusLabel(status))),
        );
      } catch (e) {
        if (!mounted) return;
        _snack(e);
      }
    }

    note.dispose();
  }

  void _snack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ' + error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          Map<String, dynamic> settings,
          List<Map<String, dynamic>> queue,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCard(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              settings: <String, dynamic>{},
              queue: <Map<String, dynamic>>[],
            );
        final settings = data.settings;

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Verificación de identidad',
              subtitle:
                  'Documento, selfie, comparación facial y revisión manual para proteger pasajeros y conductores.',
              action: FilledButton.icon(
                onPressed: () => _editSettings(settings),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Configurar'),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSummary(settings: settings),
            const SizedBox(height: 24),
            const Text(
              'Cola de verificaciones',
              style: TextStyle(
                color: _dark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las decisiones son administrativas; la app no expone los datos biométricos a otros usuarios.',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            if (data.queue.isEmpty)
              const _Empty(
                text: 'No hay verificaciones pendientes ni históricas.',
              )
            else
              ...data.queue.map(
                (row) => _VerificationRow(
                  row: row,
                  onReview: () => _resolve(row, 'review'),
                  onVerify: () => _resolve(row, 'verified'),
                  onReject: () => _resolve(row, 'rejected'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  final Map<String, dynamic> settings;

  const _SettingsSummary({required this.settings});

  @override
  Widget build(BuildContext context) {
    final provider = settings['provider']?.toString() ?? 'manual';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: _blue),
              const SizedBox(width: 8),
              Text(
                'Proveedor: ' + provider,
                style: const TextStyle(
                  color: _dark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(
                settings['document_enabled'] == true
                    ? 'Documento activo'
                    : 'Documento apagado',
              ),
              _Tag(
                settings['face_enabled'] == true
                    ? 'Selfie activa'
                    : 'Selfie apagada',
              ),
              _Tag(
                settings['face_match_enabled'] == true
                    ? 'Face match activo'
                    : 'Face match apagado',
              ),
              _Tag(
                settings['liveness_enabled'] == true
                    ? 'Prueba de vida activa'
                    : 'Prueba de vida apagada',
              ),
              _Tag(
                settings['require_driver'] == true
                    ? 'Conductor obligatorio'
                    : 'Conductor opcional',
              ),
              _Tag(
                settings['require_passenger'] == true
                    ? 'Pasajero obligatorio'
                    : 'Pasajero opcional',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Umbral rostro: ' +
                (settings['min_face_score'] ?? '—').toString() +
                ' · vida: ' +
                (settings['min_liveness_score'] ?? '—').toString(),
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onReview;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const _VerificationRow({
    required this.row,
    required this.onReview,
    required this.onVerify,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final score = row['face_match_score'];
    final life = row['liveness_score'];
    final document = row['document_score'];

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row['full_name']?.toString() ??
                          row['phone']?.toString() ??
                          'Usuario',
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (row['subject_role'] ?? 'driver').toString() +
                    ' · ' +
                    (row['provider'] ?? 'manual').toString() +
                    ' · ' +
                    (row['document_type'] ?? 'documento').toString(),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Score(label: 'Documento', value: document),
                  _Score(label: 'Rostro', value: score),
                  _Score(label: 'Vida', value: life),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: onReview,
                child: const Text('Revisión'),
              ),
              FilledButton(
                onPressed: onVerify,
                child: const Text('Verificar'),
              ),
              TextButton(
                onPressed: onReject,
                child: const Text('Rechazar'),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 10),
              action,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}

class _Score extends StatelessWidget {
  final String label;
  final Object? value;

  const _Score({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label + ': ' + (value ?? '—').toString(),
        style: const TextStyle(
          color: _dark,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final positive = status == 'verified';
    final negative = status == 'rejected';
    final color = positive
        ? const Color(0xFF14804A)
        : negative
            ? const Color(0xFFD92D20)
            : const Color(0xFFC76B16);
    final bg = positive
        ? const Color(0xFFE8F8EF)
        : negative
            ? const Color(0xFFFFE8E8)
            : const Color(0xFFFFF3E7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _dark,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: const TextStyle(color: _muted)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 8),
              Text(error.toString()),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

double _num(String value) {
  final parsed =
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  return parsed;
}

String _statusLabel(String status) {
  if (status == 'verified') return 'Verificado';
  if (status == 'rejected') return 'Rechazado';
  if (status == 'processing') return 'Procesando';
  if (status == 'review') return 'Revisión';
  return 'Pendiente';
}
