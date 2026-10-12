import 'package:flutter/material.dart';
import '../models/trip_content_settings.dart';

class TripContentEditor extends StatefulWidget {
  const TripContentEditor({super.key, required this.value, required this.defaults, required this.onChanged, this.trip = const {}, this.shared = false});
  final Map<String,dynamic> value, defaults, trip;
  final ValueChanged<Map<String,dynamic>> onChanged;
  final bool shared;
  @override State<TripContentEditor> createState()=>_TripContentEditorState();
}
class _TripContentEditorState extends State<TripContentEditor> {
  Map<String,dynamic> draft()=>TripContentSettings.copy(widget.value);
  Map<String,dynamic> effective(String key) {
    final section=TripContentSettings.copy(widget.value[key] is Map && (widget.shared || (['custom','hidden'].contains(widget.value[key]['mode']) && widget.value[key]['items'] is List)) ? widget.value[key] as Map : (widget.defaults[key] ?? TripContentSettings.highlightsDefault()) as Map);
    if(key=='highlights' && section['useTripHighlights']==true && !widget.shared) section['items']=[for(final text in (widget.trip['highlights'] as List? ?? [])) {'title':'','description':text,'enabled':true}];
    return section;
  }
  void update(String key, void Function(Map<String,dynamic>) change){final next=draft();final section=effective(key);section['mode']=widget.shared?'default':'custom';if(key=='highlights'&&!widget.shared)section['useTripHighlights']=false;change(section);next[key]=section;widget.onChanged(next);}
  Future<void> editItem(String key,{int? index}) async {
    final section=effective(key),items=List<dynamic>.from(effective(key)['items'] as List);
    final item=index==null?<String,dynamic>{}:Map<String,dynamic>.from(items[index] as Map);
    final fields=key=='glance'?['label','value']:key=='faqs'?['question','answer']:(key=='guidelines'||key=='highlights')?['title','description']:['minDays','maxDays','percent'];
    final controllers={for(final f in fields)f:TextEditingController(text:item[f]?.toString()??'')};
    var icon=item['icon']?.toString()??'info',binding=item['field']?.toString()??'';
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:Text(index==null?'Add item':'Edit item'),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final f in fields)Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:controllers[f],minLines:1,maxLines:['description','answer'].contains(f)?6:1,keyboardType:key=='cancellation'?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:{'minDays':'From days before departure','maxDays':'Through days (blank = no upper limit)','percent':'Cancellation fee (%)'}[f]??f,border:const OutlineInputBorder()))),
      if(key=='glance')DropdownButtonFormField<String>(value:binding,decoration:const InputDecoration(labelText:'Linked trip field'),items:TripContentSettings.fields.map((f)=>DropdownMenuItem(value:f,child:Text(f.isEmpty?'Custom value':f))).toList(),onChanged:(v)=>set(()=>binding=v!)),
      if(key!='faqs'&&key!='cancellation'&&key!='highlights')DropdownButtonFormField<String>(value:icon,decoration:const InputDecoration(labelText:'Icon'),items:TripContentSettings.icons.map((f)=>DropdownMenuItem(value:f,child:Text(f))).toList(),onChanged:(v)=>set(()=>icon=v!)),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){final value=<String,dynamic>{for(final f in fields)f:controllers[f]!.text.trim()};if(key=='cancellation'){value['minDays']=int.tryParse(value['minDays'] as String)??-1;value['maxDays']=(value['maxDays'] as String).isEmpty?null:int.tryParse(value['maxDays'] as String)??-1;value['percent']=num.tryParse(value['percent'] as String)??-1;}if(key=='glance')value['field']=binding;if(key!='faqs'&&key!='cancellation')value['icon']=icon;Navigator.pop(ctx,{...item,...value});},child:const Text('Save item'))])));
    for(final c in controllers.values)c.dispose();
    if(result==null||!mounted)return;
    update(key,(s){if(key=='highlights')s['useTripHighlights']=false;if(index==null)items.add(result);else items[index]=result;s['items']=items;});
  }
  Widget previewSection(String key) {
    final s = effective(key);
    if(key=='highlights' && s['useTripHighlights']==true) s['items']=[for(final text in (widget.trip['highlights'] as List? ?? [])) {'title':'','description':text}];
    final rows = <Widget>[Text(s['heading'] as String, style: Theme.of(context).textTheme.titleSmall)];
    for (final raw in s['items'] as List) {
      final item = raw as Map;
      if(item['enabled']==false) continue;
      String label;
      if (key == 'glance') {
        final value = item['field'] == null || item['field'] == '' ? item['value'] : widget.trip[item['field']] ?? '(linked trip value)';
        label = '${item['label']}: $value';
      } else if (key == 'faqs') {
        label = '${item['question']}\n${item['answer']}';
      } else if (key == 'guidelines' || key == 'highlights') {
        label = '${item['title']}\n${item['description']}';
      } else { label = '${item['minDays']}–${item['maxDays'] ?? '∞'} days: ${item['percent']}%'; }
      rows.add(Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(label)));
    }
    if (key == 'cancellation') rows.add(Text('${s['refundNote'] ?? ''}\n${s['changeNote'] ?? ''}'));
    rows.add(const Divider());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
  void preview() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Website content preview'),
        content: SizedBox(width: 900, child: SingleChildScrollView(child: LayoutBuilder(
          builder: (context, constraints) => Column(children: [
            for (final width in [360.0, 760.0])
              Padding(padding: const EdgeInsets.only(bottom: 20), child: SizedBox(
                width: width.clamp(0, constraints.maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(width == 360 ? 'Mobile' : 'Desktop', style: Theme.of(context).textTheme.titleMedium),
                  for (final key in TripContentSettings.titles.keys)
                    if (widget.value[key]?['mode'] != 'hidden' && effective(key)['mode'] != 'hidden') previewSection(key),
                ]),
              )),
          ]),
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(widget.shared?'Shared trip content':'Customisable website sections',style:Theme.of(context).textTheme.titleLarge),
    const Text('Linked fields follow trip edits. Empty custom lists stay empty. Shared settings apply only to trips using defaults.'),
    OutlinedButton.icon(onPressed:preview,icon:const Icon(Icons.preview),label:const Text('Mobile & desktop preview')),
    for(final key in TripContentSettings.titles.keys)ExpansionTile(title:Text(TripContentSettings.titles[key]!),subtitle:Text(widget.value[key]?['mode']??'default'),children:[
      DropdownButtonFormField<String>(key:ValueKey('content-mode-$key'),value:widget.value[key]?['mode']??'default',decoration:const InputDecoration(labelText:'Content source'),items:(widget.shared?['default','hidden']:['default','custom','hidden']).map((mode)=>DropdownMenuItem(value:mode,child:Text({'default':'Use shared defaults','custom':'Customise this trip','hidden':'Hide section'}[mode]!))).toList(),onChanged:(mode){final next=draft();next[key]=effective(key)..['mode']=mode;widget.onChanged(next);}),
      if((widget.shared&&widget.value[key]?['mode']!='hidden')||widget.value[key]?['mode']=='custom')...[
        TextFormField(key:ValueKey('$key-heading'),initialValue:effective(key)['heading'] as String,decoration:const InputDecoration(labelText:'Section heading'),onChanged:(v)=>update(key,(s)=>s['heading']=v)),
        if(key=='highlights') SwitchListTile(title:const Text('Use this trip’s existing highlights'),subtitle:const Text('Turn off to use the items below.'),value:effective(key)['useTripHighlights']==true,onChanged:(v)=>update(key,(s)=>s['useTripHighlights']=v)),
        if(key!='glance') SwitchListTile(title:const Text('Start expanded'),value:effective(key)['expanded']==true,onChanged:(v)=>update(key,(s)=>s['expanded']=v)),
        if(key=='glance')Wrap(spacing:8,children:[for(final preset in ['Trek','Culture','Beach','Adventure'])OutlinedButton(onPressed:()=>update(key,(s){s['items']=List<dynamic>.from(widget.defaults['glance']['items']);if(preset=='Trek'||preset=='Adventure')(s['items'] as List).add({'label':'Altitude','field':'elevation','value':'','icon':'mountain'});(s['items'] as List).insert(1,{'label':'Experience','field':'','value':preset=='Culture'?'Culture & sightseeing':preset=='Beach'?'Beaches & coastal travel':preset=='Trek'?'Trekking':'Adventure','icon':'info'});}),child:Text('$preset preset'))]),
        for(var i=0;i<(effective(key)['items'] as List).length;i++)ListTile(title:Text('${effective(key)['items'][i]['label']??effective(key)['items'][i]['question']??effective(key)['items'][i]['title']??effective(key)['items'][i]['description']??'Cancellation range ${i+1}'}'),onTap:()=>editItem(key,index:i),trailing:Wrap(children:[if(key!='cancellation') IconButton(tooltip:effective(key)['items'][i]['enabled']==false?'Show item':'Hide item',onPressed:()=>update(key,(s){final row=s['items'][i] as Map;row['enabled']=row['enabled']==false;}),icon:Icon(effective(key)['items'][i]['enabled']==false?Icons.visibility_off:Icons.visibility)),IconButton(tooltip:'Move up',onPressed:i==0?null:()=>update(key,(s){final list=s['items'] as List;final item=list.removeAt(i);list.insert(i-1,item);}),icon:const Icon(Icons.arrow_upward)),IconButton(tooltip:'Move down',onPressed:i==(effective(key)['items'] as List).length-1?null:()=>update(key,(s){final list=s['items'] as List;final item=list.removeAt(i);list.insert(i+1,item);}),icon:const Icon(Icons.arrow_downward)),IconButton(tooltip:'Remove item',onPressed:()=>update(key,(s)=>(s['items'] as List).removeAt(i)),icon:const Icon(Icons.delete_outline))])),
        TextButton.icon(onPressed:()=>editItem(key),icon:const Icon(Icons.add),label:const Text('Add item')),
        if(key=='cancellation')for(final field in ['refundNote','changeNote'])TextFormField(key:ValueKey('$field-note'),initialValue:effective(key)[field]?.toString()??'',maxLines:3,decoration:InputDecoration(labelText:field=='refundNote'?'Refund timing':'Date-change terms'),onChanged:(v)=>update(key,(s)=>s[field]=v)),
      ],
    ]),
  ])));
}
