import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Bolivia-only policy and manual KYC reviews. Never changes Chile settings.
class AdminBoliviaKycPanel extends StatefulWidget {
  const AdminBoliviaKycPanel({
    super.key,
    required this.channel,
    required this.countryCode,
  });
  final String channel;
  final String? countryCode;

  @override
  State<AdminBoliviaKycPanel> createState() => _AdminBoliviaKycPanelState();
}

class _AdminBoliviaKycPanelState extends State<AdminBoliviaKycPanel> {
  bool _busy = false;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminBoliviaKycPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.countryCode != widget.countryCode) {
      _reload();
    }
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v)).toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Future<Map<String, dynamic>> _load() async {
    if (widget.countryCode?.toUpperCase() != 'BO') return {};
    final results = await Future.wait([
      supabase.rpc('admin_driver_kyc_bolivia_manual_list',
          params: {'p_channel':widget.channel,'p_limit':150}),
    ]);
    return {'settings':_map(results[0]),'documents':_list(results[1])};
  }

  void _reload() {
    if (mounted) setState(() { _future = _load(); });
  }

  String _slotLabel(String slot) => switch (slot) {
    'front' => 'Frente del carné',
    'back' => 'Reverso del carné',
    'selfie' => 'Fotografía facial',
    _ => 'Foto de perfil',
  };

  String _statusLabel(String status) => switch(status) {
    'approved' => 'Aprobada',
    'rejected' => 'Rechazada',
    'pending' => 'Pendiente',
    _ => 'Sin revisar',
  };

  Future<void> _reviewSlot(
    Map<String,dynamic> doc,
    String slot,
    String nextStatus,
    int expectedVersion,
  ) async {
    if (_busy) return;
    final current = _map(_map(doc['review_parts'])[slot]);
    final oldStatus = _text(current['status']);
    if (oldStatus == nextStatus) return;
    final reasonController=TextEditingController();
    final confirm=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:Text(nextStatus=='rejected' ? 'Rechazar ${_slotLabel(slot)}'
          : nextStatus=='approved' ? 'Aprobar ${_slotLabel(slot)}'
          : 'Reactivar ${_slotLabel(slot)}'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Cambiar de ${_statusLabel(oldStatus)} a '
            '${_statusLabel(nextStatus)}. '
            'Las otras fotografías no cambiarán. '
            'Una aprobación del documento NO aprueba al conductor.'),
          if(nextStatus=='rejected') ...[
            const SizedBox(height:12),
            TextField(
              controller:reasonController,
              maxLines:2,
              decoration:const InputDecoration(
                border:OutlineInputBorder(),
                labelText:'Motivo del rechazo',
              ),
            ),
          ],
        ]),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(dialogContext,false),
            child:const Text('Cancelar')),
          FilledButton(
            onPressed:()=>Navigator.pop(dialogContext,true),
            child:const Text('Confirmar')),
        ],
      ),
    );
    final reason=reasonController.text.trim();
    reasonController.dispose();
    if(confirm!=true || !mounted) return;
    if(nextStatus=='rejected' && reason.length<5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Escribe al menos cinco caracteres como motivo.')));
      return;
    }
    setState(()=>_busy=true);
    try {
      await supabase.rpc('admin_driver_kyc_bolivia_manual_review_part',params:{
        'p_document_id':doc['id'],
        'p_slot':slot,
        'p_status':nextStatus,
        'p_reason':nextStatus=='rejected' ? reason:null,
        'p_expected_version':expectedVersion,
        'p_channel':widget.channel,
      });
      if(mounted) {
        Navigator.of(context).pop(); // Close document details after action.
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('${_slotLabel(slot)}: ${_statusLabel(nextStatus)}.'),
        ));
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo actualizar la fotografía: $e. Actualiza la lista.')));
    } finally {
      if(mounted) setState(()=>_busy=false);
    }
  }

  Future<void> _details(Map<String,dynamic> document) async {
    // Short-lived links for authenticated administrators, never public assets.
    final signed=<String,String>{};
    final slots=<String,String>{
      'front':'front_object_path',
      'back':'back_object_path',
      'selfie':'selfie_object_path',
      // Bolivia uses the verified selfie as the profile photograph.
    };
    for(final entry in slots.entries){
      final objectPath=_text(document[entry.value]);
      if(objectPath.isEmpty) continue;
      try {
        signed[entry.key]=await supabase.storage
          .from('driver-onboarding').createSignedUrl(objectPath,300);
      } catch (_) {}
    }
    if(!mounted) return;
    final parts=_map(document['review_parts']);
    await showDialog<void>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Revisión individual · Bolivia'),
        content:SizedBox(width:690,child:SingleChildScrollView(
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Conductor: ${_text(document['full_name'])}'),
            Text('Carné: ${_text(document['document_number'])}'),
            Text('Identidad: ${_statusLabel(
              _text(document['status'])=='verified' ? 'approved'
                : _text(document['status']))}'),
            const SizedBox(height:8),
            const Text('Puedes aprobar, rechazar o reactivar cada fotografía '
              'en cualquier momento. No se exige volver a cargar una foto '
              'si el rechazo fue un error administrativo.'),
            for (final slot in slots.keys) ...[
              const Divider(height:24),
              Text(_slotLabel(slot),
                style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
              const SizedBox(height:6),
              Builder(builder:(context) {
                final part=_map(parts[slot]);
                final current=_text(part['status']).isEmpty
                  ? 'pending':_text(part['status']);
                final version=int.tryParse(_text(part['version']))??0;
                final reason=_text(part['reason']);
                final exists=signed.containsKey(slot);
                return Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('Estado: ${_statusLabel(current)}'),
                    if(reason.isNotEmpty) Text('Motivo: $reason'),
                    const SizedBox(height:6),
                    if(exists)
                      ClipRRect(
                        borderRadius:BorderRadius.circular(10),
                        child:Image.network(
                          signed[slot]!,height:200,width:360,
                          fit:BoxFit.contain,
                          errorBuilder:(_,__,___)=>const Text(
                            'No se pudo visualizar esta fotografía.'),
                        ),
                      )
                    else const Text('Imagen no disponible.'),
                    const SizedBox(height:10),
                    if(exists) Wrap(spacing:7,runSpacing:8,children:[
                      if(current!='approved')
                        FilledButton.icon(
                          onPressed:_busy ? null:()=>_reviewSlot(
                            document,slot,'approved',version),
                          icon:const Icon(Icons.check_circle_outline),
                          label:const Text('Aprobar'),
                        ),
                      if(current!='rejected')
                        OutlinedButton.icon(
                          onPressed:_busy ? null:()=>_reviewSlot(
                            document,slot,'rejected',version),
                          icon:const Icon(Icons.highlight_off),
                          label:const Text('Rechazar'),
                        ),
                      if(current!='pending')
                        OutlinedButton.icon(
                          onPressed:_busy ? null:()=>_reviewSlot(
                            document,slot,'pending',version),
                          icon:const Icon(Icons.restart_alt),
                          label:const Text('Reactivar'),
                        ),
                    ]),
                  ],
                );
              }),
            ],
            const SizedBox(height:12),
            const Text('La aprobación del conductor y del vehículo '
              'es independiente de estas fotografías.'),
          ]),
        )),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),
            child:const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.countryCode?.toUpperCase() != 'BO') {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Map<String,dynamic>>(
      future:_future,
      builder:(context,snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return Card(child:Padding(
            padding:const EdgeInsets.all(14),
            child:Column(children:[
              const Text('No se pudo consultar el método de Bolivia.'),
              TextButton(onPressed:_reload,child:const Text('Reintentar')),
            ])));
          return const LinearProgressIndicator();
        }
        final data=snapshot.data!;
        final cfg=_map(data['settings']);
        final docs=_list(data['documents']);
        final mode=_text(cfg['preferred_method']).isEmpty
            ? 'automatic':_text(cfg['preferred_method']);
        final used=int.tryParse(_text(cfg['used']))??0;
        final remaining=int.tryParse(_text(cfg['remaining']))??0;
        return Card(
          child:Padding(
            padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              const Text('Bolivia · Control de reconocimiento de identidad',
                style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
              const SizedBox(height:6),
              Text('Didit: $used de 30 sesiones usadas este mes · '
                '$remaining disponibles · Canal: ${widget.channel}',
                style:const TextStyle(fontWeight:FontWeight.w700)),
              const SizedBox(height:7),
              LinearProgressIndicator(value:(used/30).clamp(0.0,1.0)),
              const SizedBox(height:14),
              DropdownButtonFormField<String>(
                key:ValueKey('${widget.channel}-$mode'),
                initialValue:mode,
                decoration:const InputDecoration(
                  labelText:'Método sugerido de verificación',
                  border:OutlineInputBorder(),
                ),
                items:const [
                  DropdownMenuItem(value:'automatic',
                    child:Text('Automático · 30 Didit y luego manual')),
                  DropdownMenuItem(value:'didit',
                    child:Text('Preferir Didit (respetar límite)')),
                  DropdownMenuItem(value:'manual',
                    child:Text('Solo Express manual')),
                ],
                onChanged:_busy?null:(value) {
                  if (value!=null) _setMethod(value);
                },
              ),
              const SizedBox(height:8),
              const Text('El contador utiliza el mes de Bolivia. '
                'Al llegar a 30, el próximo registro usa capturas manuales. '
                'Las verificaciones iniciadas mantienen su estado.',
                style:TextStyle(fontSize:12)),
              const SizedBox(height:18),
              Row(children:[
                Expanded(child:Text(
                  'Identidades por revisar: ${docs.where((d) => d['status'] != 'verified').length}',
                  style:const TextStyle(fontSize:16,
                    fontWeight:FontWeight.w800))),
                IconButton(onPressed:_reload,icon:const Icon(Icons.refresh)),
              ]),
              if (docs.isEmpty)
                const Padding(
                  padding:EdgeInsets.symmetric(vertical:12),
                  child:Text('Aún no hay documentos manuales en Bolivia.')),
              for (final doc in docs.take(40)) ListTile(
                contentPadding:EdgeInsets.zero,
                leading:Icon(doc['status']=='pending'
                  ? Icons.hourglass_empty:Icons.verified_user_outlined),
                title:Text(_text(doc['full_name']).isNotEmpty
                  ? _text(doc['full_name']):'Conductor · Bolivia'),
                subtitle:Text('Carné ${_text(doc['document_number'])} · '
                  '${_text(doc['status'])}'),
                trailing:const Icon(Icons.chevron_right),
                onTap:()=>_details(doc),
              ),
            ]),
          ),
        );
      },
    );
  }
}
