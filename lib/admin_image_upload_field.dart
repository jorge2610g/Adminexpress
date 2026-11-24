import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';

/// Imagen que se elige de la galería (o del computador) y se sube sola; deja la dirección
/// pública en [controller]. Reemplaza al campo «URL de imagen».
class AdminImageUploadField extends StatefulWidget {
  const AdminImageUploadField({
    super.key,
    required this.controller,
    this.label = 'Imagen',
  });

  final TextEditingController controller;
  final String label;

  @override
  State<AdminImageUploadField> createState() => _AdminImageUploadFieldState();
}

class _AdminImageUploadFieldState extends State<AdminImageUploadField> {
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 86,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        setState(() => _error = 'La imagen debe pesar menos de 5 MB.');
        return;
      }
      setState(() => _uploading = true);
      final name = image.name.toLowerCase();
      final ext = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw StateError('Sesión no válida');
      // Mismo depósito público que usan los restaurantes al registrarse.
      final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await supabase.storage.from('marketplace-merchant-applications').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final url =
          supabase.storage.from('marketplace-merchant-applications').getPublicUrl(path);
      if (mounted) setState(() => widget.controller.text = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo subir la imagen. Intenta con otra.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 84,
            height: 84,
            color: const Color(0xFFF2F4F7),
            child: url.isEmpty
                ? const Icon(Icons.image_outlined, color: Color(0xFF98A2B3), size: 32)
                : Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton.tonalIcon(
              onPressed: _uploading ? null : _pick,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library_outlined),
              label: Text(url.isEmpty ? 'Elegir de la galería' : 'Cambiar imagen'),
            ),
            if (url.isNotEmpty)
              TextButton(
                onPressed: _uploading
                    ? null
                    : () => setState(() => widget.controller.text = ''),
                child: const Text('Quitar'),
              ),
          ]),
        ),
      ]),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFC2413B))),
        ),
    ]);
  }
}
