import 'package:flutter/material.dart';
import 'admin_bolivia_kyc.dart';

/// Express manual identity reviews across all configured countries.
class AdminManualIdentityPage extends StatelessWidget {
  const AdminManualIdentityPage({
    super.key,required this.channel,this.countryCode,this.zoneId,
  });
  final String channel;
  final String? countryCode;
  final String? zoneId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:const EdgeInsets.all(18),
      children:[
        Text('Verificación manual',
          style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:6),
        const Text('Un administrador verifica el carné y la selfie. '
          'Puede aprobar, rechazar o reactivar fotografías por separado.'),
        const SizedBox(height:16),
        AdminBoliviaKycPanel(
          channel:channel,
          countryCode:countryCode,
          zoneId:zoneId,
        ),
      ],
    );
  }
}
