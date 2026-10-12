import 'package:flutter/material.dart';
import 'core/supabase_client.dart';

/// Admin championships by assigned city and account-bound runtime.
/// Writes are limited to superadmins in the Postgres RPC.
class AdminDriverChampionshipPage extends StatefulWidget {
  const AdminDriverChampionshipPage({
    super.key,required this.channel,required this.zoneId,this.countryCode});
  final String channel;
  final String? zoneId;
  final String? countryCode;
  @override
  State<AdminDriverChampionshipPage> createState() =>
    _AdminDriverChampionshipPageState();
}

class _AdminDriverChampionshipPageState
    extends State<AdminDriverChampionshipPage> {
  final _title=TextEditingController(text:'Campeonato Express');
  final _first=TextEditingController();
  final _second=TextEditingController();
  final _third=TextEditingController();
  final _rules=TextEditingController(text:
    'Solo cuentan viajes completados y válidos en la zona y servicio. '
    'Los viajes cancelados no suman. Los premios se entregan después de validar los resultados.');
  late Future<List<Map<String,dynamic>>> _future;
  String? _id;
  String _service='*',_state='draft';
  DateTime _starts=DateTime.now();
  DateTime _ends=DateTime.now().add(const Duration(days:14));
  bool _saving=false;
  bool _autoCredit=true;

  @override
  void initState(){super.initState();_reload();}
  @override
  void didUpdateWidget(covariant AdminDriverChampionshipPage oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.channel!=widget.channel||oldWidget.zoneId!=widget.zoneId){
      _newRecord();_reload();
    }
  }
  @override
  void dispose(){
    _title.dispose();_first.dispose();_second.dispose();
    _third.dispose();_rules.dispose();super.dispose();
  }
  void _reload(){
    _future=()async{
      if(widget.zoneId==null) return <Map<String,dynamic>>[];
      final raw=await supabase.rpc('admin_driver_championship_list',params:{
        'p_zone_id':widget.zoneId,'p_channel':widget.channel});
      return raw is List?raw.whereType<Map>()
        .map((x)=>Map<String,dynamic>.from(x)).toList()
        :<Map<String,dynamic>>[];
    }();
  }
  void _newRecord(){
    _id=null;_service='*';_state='draft';_autoCredit=true;
    _starts=DateTime.now();_ends=DateTime.now().add(const Duration(days:14));
    _title.text='Campeonato Express';_first.clear();_second.clear();
    _third.clear();_rules.text='Solo viajes completados y válidos. '
      'Los viajes cancelados no suman. Premios sujetos a revisión.';
    if(mounted)setState((){});
  }
  void _open(Map<String,dynamic> item){
    setState((){
      _id=item['id']?.toString();
      _title.text=item['title']?.toString()??'';
      _service=item['service_key']?.toString()??'*';
      _state=item['state']?.toString()??'draft';
      _starts=DateTime.tryParse(item['starts_at']?.toString()??'')
        ?.toLocal()??DateTime.now();
      _ends=DateTime.tryParse(item['ends_at']?.toString()??'')
        ?.toLocal()??DateTime.now().add(const Duration(days:14));
      _first.text=item['first_prize_amount']?.toString()??'0';
      _second.text=item['second_prize_amount']?.toString()??'0';
      _third.text=item['third_prize_amount']?.toString()??'0';
      _autoCredit=item['auto_credit_enabled']==true;
      _rules.text=item['rules']?.toString()??'';
    });
  }
  String _format(DateTime d)=>d.day.toString().padLeft(2,'0')+'/'
    +d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
  Future<void> _pick(bool beginning) async {
    final initial=beginning?_starts:_ends;
    final chosen=await showDatePicker(context:context,
      initialDate:initial,firstDate:DateTime(2025),
      lastDate:DateTime(2035),helpText:beginning?'Fecha de inicio':'Fecha de fin');
    if(chosen==null||!mounted)return;
    setState((){
      if(beginning) _starts=chosen;
      else _ends=chosen;
    });
  }
  Future<void> _save() async {
    if(_saving || widget.zoneId==null)return;
    if(_title.text.trim().length<4||_ends.isBefore(_starts)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Escribe un nombre y fechas válidas.')));return;
    }
    final first=num.tryParse(_first.text.trim());
    final second=num.tryParse(_second.text.trim());
    final third=num.tryParse(_third.text.trim());
    if(first==null||second==null||third==null||first<0||second<0||third<0
      ||(_autoCredit&&(first<=0||second<=0||third<=0))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Introduce tres importes válidos. Para abonar premios automáticamente deben ser mayores que cero.')));
      return;
    }
    setState(()=>_saving=true);
    try {
      // Local calendar dates are stored as UTC instants; the end date is
      // inclusive on screen, exclusive at the beginning of the next day.
      final start=DateTime.utc(_starts.year,_starts.month,_starts.day);
      final end=DateTime.utc(_ends.year,_ends.month,_ends.day)
        .add(const Duration(days:1));
      final response=await supabase.rpc('admin_driver_championship_save_v2',params:{
        'p_id':_id,'p_zone_id':widget.zoneId,'p_channel':widget.channel,
        'p_service_key':_service,'p_title':_title.text.trim(),
        'p_starts_at':start.toIso8601String(),
        'p_ends_at':end.toIso8601String(),'p_state':_state,
        'p_first_amount':first,
        'p_second_amount':second,
        'p_third_amount':third,
        'p_auto_credit':_autoCredit,
        'p_rules':_rules.text.trim(),
      });
      if(!mounted)return;
      _id=(response is Map?response['id']:null)?.toString();
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Campeonato guardado correctamente.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('No se pudo guardar: '+e.toString())));
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }
  Widget _input(String label,TextEditingController controller,
    {int maxLines=1})=>TextField(controller:controller,maxLines:maxLines,
      decoration:InputDecoration(labelText:label),
    );
  Widget _dateTile(String title,DateTime date,bool beginning)=>OutlinedButton.icon(
    onPressed:()=>_pick(beginning),
    icon:const Icon(Icons.calendar_month_outlined),
    label:Text(title+': '+_format(date)));
  @override
  Widget build(BuildContext context){
    if(widget.zoneId==null)
      return const Center(child:Text('Selecciona una ciudad para continuar.'));
    return FutureBuilder<List<Map<String,dynamic>>>(
      future:_future,
      builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)
          return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)
          return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text('No se pudieron cargar los campeonatos: '+snapshot.error.toString()),
            TextButton(onPressed:()=>setState(_reload),
              child:const Text('Reintentar')),
          ]));
        final records=snapshot.data??<Map<String,dynamic>>[];
        return ListView(padding:const EdgeInsets.all(22),children:[
          Row(children:[
            const Icon(Icons.emoji_events_outlined,color:Color(0xFF2563EB),size:30),
            const SizedBox(width:12),
            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Campeonato Express',style:TextStyle(
                fontSize:21,fontWeight:FontWeight.w900)),
              Text('Ranking de viajes por ciudad y servicio, con premios configurables',
                style:TextStyle(fontSize:12,color:Color(0xFF667085))),
            ])),
            FilledButton.icon(onPressed:_newRecord,
              icon:const Icon(Icons.add),label:const Text('Nuevo')),
          ]),
          const SizedBox(height:16),
          Card(child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Campeonatos de esta zona · '+(widget.channel=='preview'
                ?'ENTORNO DE PRUEBA':'PRODUCCIÓN'),
                style:const TextStyle(fontWeight:FontWeight.w800)),
              const SizedBox(height:10),
              if(records.isEmpty)const Text('Todavía no se ha creado un campeonato.'),
              for(final row in records)
                ListTile(
                  leading:const Icon(Icons.emoji_events_outlined),
                  title:Text(row['title']?.toString()??''),
                  subtitle:Text(
                    (row['service_key']?.toString()??'*')+
                    ' · '+(row['state']?.toString()??'draft')+
                    ' · '+(row['settlement_status']?.toString()=='credited'
                      ?'Premios acreditados'
                      :row['auto_credit_enabled']==true
                        ?'Abono programado':'Sin abono automático')),
                  selected:_id==row['id']?.toString(),
                  trailing:const Icon(Icons.edit_outlined),
                  onTap:()=>_open(row),
                ),
            ]))),
          const SizedBox(height:15),
          Card(child:Padding(padding:const EdgeInsets.all(18),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_id==null?'Crear campeonato':'Editar campeonato',
                style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
              const SizedBox(height:12),
              _input('Nombre del campeonato',_title),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(
                initialValue:_service,
                decoration:const InputDecoration(labelText:'Servicio'),
                items:const [
                  DropdownMenuItem(value:'*',child:Text('Todos los servicios')),
                  DropdownMenuItem(value:'economy',child:Text('Express')),
                  DropdownMenuItem(value:'motorcycle',child:Text('Moto')),
                  DropdownMenuItem(value:'comfort',child:Text('Comfort')),
                  DropdownMenuItem(value:'xl',child:Text('XL')),
                ],onChanged:(v)=>setState(()=>_service=v??'*')),
              const SizedBox(height:12),
              Wrap(spacing:12,runSpacing:10,children:[
                _dateTile('Inicio',_starts,true),
                _dateTile('Fin',_ends,false),
              ]),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(
                initialValue:_state,
                decoration:const InputDecoration(labelText:'Estado'),
                items:const [
                  DropdownMenuItem(value:'draft',child:Text('Borrador · no visible')),
                  DropdownMenuItem(value:'active',child:Text('Activo · visible durante las fechas')),
                  DropdownMenuItem(value:'closed',child:Text('Cerrado · no visible')),
                ],onChanged:(v)=>setState(()=>_state=v??'draft')),
              const SizedBox(height:17),
              const Text('Premios para los 3 ganadores',
                style:TextStyle(fontWeight:FontWeight.w900)),
              const SizedBox(height:5),
              Text('Importes sin separador de miles · ${widget.countryCode=='CL'?'CLP':'BOB'}',
                style:const TextStyle(fontSize:12,color:Color(0xFF667085))),
              const SizedBox(height:9),
              _input('🥇 Primer lugar (ej. 50000)',_first),
              const SizedBox(height:9),
              _input('🥈 Segundo lugar (ej. 30000)',_second),
              const SizedBox(height:9),
              _input('🥉 Tercer lugar (ej. 15000)',_third),
              const SizedBox(height:12),
              SwitchListTile(
                contentPadding:EdgeInsets.zero,
                value:_autoCredit,
                onChanged:(value)=>setState(()=>_autoCredit=value),
                title:const Text('Abonar automáticamente los premios a la billetera',
                  style:TextStyle(fontWeight:FontWeight.w800)),
                subtitle:const Text('Al finalizar el plazo, solo los tres ganadores con viajes válidos recibirán su premio una vez. El saldo podrá usarse en suscripciones.'),
              ),
              const SizedBox(height:13),
              _input('Reglas y condiciones',_rules,maxLines:3),
              const SizedBox(height:10),
              const Text('Los importes se acreditan en la moneda y billetera de la ciudad. '
                'Las reglas y los premios quedan bloqueados una vez iniciado el campeonato. '
                'Los campeonatos antiguos de Preview con premios ficticios no acreditan saldo.',
                style:TextStyle(color:Color(0xFF667085),fontSize:12)),
              if(_id!=null&&_state=='closed') ...[
                const SizedBox(height:12),
                FutureBuilder<dynamic>(
                  future:supabase.rpc('admin_driver_championship_rewards',
                    params:{'p_id':_id,'p_zone_id':widget.zoneId,
                      'p_channel':widget.channel}),
                  builder:(context,snap){
                    if(snap.connectionState!=ConnectionState.done)
                      return const LinearProgressIndicator();
                    if(snap.hasError)return Text('Error consultando premios: ${snap.error}');
                    final data=snap.data;
                    final rewards=data is List?data:<dynamic>[];
                    if(rewards.isEmpty)return const Text('Sin premios acreditados.');
                    return Column(crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        const Text('Premios acreditados — historial',
                          style:TextStyle(fontWeight:FontWeight.w900)),
                        for(final prize in rewards)
                          if(prize is Map)
                            ListTile(
                              leading:const Icon(Icons.account_balance_wallet_outlined),
                              title:Text('Puesto ${prize['position']} · ${prize['driver_name']}'),
                              subtitle:Text('${prize['rides']} viajes · Comprobante ${prize['receipt_id']}'),
                              trailing:Text('${prize['currency']} ${prize['amount']}'),
                            ),
                      ]);
                  }),
              ],
              const SizedBox(height:15),
              FilledButton.icon(
                onPressed:_saving?null:_save,
                icon:const Icon(Icons.save_outlined),
                label:Text(_saving?'Guardando…':'Guardar campeonato')),
            ]))),
        ]);
      },
    );
  }
}
