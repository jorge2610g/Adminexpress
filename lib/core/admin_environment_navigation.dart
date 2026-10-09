import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_client.dart';

/// Navigation ONLY: both sites use Supabase MAIN.
/// ADMIN_ENV fixes the environment channel at build time; this link never
/// elevates permissions or changes the active data channel in-app.
/// Resolving relative to the current site supports both a domain root and a
/// future GitHub Pages project subpath.
class AdminEnvironmentLinkButton extends StatelessWidget {
  const AdminEnvironmentLinkButton({super.key});

  static String get label =>
      adminIsPreview ? 'Ir a Producción' : 'Ir a Prueba';

  static Uri get destination =>
      Uri.base.resolve(adminIsPreview ? '../' : 'preview/');

  Future<void> _navigate(BuildContext context) async {
    try {
      final opened = await launchUrl(
        destination,
        webOnlyWindowName: '_self',
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el otro panel.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el otro panel.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _navigate(context),
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: adminIsPreview
              ? const Color(0xFF0F6848)
              : const Color(0xFF7A2E0E),
          side: BorderSide(
            color: adminIsPreview
                ? const Color(0xFF9AD8B3)
                : const Color(0xFFF5C36A),
          ),
        ),
      );
}
