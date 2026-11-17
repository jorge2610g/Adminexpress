import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Interruptores de verificación de pasajeros: foto de perfil, carnet de
/// identidad (frente y reverso) y selfie de reconocimiento facial.
///
/// Solo super_admin: las RPC `admin_passenger_verification_*` lo exigen en la
/// base. La configuración se guarda aunque la app aún no la solicite.
class AdminPassengerVerificationSettings extends StatefulWidget {
  const AdminPassengerVerificationSettings({super.key});

  @override
  State<AdminPassengerVerificationSettings> createState() =>
      _AdminPassengerVerificationSettingsState();
}

class _AdminPassengerVerificationSettingsState
    extends State<AdminPassengerVerificationSettings> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _profilePhoto = true;
  bool _identity = false;
  bool _selfie = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc('admin_passenger_verification_settings_get');
      if (raw is Map && mounted) {
        setState(() {
          _profilePhoto = raw['profile_photo_required'] == true;
          _identity = raw['identity_document_required'] == true;
          _selfie = raw['face_selfie_required'] == true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.rpc(
        'admin_passenger_verification_settings_update',
        params: {
          'p_profile_photo_required': _profilePhoto,
          'p_identity_document_required': _identity,
          'p_face_selfie_required': _selfie,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Requisitos de pasajeros guardados.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Requisitos de pasajeros'),
      subtitle: const Text('Foto de perfil, carnet y selfie de reconocimiento facial'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _profilePhoto,
            onChanged: _saving ? null : (value) => setState(() => _profilePhoto = value),
            title: const Text('Pedir foto de perfil cada día'),
            subtitle: const Text(
              'Al pedir un viaje, el pasajero se toma su foto de perfil una vez por día.',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _identity,
            onChanged: _saving ? null : (value) => setState(() => _identity = value),
            title: const Text('Pedir carnet de identidad (anverso y reverso)'),
            subtitle: const Text(
              'Apagado: no se piden documentos. Encendido: al pedir un viaje, si aún no los tiene. Solo los ve el administrador.',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _selfie,
            onChanged: _saving ? null : (value) => setState(() => _selfie = value),
            title: const Text('Pedir selfie para reconocimiento facial'),
            subtitle: const Text(
              'Apagado por ahora. Se pide al pedir un viaje, junto con el carnet. Solo la ve el administrador.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar requisitos'),
            ),
          ),
        ],
      ],
    );
  }
}
