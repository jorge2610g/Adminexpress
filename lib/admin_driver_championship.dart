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
    _id=null;_service='*';_state='draft';
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
      _first.text=item['first_prize']?.toString()??'';
      _second.text=item['second_prize']?.toString()??'';
      _third.text=item['third_prize']?.toString()??'';
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
    setState(()=>_saving=true);
    try {
      // Local calendar dates are stored as UTC instants; the end date is
      // inclusive on screen, exclusive at the beginning of the next day.
      final start=DateTime.utc(_starts.year,_starts.month,_starts.day);
      final end=DateTime.utc(_ends.year,_ends.month,_ends.day)
        .add(const Duration(days:1));
      final response=await supabase.rpc('admin_driver_championship_save',params:{
        'p_id':_id,'p_zone_id':widget.zoneId,'p_channel':widget.channel,
        'p_service_key':_service,'p_title':_title.text.trim(),
        'p_starts_at':start.toIso8601String(),
        'p_ends_at':end.toIso8601String(),'p_state':_state,
        'p_first_prize':_first.text.trim(),
        'p_second_prize':_second.text.trim(),
        'p_third_prize':_third.text.trim(),
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
                    ' · '+(row['state']?.toString()??'draft')),
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
              const SizedBox(height:9),
              _input('🥇 Primer lugar (ej. $50.000 + bono)',_first),
              const SizedBox(height:9),
              _input('🥈 Segundo lugar',_second),
              const SizedBox(height:9),
              _input('🥉 Tercer lugar',_third),
              const SizedBox(height:13),
              _input('Reglas y condiciones',_rules,maxLines:3),
              const SizedBox(height:10),
              const Text('El ranking se calcula desde viajes reales completados. '
                'No se generan pagos automáticos y la clasificación solo es visible '
                'a conductores aprobados de la misma zona y entorno.',
                style:TextStyle(color:Color(0xFF667085),fontSize:12)),
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
