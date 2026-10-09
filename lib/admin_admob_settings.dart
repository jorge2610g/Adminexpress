import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Admin > Publicidad (AdMob). Both websites share the main Supabase project,
/// but the server checks the requested environment against admin permissions.
/// No password, API token, or service-role key is ever accepted/stored here.
class AdminAdMobSettingsPage extends StatefulWidget {
  const AdminAdMobSettingsPage({super.key, required this.channel});

  final String channel;

  @override
  State<AdminAdMobSettingsPage> createState() => _AdminAdMobSettingsPageState();
}

class _AdminAdMobSettingsPageState extends State<AdminAdMobSettingsPage> {
  final _appId = TextEditingController();
  final _bannerId = TextEditingController();
  final _publisherId = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _home = true;
  bool _trip = true;
  String? _error;
  int _revision = 0;

  bool get _preview => widget.channel == 'preview';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminAdMobSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) _load();
  }

  Future<void> _load() async {
    final currentRevision = ++_revision;
    final channel = widget.channel;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc(
        'admin_admob_settings_get',
        params: {'p_channel': channel},
      );
      if (!mounted || currentRevision != _revision || channel != widget.channel) {
        return;
      }
      if (raw is! Map) throw StateError('Respuesta de anuncios no válida');
      final data = Map<String, dynamic>.from(raw);
      setState(() {
        _enabled = data['enabled'] == true;
        _home = data['home_enabled'] != false;
        _trip = data['trip_enabled'] != false;
        _appId.text = (data['admob_android_app_id'] ?? '').toString();
        _bannerId.text =
            (data['admob_passenger_banner_unit_id'] ?? '').toString();
        _publisherId.text = (data['admob_publisher_id'] ?? '').toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || currentRevision != _revision) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la configuración: $error';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final channel = widget.channel;
    final currentRevision = _revision;
    if (!_preview && _enabled &&
        (_appId.text.trim().isEmpty ||
         _bannerId.text.trim().isEmpty ||
         _publisherId.text.trim().isEmpty)) {
      setState(() => _error =
          'Antes de activar Producción, introduce los tres ID de Google AdMob.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc(
        'admin_admob_settings_update',
        params: {
          'p_channel': channel,
          'p_enabled': _enabled,
          'p_home_enabled': _home,
          'p_trip_enabled': _trip,
          // Preview MUST NOT write actual monetization identifiers.
          'p_android_app_id': _preview ? null : _appId.text.trim(),
          'p_banner_unit_id': _preview ? null : _bannerId.text.trim(),
          'p_publisher_id': _preview ? null : _publisherId.text.trim(),
        },
      );
      if (!mounted || currentRevision != _revision || channel != widget.channel) {
        return;
      }
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        setState(() {
          _enabled = data['enabled'] == true;
          _home = data['home_enabled'] != false;
          _trip = data['trip_enabled'] != false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publicidad ${_preview ? "de Prueba" : "de Producción"} guardada. '
            '${_enabled ? "Activada" : "Desactivada"}.',
          ),
        ),
      );
    } catch (error) {
      if (mounted && currentRevision == _revision) {
        setState(() => _error = 'No se pudieron guardar los anuncios: $error');
      }
    } finally {
      if (mounted && currentRevision == _revision) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _appId.dispose();
    _bannerId.dispose();
    _publisherId.dispose();
    super.dispose();
  }

  Widget _idInput(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: 'ID público de AdMob. No introduzcas contraseñas ni tokens.',
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Admin · Publicidad (Google AdMob)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                Chip(label: Text(_preview ? 'PRUEBA' : 'PRODUCCIÓN')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _preview
                  ? 'Solo anuncios de prueba de Google. Ningún cambio modifica '
                    'las credenciales ni la publicidad de Producción.'
                  : 'Administra los anuncios de pasajeros y los ID públicos '
                    'de tu cuenta AdMob. Los anuncios reales siguen apagados '
                    'hasta activarlos y tener una APK configurada.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: _saving ? null : (value) => setState(() => _enabled = value),
              title: Text(_preview
                  ? 'Activar anuncios de Prueba'
                  : 'Activar anuncios de Producción'),
              subtitle: const Text('Interruptor general: apagarlo oculta todos los anuncios de pasajeros.'),
            ),
            const Divider(height: 2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _home,
              onChanged: _saving ? null : (value) => setState(() => _home = value),
              title: const Text('Mostrar en Inicio'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _trip,
              onChanged: _saving ? null : (value) => setState(() => _trip = value),
              title: const Text('Mostrar durante un viaje'),
            ),
            const Divider(height: 26),
            if (_preview)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Preview usa las unidades oficiales de prueba de Google. '
                  'No necesitas colocar identificadores reales aquí.',
                ),
              )
            else ...[
              const Text('Credenciales públicas / identificadores AdMob',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _idInput(_publisherId, 'ID de editor (Publisher ID)',
                  'pub-1234567890123456'),
              _idInput(_appId, 'ID de aplicación Android (App ID)',
                  'ca-app-pub-1234567890123456~1234567890'),
              _idInput(_bannerId, 'ID de unidad Banner (Ad Unit ID)',
                  'ca-app-pub-1234567890123456/1234567890'),
              const Card(
                color: Color(0xFFFFF7E6),
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Importante: guardar el App ID aquí no cambia el '
                    'AndroidManifest de una APK instalada. Para anuncios reales '
                    'se necesita compilar una versión de Express con el mismo '
                    'App ID y configurar el ID de Banner en el build o en la '
                    'configuración remota compatible. No compartas claves '
                    'secretas de Google, OAuth ni credenciales de pago.',
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 17, width: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar publicidad'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
