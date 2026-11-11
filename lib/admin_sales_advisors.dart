import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Asesores de ventas: alta de asesores, conteo por día, revisión de fotos
/// y pagos por registro terminado.
class AdminSalesAdvisorsPage extends StatefulWidget {
  const AdminSalesAdvisorsPage({super.key, required this.canEdit});

  final bool canEdit;

  @override
  State<AdminSalesAdvisorsPage> createState() => _AdminSalesAdvisorsPageState();
}

class _AdminSalesAdvisorsPageState extends State<AdminSalesAdvisorsPage> {
  static const _publicBase = 'https://expressviajes.online';
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc('admin_sales_overview');
    return Map<String, dynamic>.from(value as Map);
  }

  void _reload() => setState(() => _future = _load());

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : const [];

  String _money(dynamic amount) {
    final value = num.tryParse(amount?.toString() ?? '') ?? 0;
    return 'Bs ${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}';
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _say(done);
      _reload();
    } catch (error) {
      _say(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Código automático: primer nombre + 3 caracteres al azar (ej. ANA-7K3).
  /// Sin 0/O ni 1/I para que no se confundan al leerlo.
  static String _generateCode(String fullName) {
    const accents = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    };
    final first = fullName.trim().toUpperCase().split(RegExp(r'\s+')).first;
    final letters = first
        .split('')
        .map((c) => accents[c] ?? c)
        .where((c) => RegExp('[A-Z]').hasMatch(c))
        .take(8)
        .join();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(
      3,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return '${letters.isEmpty ? 'ASESOR' : letters}-$suffix';
  }

  String _latestAccountQuery = '';

  /// Cuentas Express que coinciden con lo escrito (espera a que dejes de escribir).
  Future<List<Map<String, dynamic>>> _findAccounts(String query) async {
    final text = query.trim();
    _latestAccountQuery = text;
    if (text.length < 3) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (text != _latestAccountQuery) return const [];
    try {
      final value = await supabase
          .rpc('admin_sales_find_accounts', params: {'p_query': text});
      return _rows(value);
    } catch (_) {
      return const [];
    }
  }

  Widget _emailField(
    TextEditingController controller,
    String helper,
    StateSetter setDialogState,
  ) {
    final focus = FocusNode();
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: controller,
      focusNode: focus,
      displayStringForOption: (option) => option['email'].toString(),
      optionsBuilder: (value) => _findAccounts(value.text),
      onSelected: (_) => setDialogState(() {}),
      fieldViewBuilder: (context, textController, focusNode, onSubmit) =>
          TextField(
        controller: textController,
        focusNode: focusNode,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Correo de su cuenta Express',
          helperText: helper,
          suffixIcon: const Icon(Icons.search_rounded, size: 18),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      option['already_advisor'] == true
                          ? Icons.badge_rounded
                          : Icons.person_outline_rounded,
                      size: 20,
                    ),
                    title: Text(option['email'].toString()),
                    subtitle: Text(
                      [
                        if (option['name'].toString().isNotEmpty)
                          option['name'].toString(),
                        if (option['already_advisor'] == true)
                          'Ya es asesor',
                      ].join(' · '),
                    ),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editAdvisor([Map<String, dynamic>? advisor]) async {
    final name = TextEditingController(text: advisor?['name']?.toString() ?? '');
    final code = TextEditingController(text: advisor?['code']?.toString() ?? '');
    final email = TextEditingController();
    var active = advisor?['active'] != false;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(advisor == null ? 'Nuevo asesor' : 'Editar asesor'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                ),
                const SizedBox(height: 10),
                if (advisor == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'El código del QR se crea automáticamente al guardar.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Código del QR: ${advisor['code']} (no cambia)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 10),
                _emailField(
                  email,
                  advisor == null
                      ? 'Escribe 3 letras y elige la cuenta de la lista.'
                      : 'Déjalo vacío para no cambiar la cuenta.',
                  setDialogState,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                  title: const Text('Activo'),
                ),
              ],
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
    final fullName = name.text.trim();
    final existingCode = code.text.trim().toUpperCase();
    final emailText = email.text.trim();
    name.dispose();
    code.dispose();
    email.dispose();
    if (save != true) return;
    if (fullName.length < 2) {
      _say('Escribe el nombre del asesor.');
      return;
    }
    var savedCode = existingCode;
    await _run(
      () async {
        // Si el código al azar ya existe, se intenta con otro.
        for (var attempt = 0; ; attempt++) {
          savedCode = advisor == null ? _generateCode(fullName) : existingCode;
          try {
            await supabase.rpc('admin_sales_advisor_save', params: {
              'p_id': advisor?['id'],
              'p_full_name': fullName,
              'p_code': savedCode,
              'p_email': emailText,
              'p_active': active,
            });
            return;
          } catch (error) {
            final duplicated = error.toString().contains('23505') &&
                error.toString().contains('code');
            if (advisor != null || !duplicated || attempt >= 4) rethrow;
          }
        }
      },
      advisor == null ? 'Asesor creado.' : 'Asesor guardado.',
    );
  }

  Future<void> _reviewEvidence(Map<String, dynamic> row) async {
    String? url;
    try {
      url = await supabase.storage
          .from('sales-evidence')
          .createSignedUrl(row['storage_path'].toString(), 300);
    } catch (error) {
      _say(friendlyError(error));
      return;
    }
    if (!mounted) return;
    final note = TextEditingController();
    final approve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Foto de ${row['first_name'] ?? 'registro'} · ${row['role'] == 'driver' ? 'Conductor' : 'Pasajero'}',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Asesor: ${row['advisor']}'),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: Image.network(
                  url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('No se pudo cargar la foto.'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Rechazar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    final noteText = note.text.trim();
    note.dispose();
    if (approve == null) return;
    await _run(
      () async => supabase.rpc('admin_sales_review_evidence', params: {
        'p_evidence_id': row['evidence_id'],
        'p_approve': approve,
        'p_note': noteText,
      }),
      approve ? 'Foto aprobada: el pago quedó por pagar.' : 'Foto rechazada.',
    );
  }

  Future<void> _markPaid(Map<String, dynamic> row) async {
    final reference = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pagar ${_money(row['amount'])} a ${row['advisor']}'),
        content: TextField(
          controller: reference,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Referencia de la transferencia',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Marcar pagado'),
          ),
        ],
      ),
    );
    final text = reference.text.trim();
    reference.dispose();
    if (ok != true) return;
    await _run(
      () async => supabase.rpc('admin_sales_mark_paid', params: {
        'p_payout_id': row['payout_id'],
        'p_reference': text,
      }),
      'Pago registrado.',
    );
  }

  Widget _card(String title, List<Widget> children, {Widget? action}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(friendlyError(snapshot.error)),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        final data = snapshot.data ?? const {};
        final advisors = _rows(data['advisors']);
        final byDay = _rows(data['by_day']);
        final flagged = _rows(data['flagged']);
        final evidence = _rows(data['evidence_pending']);
        final payouts = _rows(data['payouts_to_pay']);
        final edit = widget.canEdit;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              'Asesores de ventas',
              [
                const Text(
                  'Pasajero: Bs 1 · Conductor aprobado: Bs 2. Se paga solo con '
                  'registro terminado y foto aprobada.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                if (advisors.isEmpty) _empty('Todavía no hay asesores.'),
                for (final a in advisors)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.badge_rounded,
                      color: a['active'] == true
                          ? const Color(0xFF0B57D0)
                          : const Color(0xFF9CA3AF),
                    ),
                    title: Text(
                      '${a['name']} · ${a['code']}'
                      '${a['active'] == true ? '' : ' · Inactivo'}'
                      '${a['has_account'] == true ? '' : ' · Sin cuenta'}',
                    ),
                    subtitle: Text(
                      'Hoy: ${a['today']} · Registrados: ${a['attributed']} · '
                      'Completados: ${a['registered']} · '
                      'Por pagar: ${_money(a['to_pay'])} · Pagado: ${_money(a['paid'])}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Copiar enlace del QR',
                          icon: const Icon(Icons.link_rounded),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(
                              text: '$_publicBase/r/${a['code']}',
                            ));
                            _say('Enlace copiado: $_publicBase/r/${a['code']}');
                          },
                        ),
                        if (edit)
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _editAdvisor(a),
                          ),
                      ],
                    ),
                  ),
                const Text(
                  'Cada asesor ve su QR y sus registros en '
                  '$_publicBase/asesor',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (edit)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _editAdvisor(),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Nuevo asesor'),
                    ),
                ],
              ),
            ),
            _card('Fotos por revisar (${evidence.length})', [
              if (evidence.isEmpty) _empty('No hay fotos pendientes.'),
              for (final e in evidence)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(
                    '${e['first_name'] ?? 'Registro'} · '
                    '${e['role'] == 'driver' ? 'Conductor' : 'Pasajero'}',
                  ),
                  subtitle: Text('Asesor: ${e['advisor']}'),
                  trailing: edit
                      ? FilledButton(
                          onPressed: _busy ? null : () => _reviewEvidence(e),
                          child: const Text('Revisar'),
                        )
                      : null,
                ),
            ]),
            _card('Pagos por hacer (${payouts.length})', [
              if (payouts.isEmpty) _empty('No hay pagos pendientes.'),
              for (final p in payouts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_rounded),
                  title: Text('${p['advisor']} · ${_money(p['amount'])}'),
                  subtitle: Text(
                    p['role'] == 'driver' ? 'Conductor' : 'Pasajero',
                  ),
                  trailing: edit
                      ? OutlinedButton(
                          onPressed: _busy ? null : () => _markPaid(p),
                          child: const Text('Marcar pagado'),
                        )
                      : null,
                ),
            ]),
            if (flagged.isNotEmpty)
              _card('Registros en revisión (${flagged.length})', [
                for (final f in flagged)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.report_gmailerrorred_rounded,
                      color: Color(0xFFB3261E),
                    ),
                    title: Text('${f['first_name'] ?? 'Registro'} · ${f['advisor']}'),
                    subtitle: Text(f['reason']?.toString() ?? ''),
                    trailing: edit
                        ? TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                      () async => supabase.rpc(
                                        'admin_sales_clear_flag',
                                        params: {
                                          'p_attribution_id': f['attribution_id'],
                                        },
                                      ),
                                      'Registro liberado.',
                                    ),
                            child: const Text('Liberar'),
                          )
                        : null,
                  ),
              ]),
            _card('Registros por día (últimos 30 días)', [
              if (byDay.isEmpty) _empty('Todavía no hay registros.'),
              for (final d in byDay)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 110, child: Text(d['day'].toString())),
                      Expanded(child: Text(d['advisor'].toString())),
                      Text(
                        'Registrados ${d['attributed']} · Completados ${d['registered']}',
                      ),
                    ],
                  ),
                ),
            ]),
          ],
        );
      },
    );
  }
}
