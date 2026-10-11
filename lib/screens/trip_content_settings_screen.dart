import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/github_service.dart';
import '../services/trip_content_service.dart';
import '../widgets/trip_content_editor.dart';

class TripContentSettingsScreen extends StatefulWidget {
  const TripContentSettingsScreen({super.key});
  @override State<TripContentSettingsScreen> createState()=>_TripContentSettingsScreenState();
}
class _TripContentSettingsScreenState extends State<TripContentSettingsScreen> {
  late TripContentService service;
  Map<String,dynamic>? config;
  bool busy=false,dirty=false;
  String? error;
  @override void initState(){super.initState();service=TripContentService(GitHubService(settings:context.read<SettingsProvider>().settings));load();}
  Future<void> load() async {setState(()=>busy=true);try{final value=await service.load();if(mounted)setState((){config=value;dirty=false;error=null;});}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> publish() async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Publish shared trip content?'),content:const Text('This updates trips using shared defaults. Trips with custom sections keep their own content. Review the mobile and desktop preview before publishing.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Publish'))]));
    if(yes!=true||!mounted)return;setState(()=>busy=true);final result=await service.save(config!);if(!mounted)return;setState((){busy=false;if(result.success){dirty=false;error=null;}else{error=result.error;}});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.success?'Published. Wait for website deployment.':result.error??'Publish failed.')));
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:!dirty&&!busy,onPopInvokedWithResult:(didPop,result) async{if(didPop||busy)return;final discard=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Discard content edits?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Keep editing')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Discard'))]));if(discard==true&&mounted){setState(()=>dirty=false);Navigator.pop(context);}},child:Scaffold(appBar:AppBar(title:const Text('Shared Trip Content')),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1000),child:ListView(padding:const EdgeInsets.all(16),children:[
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    if(config==null)FilledButton(onPressed:busy?null:load,child:const Text('Load shared content')),
    if(config!=null)AbsorbPointer(absorbing:busy,child:TripContentEditor(value:Map<String,dynamic>.from(config!['sections'] as Map),defaults:Map<String,dynamic>.from(config!['sections'] as Map),shared:true,onChanged:(v)=>setState((){config!['sections']=v;dirty=true;}))),
    if(config!=null)FilledButton(onPressed:busy?null:publish,child:Text(busy?'Publishing…':'Publish shared content')),
  ])))));
}
