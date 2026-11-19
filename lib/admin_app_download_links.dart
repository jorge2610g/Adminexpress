import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

/// Edición centralizada del QR público de Express.
class AdminAppDownloadLinksCard extends StatefulWidget {
  final bool canEdit;

  const AdminAppDownloadLinksCard({super.key, required this.canEdit});

  @override
  State<AdminAppDownloadLinksCard> createState() =>
      _AdminAppDownloadLinksCardState();
}

class _AdminAppDownloadLinksCardState
    extends State<AdminAppDownloadLinksCard> {
  static const qrUrl = 'https://expressviajes.online/app/';
  static const platforms = <String, (String, IconData, String)>{
    'android': ('Android / Google Play', Icons.android_rounded,
        'URL oficial de descarga para celulares Android.'),
    'ios': ('iPhone / App Store', Icons.phone_iphone_rounded,
        'Déjalo desactivado mientras Express no tenga ficha publicada en App Store.'),
    'web': ('Computadora y otros', Icons.language_rounded,
        'Página que se abrirá en equipos que no sean Android ni iOS.'),
  };

  final Map<String, TextEditingController> _urls = {
    for (final p in platforms.keys) p: TextEditingController(),
  };
  final Map<String, bool> _enabled = {
    for (final p in platforms.keys) p: false,
  };

  bool _loading = true;
  String? _saving;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _urls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('app_download_links')
          .select('platform,url,enabled');
      if (!mounted) return;
      for (final row in rows) {
        final platform = row['platform']?.toString();
        if (platform != null && _urls.containsKey(platform)) {
          _urls[platform]!.text = row['url']?.toString() ?? '';
          _enabled[platform] = row['enabled'] == true;
        }
      }
    } catch (error) {
      if (mounted) _error = 'No se pudieron consultar los enlaces: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String platform) async {
    if (!widget.canEdit || _saving != null) return;
    final url = _urls[platform]!.text.trim();
    final parsed = Uri.tryParse(url);
    if (url.isNotEmpty && (parsed == null ||
        parsed.scheme != 'https' || parsed.host.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un enlace HTTPS válido.')),
      );
      return;
    }
    if ((_enabled[platform] ?? false) && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega el enlace antes de activarlo.')),
      );
      return;
    }
    setState(() => _saving = platform);
    try {
      await supabase.rpc('admin_app_download_link_update', params: {
        'p_platform': platform,
        'p_url': url,
        'p_enabled': _enabled[platform] ?? false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace de ${platforms[platform]!.$1} guardado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Widget _platformCard(String platform) {
    final data = platforms[platform]!;
    final active = _enabled[platform] ?? false;
    final saving = _saving == platform;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.$2, color: const Color(0xFF1454BD)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data.$1,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Switch.adaptive(
                  value: active,
                  onChanged: widget.canEdit && _saving == null
                      ? (value) => setState(() => _enabled[platform] = value)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(data.$3, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: _urls[platform],
              enabled: widget.canEdit && _saving == null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Enlace HTTPS para ${data.$1}',
                hintText: 'https://...',
                helperText: active ? 'Activo al escanear el QR' : 'No disponible para usuarios',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: widget.canEdit && _saving == null
                    ? () => _save(platform)
                    : null,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar este enlace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(35),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('QR inteligente de descarga',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Modifica el destino de cada plataforma sin cambiar ni reimprimir '
          'el QR de los chalecos, vehículos o anuncios.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        Card(
          color: const Color(0xFFEFF6FF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enlace permanente del QR',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const SelectableText(qrUrl),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: qrUrl));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enlace QR copiado.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar enlace'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(qrUrl),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Probar QR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final platform in platforms.keys) _platformCard(platform),
        if (!widget.canEdit)
          const Text(
            'Solo el superadministrador puede cambiar estos enlaces.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
      ],
    );
  }
}
