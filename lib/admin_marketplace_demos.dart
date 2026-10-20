import 'package:flutter/material.dart';
import 'core/supabase_client.dart';
import 'core/admin_dropdown_field.dart';

/// Scoped, idempotent demo restaurants for Preview or hidden Production QA.
/// Production demos never enter the public customer catalogue.
class AdminMarketplaceDemoSection extends StatefulWidget {
  const AdminMarketplaceDemoSection({
    super.key,required this.zoneId,required this.channel,
    required this.onOpenProducts,
  });
  final String zoneId,channel;
  final void Function(Map<String,dynamic>) onOpenProducts;
  @override
  State<AdminMarketplaceDemoSection> createState()=>_AdminMarketplaceDemoSectionState();
}

class _AdminMarketplaceDemoSectionState extends State<AdminMarketplaceDemoSection> {
  late Future<List<Map<String,dynamic>>> _future;
  bool _busy=false;
  @override
  void initState(){super.initState();_refresh();}
  @override
  void didUpdateWidget(covariant AdminMarketplaceDemoSection old){
    super.didUpdateWidget(old);
    if(old.zoneId!=widget.zoneId||old.channel!=widget.channel)_refresh();
  }
  void _refresh(){
    _future=()async{
      final data=await supabase.rpc('admin_marketplace_list_demo_restaurants',
        params:{'p_zone_id':widget.zoneId,'p_channel':widget.channel});
      if(data is! List)return <Map<String,dynamic>>[];
      return data.whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
    }();
  }
  void _message(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }
  Future<void> _createDemo()async{
    if(_busy)return;
    var selected='all';
    final confirmed=await showDialog<bool>(context:context,
      builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>
        AlertDialog(
          title:const Text('Crear restaurante demo'),
          content:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:460),
            child:Column(mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Ciudad seleccionada · ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}',
                style:const TextStyle(fontWeight:FontWeight.w600)),
              const SizedBox(height:12),
              AdminDropdownField<String>(
                initialValue:selected,
                decoration:const InputDecoration(labelText:'Plantilla con productos'),
                items:const [
                  DropdownMenuItem(value:'all',
                    child:Text('Paquete completo · 3 restaurantes, 18 productos')),
                  DropdownMenuItem(value:'burgers',
                    child:Text('Hamburguesería · 6 productos')),
                  DropdownMenuItem(value:'pizza',
                    child:Text('Pizzería · 6 productos')),
                  DropdownMenuItem(value:'home_cooking',
                    child:Text('Almuerzos caseros · 6 productos')),
                ],
                onChanged:(v)=>setLocal(()=>selected=v??'burgers'),
              ),
              const SizedBox(height:14),
              Text(widget.channel=='production'
                ? 'Seguridad: el restaurante demo de Producción quedará oculto '
                  'para clientes y bloqueado para pedidos reales, aun si Delivery se habilita.'
                : 'Este negocio demo solo se verá en Prueba. '
                  'Se crean menú, productos, extras, precios locales y horarios.'),
              const SizedBox(height:8),
              const Text('Repetir la creación no duplicará productos ni borrará cambios.',
                style:TextStyle(fontSize:12)),
            ])),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialogContext,false),
              child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),
              child:const Text('Crear demo')),
          ],
        )));
    if(confirmed!=true||!mounted)return;
    setState(()=>_busy=true);
    try{
      final templates=selected=='all'
        ? <String>['burgers','pizza','home_cooking'] : <String>[selected];
      var created=0;
      for(final template in templates){
        final result=await supabase.rpc('admin_marketplace_create_demo_restaurant',
          params:{
            'p_zone_id':widget.zoneId,'p_channel':widget.channel,
            'p_template_key':template,
          });
        final map=result is Map?Map<String,dynamic>.from(result):<String,dynamic>{};
        if(map['created']==true)created++;
      }
      _message('Se prepararon ${templates.length} demos. Nuevos: $created. '
        'Cada uno tiene 6 productos y propietario de prueba asignado.');
      if(mounted)setState(_refresh);
    }catch(e){_message('No se pudo generar el restaurante demo: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _assign(Map<String,dynamic> row)async{
    final email=TextEditingController();
    var role='owner';
    final accepted=await showDialog<bool>(context:context,
      builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>
        AlertDialog(
          title:const Text('Asignar usuario al restaurante'),
          content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),
            child:Column(mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(row['name']?.toString()??'Restaurante demo'),
              const SizedBox(height:12),
              TextField(controller:email,
                keyboardType:TextInputType.emailAddress,
                decoration:const InputDecoration(labelText:'Correo registrado en Express')),
              const SizedBox(height:12),
              AdminDropdownField<String>(
                initialValue:role,
                decoration:const InputDecoration(labelText:'Permiso'),
                items:const [
                  DropdownMenuItem(value:'owner',child:Text('Propietario')),
                  DropdownMenuItem(value:'manager',child:Text('Encargado')),
                  DropdownMenuItem(value:'staff',child:Text('Empleado')),
                ],
                onChanged:(v)=>setLocal(()=>role=v??'owner'),
              ),
              const SizedBox(height:8),
              const Text('La cuenta debe estar registrada y pertenecer al mismo entorno. '
                'Luego podrá ingresar al portal web de restaurantes.',
                style:TextStyle(fontSize:12)),
            ])),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialogContext,false),
              child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),
              child:const Text('Asignar usuario')),
          ],
        )));
    final value=email.text.trim();
    email.dispose();
    if(accepted!=true||!mounted)return;
    if(!value.contains('@')){_message('Correo inválido.');return;}
    setState(()=>_busy=true);
    try{
      await supabase.rpc('admin_marketplace_assign_demo_user',params:{
        'p_merchant_id':row['merchant_id'],'p_channel':widget.channel,
        'p_email':value,'p_role':role,
      });
      _message('Usuario asignado. Ya puede ingresar al portal del restaurante.');
      if(mounted)setState(_refresh);
    }catch(e){_message('No se pudo asignar el usuario: $e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Card(
    margin:EdgeInsets.zero,
    child:Padding(padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Wrap(spacing:14,runSpacing:10,
          crossAxisAlignment:WrapCrossAlignment.center,children:[
            const Icon(Icons.science_outlined,color:Color(0xFF2563EB),size:29),
            const Text('Restaurantes demo',
              style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
            Chip(label:Text(widget.channel.toUpperCase())),
            FilledButton.icon(
              onPressed:_busy?null:_createDemo,
              icon:const Icon(Icons.add_circle_outline),
              label:const Text('Crear restaurante demo')),
          ]),
        const SizedBox(height:7),
        Text(widget.channel=='production'
          ? 'Demos privados de Producción: no aparecen a clientes ni aceptan pedidos reales.'
          : 'Negocios demo de Prueba, separados de los negocios reales.',
          style:const TextStyle(fontSize:12,color:Color(0xFF64748B))),
        const SizedBox(height:14),
        FutureBuilder<List<Map<String,dynamic>>>(future:_future,
          builder:(context,snapshot){
            if(snapshot.connectionState!=ConnectionState.done)
              return const Center(child:Padding(
                padding:EdgeInsets.all(12),child:CircularProgressIndicator()));
            if(snapshot.hasError)return Row(children:[
              const Expanded(child:Text('No se pudieron cargar los demos.')),
              TextButton(onPressed:()=>setState(_refresh),
                child:const Text('Reintentar')),
            ]);
            final rows=snapshot.data??<Map<String,dynamic>>[];
            if(rows.isEmpty)return const Padding(
              padding:EdgeInsets.symmetric(vertical:10),
              child:Text('Todavía no hay restaurantes demo en esta zona y entorno.'));
            return Column(children:[
              for(final r in rows)Padding(
                padding:const EdgeInsets.only(bottom:9),
                child:ListTile(
                  contentPadding:const EdgeInsets.all(10),
                  tileColor:Theme.of(context).colorScheme.surfaceContainerLow,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                  leading:const CircleAvatar(child:Icon(Icons.restaurant)),
                  title:Text(r['name']?.toString()??'Demo'),
                  subtitle:Text(
                    '${r['product_count']??0} productos · '
                    '${r['merchant_users']??0} usuarios · '
                    '${widget.channel=='production'?'Oculto a clientes':'Solo en Prueba'}'),
                  trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                    IconButton(
                      tooltip:'Ver productos',
                      onPressed:()=>widget.onOpenProducts({
                        'id':r['merchant_id'],'name':r['name'],
                        'preview_visible':r['preview_visible'],
                        'production_visible':r['production_visible'],
                      }),
                      icon:const Icon(Icons.inventory_2_outlined)),
                    IconButton(
                      tooltip:'Asignar usuario',
                      onPressed:_busy?null:()=>_assign(r),
                      icon:const Icon(Icons.person_add_alt_1_outlined)),
                  ]),
                ),
              ),
            ]);
          }),
      ])));
}
