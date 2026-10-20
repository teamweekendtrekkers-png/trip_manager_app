import 'package:flutter/material.dart';

List<String> reorderGallery(List<String> photos,int oldIndex,int newIndex){
 final result=List<String>.from(photos);
 if(oldIndex<0||oldIndex>=result.length||newIndex<0||newIndex>result.length)return result;
 if(newIndex>oldIndex)newIndex--;
 result.insert(newIndex,result.removeAt(oldIndex));return result;
}
class GalleryOrderEditor extends StatelessWidget{
 const GalleryOrderEditor({super.key,required this.photos,required this.imageBuilder,required this.onChanged,required this.onRemove});
 final List<String> photos;final Widget Function(String) imageBuilder;
 final ValueChanged<List<String>> onChanged;final ValueChanged<int> onRemove;
 @override Widget build(BuildContext context)=>ReorderableListView.builder(
  key:const Key('gallery-order-editor'),shrinkWrap:true,primary:false,physics:const NeverScrollableScrollPhysics(),
  buildDefaultDragHandles:false,itemCount:photos.length,
  onReorder:(from,to)=>onChanged(reorderGallery(photos,from,to)),
  itemBuilder:(context,index){
   final photo=photos[index],occurrence=photos.take(index).where((p)=>p==photo).length;
   return SizedBox(key:ValueKey('gallery-photo-$photo-$occurrence'),height:112,child:Card(margin:const EdgeInsets.symmetric(vertical:4),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
    Stack(children:[
     SizedBox(width:96,height:72,child:ClipRRect(borderRadius:BorderRadius.circular(8),child:imageBuilder(photo))),
     Positioned(left:4,top:4,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(8)),child:Text('${index+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))),
    ]),
    const SizedBox(width:10),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text('Photo ${index+1}',style:Theme.of(context).textTheme.titleSmall),
     Text(index==0?'Opens the website gallery':'Drag to reorder',style:Theme.of(context).textTheme.bodySmall,maxLines:2,overflow:TextOverflow.ellipsis),
    ])),
    PopupMenuButton<String>(tooltip:'Photo ${index+1} actions',itemBuilder:(_)=>[
     PopupMenuItem(value:'up',enabled:index>0,child:const Text('Move up')),
     PopupMenuItem(value:'down',enabled:index<photos.length-1,child:const Text('Move down')),
     const PopupMenuItem(value:'remove',child:Text('Remove from gallery')),
    ],onSelected:(action){
     if(action=='remove'){onRemove(index);return;}
     final values=List<String>.from(photos),target=index+(action=='up'?-1:1);
     if(target<0||target>=values.length)return;
     final photo=values.removeAt(index);values.insert(target,photo);onChanged(values);
    }),
    ReorderableDragStartListener(index:index,child:Tooltip(message:'Drag photo ${index+1}',child:const SizedBox(width:44,height:48,child:Icon(Icons.drag_handle)))),
   ])))),
  },
 );
}
