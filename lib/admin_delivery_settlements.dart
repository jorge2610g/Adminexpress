import 'package:flutter/material.dart';
import 'core/supabase_client.dart';

class AdminDeliverySettlementsPage extends StatefulWidget {
 const AdminDeliverySettlementsPage({super.key,required this.channel,
  required this.zoneId});
 final String channel; final String? zoneId;
 @override State<AdminDeliverySettlementsPage> createState()=>
   _AdminDeliverySettlementsPageState();
}
class _AdminDeliverySettlementsPageState
    extends State<AdminDeliverySettlementsPage> {
 late Future<List<Map<String,dynamic>>> future;
 bool busy=false;
 @override void initState(){super.initState();_reload();}
 @override void didUpdateWidget(covariant AdminDeliverySettlementsPage old){
   super.didUpdateWidget(old);
   if(old.zoneId!=widget.zoneId||old.channel!=widget.channel)_reload();
 }
 void _reload(){
   future=() async {
     if(widget.zoneId==null)return <Map<String,dynamic>>[];
     final raw=await supabase.rpc('admin_marketplace_weekly_cuts',params:{
       'p_zone_id':widget.zoneId,'p_channel':widget.channel,
     });
     return raw is List?raw.whereType<Map>()
       .map((e)=>Map<String,dynamic>.from(e)).toList():[];
   }();
 }
 String _money(Object? n,String code){
   final d=n is num?n.toDouble():double.tryParse(n.toString())??0;
   final display=code=='CLP'?d.round().toString().replaceAllMapped(
     RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>'.'):d.toStringAsFixed(2);
   return (code=='CLP'?'CLP ':code=='BOB'?'Bs ':'$code ')+display;
 }
 String _status(String raw)=>switch(raw){
  'paid'=>'Pagado','under_review'=>'En revisión',
  'rejected'=>'Rechazado',_=>'Pendiente'
 };
 Future<void> _review(Map<String,dynamic> row,bool approve) async {
   if(busy)return;
   final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
     title:Text(approve?'Confirmar dinero recibido':'Rechazar aviso'),
     content:Text(approve?'¿Verificaste en la cuenta de Express que se recibió '
       'el pago de ${_money(row['amount'],row['currency_code'].toString())} '
       'del restaurante ${row['merchant_name']}? '
       'Esto cerrará el saldo semanal y quedará auditado.':
       'El restaurante podrá corregir y volver a informar el pago.'),
     actions:[
       TextButton(onPressed:()=>Navigator.pop(context,false),
         child:const Text('Cancelar')),
       FilledButton(onPressed:()=>Navigator.pop(context,true),
         child:Text(approve?'Aprobar pago':'Rechazar aviso')),
     ],
   ));
   if(yes!=true||!mounted)return;
   setState(()=>busy=true);
   try{
     await supabase.rpc('admin_marketplace_review_weekly_cut',params:{
       'p_cut_id':row['id'],'p_approve':approve,
     });
     if(mounted){
       setState(_reload);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content:Text('Liquidación actualizada y registrada.')));
     }
   }catch(e){
     if(mounted)ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content:Text('No se pudo revisar la liquidación: $e')));
   }finally{if(mounted)setState(()=>busy=false);}
 }
 Widget _receipt(String path)=>FutureBuilder<String>(
   future:supabase.storage.from('marketplace-weekly-receipts')
     .createSignedUrl(path,600),
   builder:(context,snapshot){
     if(snapshot.connectionState!=ConnectionState.done)
       return const LinearProgressIndicator();
     if(!snapshot.hasData)return const Text('Comprobante no disponible');
     return ConstrainedBox(constraints:const BoxConstraints(
       maxWidth:300,maxHeight:260),
       child:Image.network(snapshot.data!,fit:BoxFit.contain,
         errorBuilder:(_,__,___)=>const Text('No se pudo abrir la imagen.')));
   });
 @override Widget build(BuildContext context){
   if(widget.zoneId==null)return const Center(
     child:Text('Selecciona ciudad y zona para ver liquidaciones.'));
   return FutureBuilder<List<Map<String,dynamic>>>(
     future:future,builder:(context,snapshot){
       if(snapshot.connectionState!=ConnectionState.done)
         return const Center(child:CircularProgressIndicator());
       if(snapshot.hasError)return Center(child:Column(
         mainAxisSize:MainAxisSize.min,children:[
         Text('Error leyendo cortes: ${snapshot.error}'),
         FilledButton(onPressed:()=>setState(_reload),
           child:const Text('Reintentar'))]));
       final cuts=snapshot.data??<Map<String,dynamic>>[];
       final pending=cuts.where((r)=>r['status']!='paid').toList();
       return ListView(padding:const EdgeInsets.all(20),children:[
         Row(children:[
           const Icon(Icons.receipt_long_rounded,
             color:Color(0xFF2563EB),size:32),
           const SizedBox(width:12),
           Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
             children:[
             Text('Liquidaciones de restaurantes',
               style:Theme.of(context).textTheme.headlineSmall),
             Text('Cortes semanales · ${widget.channel.toUpperCase()} · '
               'desglose privado de Express'),
           ])),
           IconButton(onPressed:()=>setState(_reload),
             icon:const Icon(Icons.refresh)),
         ]),
         const SizedBox(height:13),
         Card(child:Padding(padding:const EdgeInsets.all(15),
           child:Row(children:[
             Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
               children:[
               Text('Cortes por cobrar',
                 style:Theme.of(context).textTheme.titleMedium),
               Text('${pending.length} cortes pendientes o en revisión'),
             ])),
             const Icon(Icons.account_balance_wallet_outlined,size:32),
           ]))),
         const SizedBox(height:10),
         if(cuts.isEmpty)const Card(child:Padding(
           padding:EdgeInsets.all(24),child:Text(
             'No hay cortes cerrados. Se generan el lunes al finalizar la semana '
             'con entregas en que el restaurante recibió el dinero.'))),
         for(final r in cuts)Card(child:Padding(
           padding:const EdgeInsets.all(16),
           child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
             Row(children:[
               Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                 children:[
                 Text(r['merchant_name']?.toString()??'Restaurante',
                   style:Theme.of(context).textTheme.titleMedium),
                 Text('${r['week_start']} al ${r['week_end']}'),
               ])),
               Chip(label:Text(_status(r['status']?.toString()??''))),
             ]),
             const SizedBox(height:8),
             Text('Total Servicio Express: ${_money(r['amount'],r['currency_code'].toString())}',
               style:const TextStyle(fontWeight:FontWeight.w800)),
             const SizedBox(height:6),
             Text('Cargo de servicio: ${_money(r['service_fee'],r['currency_code'].toString())}'),
             Text('Diferencia de envío (privada): ${_money(r['delivery_spread'],r['currency_code'].toString())}'),
             const Divider(),
             if((r['reference']?.toString()??'').isNotEmpty)
               Text('Referencia informada: ${r['reference']}'),
             if((r['receipt_path']?.toString()??'').isNotEmpty)...[
               const SizedBox(height:8),
               _receipt(r['receipt_path'].toString()),
             ],
             if(r['status']=='under_review')...[
               const SizedBox(height:8),
               Wrap(spacing:9,children:[
                 OutlinedButton.icon(onPressed:busy?null:()=>_review(r,false),
                   icon:const Icon(Icons.close),
                   label:const Text('Rechazar aviso')),
                 FilledButton.icon(onPressed:busy?null:()=>_review(r,true),
                   icon:const Icon(Icons.check),
                   label:const Text('Confirmar recibido')),
               ]),
             ],
           ]))),
       ]);
     });
 }
}
