import 'package:flutter/material.dart';

class BatchPalette{
 const BatchPalette(this.label,this.background,this.border,this.accent);
 final String label;final Color background,border,accent;
}
const batchPalettes=<String,BatchPalette>{
 'forest':BatchPalette('Forest',Color(0xffeff7f2),Color(0xff8caf9b),Color(0xff174b32)),
 'teal':BatchPalette('Teal',Color(0xffedf8f7),Color(0xff86bcb3),Color(0xff08685f)),
 'blue':BatchPalette('Blue',Color(0xffeff5fc),Color(0xff91b0d7),Color(0xff245993)),
 'violet':BatchPalette('Violet',Color(0xfff5f0fb),Color(0xffb9a0d8),Color(0xff64418c)),
 'amber':BatchPalette('Amber',Color(0xfffff7e8),Color(0xffd6b36a),Color(0xff805000)),
 'rose':BatchPalette('Rose',Color(0xfffdf0f2),Color(0xffd7a0ac),Color(0xff963e56)),
};
class BatchColorPicker extends StatelessWidget{
 const BatchColorPicker({super.key,required this.value,required this.onChanged});
 final String? value;final ValueChanged<String> onChanged;
 @override Widget build(BuildContext context){
  final selected=batchPalettes.containsKey(value)?value!:'forest',palette=batchPalettes[batchPalettes.containsKey(value)?value!:'forest']!;
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('Upcoming Batches colour',style:Theme.of(context).textTheme.titleMedium),
   const SizedBox(height:8),
   const Text('Every departure of this trip uses the same colour after publishing.'),
   const SizedBox(height:12),
   Wrap(spacing:8,runSpacing:8,children:[for(final entry in batchPalettes.entries)ChoiceChip(
    key:ValueKey('batch-color-${entry.key}'),label:Text(entry.value.label),
    avatar:CircleAvatar(backgroundColor:entry.value.accent,radius:9),
    selected:selected==entry.key,onSelected:(_)=>onChanged(entry.key),
   )]),
   const SizedBox(height:12),
   Container(key:const Key('batch-color-preview'),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:palette.background,border:Border.all(color:palette.border),borderRadius:BorderRadius.circular(12)),
    child:Row(children:[
     Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:palette.accent,borderRadius:BorderRadius.circular(8)),child:const Text('23–25 Oct',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
     const SizedBox(width:12),const Expanded(child:Text('Your trip',style:TextStyle(color:Color(0xff173f35),fontWeight:FontWeight.bold))),
     Icon(Icons.arrow_forward,color:palette.accent),
    ]),
   ),
  ]);
 }
}
