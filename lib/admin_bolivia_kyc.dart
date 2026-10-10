import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Manual document moderation for all supported regions.
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
    final documents=await supabase.rpc('admin_driver_kyc_bolivia_manual_list',
      params:{'p_channel':widget.channel,'p_limit':150});
    final zones=(widget.countryCode??'').trim().isEmpty
      ? <Map<String,dynamic>>[]
      : _list(await supabase.rpc('admin_zone_list_for_country',params:{
          'p_country_code':widget.countryCode!.trim().toUpperCase(),
        }));
    final rows=_list(documents);
    final region=widget.countryCode?.toUpperCase();
    return {
      'documents':rows.where((d)=>region==null || region.isEmpty ||
        _text(d['country_code']).toUpperCase()==region).toList(),
      'zones':zones,
    };
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
    'verified' => 'Verificada',
    'rejected' => 'Rechazada',
    'pending' => 'Pendiente',
    _ => 'Sin revisar',
  };

  Future<Map<String,dynamic>?> _reviewSlot(
    Map<String,dynamic> doc,
    String slot,
    String nextStatus,
    int expectedVersion,
  ) async {
    if (_busy) return null;
    final current = _map(_map(doc['review_parts'])[slot]);
    final oldStatus = _text(current['status']);
    if (oldStatus == nextStatus) return doc;
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
    if(confirm!=true || !mounted) return null;
    if(nextStatus=='rejected' && reason.length<5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Escribe al menos cinco caracteres como motivo.')));
      return null;
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
      final refreshed=await _load();
      Map<String,dynamic>? updatedDocument;
      for(final candidate in _list(refreshed['documents'])) {
        if(_text(candidate['id'])==_text(doc['id'])) {
          updatedDocument=candidate;
          break;
        }
      }
      if(mounted) {
        setState(()=>_future=Future.value(refreshed));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('${_slotLabel(slot)}: ${_statusLabel(nextStatus)}.'),
        ));
      }
      return updatedDocument;
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo actualizar la fotografía: $e. Actualiza la lista.')));
      return null;
    } finally {
      if(mounted) setState(()=>_busy=false);
    }
  }

  Future<void> _activateDriver(
    Map<String,dynamic> document,
    Map<String,dynamic> zone,
    BuildContext detailContext,
    void Function(bool) setActivationBusy,
  ) async {
    final name=_text(document['full_name']).isEmpty
      ? 'El conductor':_text(document['full_name']);
    final zoneName=_text(zone['name']).isEmpty
      ? _text(zone['city']):_text(zone['name']);
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Activar conductor'),
        content:Text('$name quedará aprobado en $zoneName y podrá conectarse '
          'para recibir solicitudes.'),
        actions:[
          TextButton(
            onPressed:()=>Navigator.pop(dialogContext,false),
            child:const Text('Cancelar')),
          FilledButton(
            onPressed:()=>Navigator.pop(dialogContext,true),
            child:const Text('Activar')),
        ],
      ),
    );
    if(confirmed!=true || !mounted) return;
    setActivationBusy(true);
    try {
      await supabase.rpc('admin_driver_activate',params:{
        'p_driver_id':document['driver_id'],
        'p_zone_id':zone['id'],
        'p_channel':widget.channel,
      });
      if(!mounted) return;
      Navigator.of(detailContext).pop();
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Conductor activado en $zoneName.')));
    } catch(error) {
      setActivationBusy(false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo activar: $error')));
    }
  }

  Future<void> _details(
    Map<String,dynamic> document,
    List<Map<String,dynamic>> zones,
  ) async {
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
    var currentDocument=Map<String,dynamic>.from(document);
    String? selectedZoneId=_text(currentDocument['zone_id']).isEmpty
      ? null:_text(currentDocument['zone_id']);
    var activationBusy=false;
    await showDialog<void>(
      context:context,
      builder:(dialogContext)=>StatefulBuilder(
        builder:(context,setDialogState) {
          final parts=_map(currentDocument['review_parts']);
          final allPhotosApproved=parts.values.whereType<Map>().every((part) {
            final photo=_text(part['path']).isNotEmpty;
            return !photo || _text(part['status'])=='approved';
          });
          final verified=_text(currentDocument['status'])=='verified';
          final alreadyActive=_text(currentDocument['approval_status'])=='approved' &&
            _text(currentDocument['zone_id']).isNotEmpty;
          Map<String,dynamic>? selectedZone;
          for(final zone in zones) {
            if(_text(zone['id'])==selectedZoneId) {
              selectedZone=zone;
              break;
            }
          }
          final canActivate=allPhotosApproved && verified && !alreadyActive &&
            selectedZone!=null && !activationBusy;
          return AlertDialog(
        title:const Text('Revisión individual de identidad'),
        content:SizedBox(width:690,child:SingleChildScrollView(
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Conductor: ${_text(currentDocument['full_name'])}'),
            Text('Carné: ${_text(currentDocument['document_number'])}'),
            Text('Identidad: ${_statusLabel(
              _text(currentDocument['status'])=='verified' ? 'approved'
                : _text(currentDocument['status']))}'),
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
                          onPressed:_busy ? null:() async {
                            final updated=await _reviewSlot(
                              currentDocument,slot,'approved',version);
                            if(updated!=null && dialogContext.mounted) {
                              setDialogState(()=>currentDocument=updated);
                            }
                          },
                          icon:const Icon(Icons.check_circle_outline),
                          label:const Text('Aprobar'),
                        ),
                      if(current!='rejected')
                        OutlinedButton.icon(
                          onPressed:_busy ? null:() async {
                            final updated=await _reviewSlot(
                              currentDocument,slot,'rejected',version);
                            if(updated!=null && dialogContext.mounted) {
                              setDialogState(()=>currentDocument=updated);
                            }
                          },
                          icon:const Icon(Icons.highlight_off),
                          label:const Text('Rechazar'),
                        ),
                      if(current!='pending')
                        OutlinedButton.icon(
                          onPressed:_busy ? null:() async {
                            final updated=await _reviewSlot(
                              currentDocument,slot,'pending',version);
                            if(updated!=null && dialogContext.mounted) {
                              setDialogState(()=>currentDocument=updated);
                            }
                          },
                          icon:const Icon(Icons.restart_alt),
                          label:const Text('Reactivar'),
                        ),
                    ]),
                  ],
                );
              }),
            ],
            const SizedBox(height:12),
            if(!alreadyActive) ...[
              if(_text(currentDocument['zone_id']).isEmpty)
                DropdownButtonFormField<String>(
                  value:selectedZoneId,
                  decoration:const InputDecoration(
                    border:OutlineInputBorder(),
                    labelText:'Zona del conductor',
                  ),
                  items:zones.map((zone)=>DropdownMenuItem<String>(
                    value:_text(zone['id']),
                    child:Text(_text(zone['name']).isEmpty
                      ? _text(zone['city']):_text(zone['name'])),
                  )).toList(),
                  onChanged:_busy ? null:(value)=>setDialogState(
                    ()=>selectedZoneId=value),
                ),
              if(!allPhotosApproved || !verified)
                const Padding(
                  padding:EdgeInsets.only(top:8),
                  child:Text('Aprueba todas las fotografías para activar.')),
              const SizedBox(height:10),
              FilledButton.icon(
                onPressed:canActivate ? ()=>_activateDriver(
                  currentDocument,selectedZone!,dialogContext,
                  (busy)=>setDialogState(()=>activationBusy=busy)) : null,
                icon:const Icon(Icons.verified_user_rounded),
                label:Text(activationBusy ? 'Activando…':'Activar conductor'),
              ),
            ] else
              Chip(label:Text('Activo · ${_text(currentDocument['zone_name'])}')),
            const Text('La aprobación del conductor y del vehículo '
              'es independiente de estas fotografías.'),
          ]),
        )),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),
            child:const Text('Cerrar')),
        ],
      );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String,dynamic>>(
      future:_future,
      builder:(context,snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return Card(child:Padding(
            padding:const EdgeInsets.all(14),
            child:Column(children:[
              const Text('No se pudieron consultar los documentos.'),
              TextButton(onPressed:_reload,child:const Text('Reintentar')),
            ])));
          return const LinearProgressIndicator();
        }
        final data=snapshot.data!;
        final docs=_list(data['documents']);
        final zones=_list(data['zones']);
        return Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Text('Verificación manual de identidad',
              style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
            const SizedBox(height:8),
            const Text('Revisa cada fotografía del carné y la selfie '
              'por separado. Puedes reactivar rechazos por error.'),
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
                  child:Text('Aún no hay documentos para revisar.')),
              for (final doc in docs.take(40)) ListTile(
                contentPadding:EdgeInsets.zero,
                leading:Icon(doc['status']=='pending'
                  ? Icons.hourglass_empty:Icons.verified_user_outlined),
                title:Text(_text(doc['full_name']).isNotEmpty
                  ? _text(doc['full_name']):'Conductor'),
                subtitle:Text('Carné ${_text(doc['document_number'])} · '
                  '${_statusLabel(_text(doc['status']))}'),
                trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                  if(_text(doc['approval_status'])=='approved' &&
                      _text(doc['zone_id']).isNotEmpty)
                    Chip(label:Text('Activo · ${_text(doc['zone_name'])}')),
                  const Icon(Icons.chevron_right),
                ]),
                onTap:()=>_details(doc,zones),
              ),
            ]),
          ),
        );
      },
    );
  }
}
