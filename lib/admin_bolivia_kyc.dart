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
      supabase.rpc('admin_driver_kyc_bolivia_settings',
          params: {'p_channel':widget.channel}),
      supabase.rpc('admin_driver_kyc_bolivia_manual_list',
          params: {'p_channel':widget.channel,'p_limit':150}),
    ]);
    return {'settings':_map(results[0]),'documents':_list(results[1])};
  }

  void _reload() {
    if (mounted) setState(() { _future = _load(); });
  }

  Future<void> _setMethod(String method) async {
    if (_busy) return;
    final previous = _map((await _future)['settings'])['preferred_method'];
    if (previous == method) return;
    final approved = await showDialog<bool>(
      context:context,
      builder:(context)=>AlertDialog(
        title:const Text('Cambiar método de verificación'),
        content:Text('Bolivia · ${widget.channel == 'preview' ? 'Pruebas' : 'Producción'}\n\n'
          'Nuevo método: ${_label(method)}.\n\n'
          'El límite de Didit seguirá siendo 30 sesiones por mes. '
          'Al agotarse, Express utilizará el sistema manual. '
          'No afecta Chile ni las verificaciones en curso.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),
            child:const Text('Guardar método')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy=true);
    try {
      await supabase.rpc('admin_driver_kyc_bolivia_set_method',params:{
        'p_channel':widget.channel,'p_method':method,
      });
      if (mounted) _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo guardar el método: $e')));
    } finally {
      if (mounted) setState(() => _busy=false);
    }
  }

  String _label(String mode) => switch (mode) {
    'didit' => 'Didit (máximo 30 mensuales)',
    'manual' => 'Solo verificación manual Express',
    _ => 'Automático: Didit → manual después de 30',
  };

  Future<void> _review(Map<String,dynamic> doc,String decision) async {
    final reasonController = TextEditingController();
    final isApprove = decision == 'approve';
    final ok = await showDialog<bool>(
      context:context,
      builder:(context)=>AlertDialog(
        title:Text(isApprove ? 'Aprobar identidad' :
            decision == 'retry' ? 'Solicitar nueva captura' : 'Rechazar documento'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(isApprove
            ? 'Aprobarás la identidad, pero el conductor seguirá pendiente '
              'de aprobación de vehículo y cuenta.'
            : 'El conductor podrá repetir la fotografía o contactar a soporte.'),
          if (!isApprove) ...[
            const SizedBox(height:12),
            TextField(controller:reasonController,maxLines:2,
              decoration:const InputDecoration(
                border:OutlineInputBorder(),labelText:'Motivo (obligatorio)')),
          ],
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),
            child:const Text('Confirmar')),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true || !mounted) return;
    if (!isApprove && reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Indica un motivo de al menos 5 caracteres.')));
      return;
    }
    setState(()=>_busy=true);
    try {
      await supabase.rpc('admin_driver_kyc_bolivia_manual_decide',params:{
        'p_document_id':doc['id'],'p_decision':decision,
        'p_reason':isApprove ? null : reason,
        'p_channel':widget.channel,
      });
      if (mounted) { Navigator.of(context).pop(); _reload(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo actualizar la revisión: $e')));
    } finally {
      if (mounted) setState(()=>_busy=false);
    }
  }

  Future<void> _details(Map<String,dynamic> document) async {
    // Storage RLS allows only the owner and authorised administrators to
    // generate short-lived signed links. Never store these URLs in the DB.
    final signed = <String,String>{};
    for (final field in <String>[
      'front_object_path','back_object_path','selfie_object_path'
    ]) {
      final objectPath = _text(document[field]);
      if (objectPath.isEmpty) continue;
      try {
        signed[field] = await supabase.storage
            .from('driver-onboarding').createSignedUrl(objectPath,300);
      } catch (_) { /* The review must not expose unavailable objects. */ }
    }
    if (!mounted) return;
    await showDialog<void>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Documento · revisión manual Bolivia'),
        content:SizedBox(width:670,child:SingleChildScrollView(
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Conductor: ${_text(document['full_name'])}'),
            Text('Documento: ${_text(document['document_number'])}'),
            Text('Estado: ${_text(document['status'])}'),
            if (_text(document['rejection_reason']).isNotEmpty)
              Text('Observación: ${document['rejection_reason']}'),
            for (final item in <(String,String)>[
              ('Anverso','front_object_path'),
              ('Reverso','back_object_path'),
              ('Fotografía facial','selfie_object_path'),
            ]) ...[
              const SizedBox(height:12),
              Text(item.$1,style:const TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              if (signed[item.$2] != null)
                ClipRRect(
                  borderRadius:BorderRadius.circular(10),
                  child:Image.network(signed[item.$2]!,
                    fit:BoxFit.contain,height:190,width:330,
                    errorBuilder:(_,__,___)=>const Text(
                      'No se pudo abrir la imagen privada.')),
                )
              else const Text('Imagen no disponible · no aprobar hasta comprobar.'),
            ],
            const SizedBox(height:12),
            const Text('Las imágenes se conservan en almacenamiento privado. '
              'La selfie es evidencia para revisión humana; no acredita '
              'automáticamente prueba de vida.'),
          ]),
        )),
        actions:[
          TextButton(onPressed:()=>Navigator.of(dialogContext).pop(),
            child:const Text('Cerrar')),
          if (_text(document['status'])=='pending') ...[
            OutlinedButton(onPressed:_busy?null:()=>_review(document,'retry'),
              child:const Text('Repetir captura')),
            OutlinedButton(onPressed:_busy?null:()=>_review(document,'reject'),
              child:const Text('Rechazar')),
            FilledButton(onPressed:_busy||signed.length!=3
                ? null:()=>_review(document,'approve'),
              child:const Text('Aprobar identidad')),
          ],
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
        final pending=docs.where((d)=>d['status']=='pending').toList();
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
                  'Identidades manuales pendientes: ${pending.length}',
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
