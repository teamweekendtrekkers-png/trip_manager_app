import 'package:flutter/material.dart';

enum InlineStyle { bold, italic, both }

/// The stored markers are portable across drafts, publishing and the website.
TextEditingValue toggleInlineStyle(TextEditingValue value, InlineStyle style) {
  final selection=value.selection;
  if(!selection.isValid || selection.isCollapsed || selection.end>value.text.length)return value;
  var start=selection.start,end=selection.end;
  final selected=value.text.substring(start,end);
  if(selected.contains('\n')){
    final lines=selected.split('\n').map((line){
      if(line.trim().isEmpty)return line;
      final a=line.length-line.trimLeft().length,b=line.trimRight().length;
      return toggleInlineStyle(TextEditingValue(text:line,selection:TextSelection(baseOffset:a,extentOffset:b)),style).text;
    }).join('\n');
    return value.copyWith(text:value.text.replaceRange(start,end,lines),selection:TextSelection(baseOffset:start,extentOffset:start+lines.length),composing:TextRange.empty);
  }
  var content=selected,mask=0;
  final own=RegExp(r'^(\*{1,3})(\S(?:[\s\S]*?\S)?)\1$').firstMatch(content);
  if(own!=null){
    final n=own.group(1)!.length;mask=n==3?3:n==2?1:2;content=own.group(2)!;
  }else{
    var before=0,after=0;
    while(before<3&&start-before>0&&value.text[start-before-1]=='*')before++;
    while(after<3&&end+after<value.text.length&&value.text[end+after]=='*')after++;
    if(before>0&&before==after){mask=before==3?3:before==2?1:2;start-=before;end+=after;}
  }
  mask=style==InlineStyle.both?(mask==3?0:3):mask^(style==InlineStyle.bold?1:2);
  final marker=mask==3?'***':mask==1?'**':mask==2?'*':'';
  final leading=content.length-content.trimLeft().length,trailing=content.trimRight().length;
  if(trailing<=leading)return value;
  final replacement=content.substring(0,leading)+marker+content.substring(leading,trailing)+marker+content.substring(trailing);
  final innerStart=start+leading+marker.length,innerEnd=innerStart+trailing-leading;
  return value.copyWith(text:value.text.replaceRange(start,end,replacement),selection:TextSelection(baseOffset:innerStart,extentOffset:innerEnd),composing:TextRange.empty);
}

Widget formattingContextMenu(BuildContext context,EditableTextState editable){
  final value=editable.widget.controller.value;
  void apply(InlineStyle style){
    final next=toggleInlineStyle(editable.widget.controller.value,style);
    editable.hideToolbar();
    editable.userUpdateTextEditingValue(next,SelectionChangedCause.toolbar);
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors:editable.contextMenuAnchors,
    buttonItems:[
      ...editable.contextMenuButtonItems,
      if(value.selection.isValid&&!value.selection.isCollapsed)...[
        ContextMenuButtonItem(label:'Bold',onPressed:()=>apply(InlineStyle.bold)),
        ContextMenuButtonItem(label:'Italic',onPressed:()=>apply(InlineStyle.italic)),
        ContextMenuButtonItem(label:'Bold + italic',onPressed:()=>apply(InlineStyle.both)),
      ],
    ],
  );
}

List<InlineSpan> inlineSpans(String source,{bool bold=false,bool italic=false,int depth=0}){
  if(depth>12)return [TextSpan(text:source)];
  final pattern=RegExp(r'(\*{1,3})(?=\S)([\s\S]*?\S|\S)\1(?!\*)'),spans=<InlineSpan>[];
  var cursor=0;
  TextStyle style(bool b,bool i)=>TextStyle(fontWeight:b?FontWeight.bold:null,fontStyle:i?FontStyle.italic:null);
  for(final match in pattern.allMatches(source)){
    if(match.start>cursor)spans.add(TextSpan(text:source.substring(cursor,match.start),style:style(bold,italic)));
    final n=match.group(1)!.length;
    spans.addAll(inlineSpans(match.group(2)!,bold:bold||n>=2,italic:italic||n==1||n==3,depth:depth+1));
    cursor=match.end;
  }
  if(cursor<source.length)spans.add(TextSpan(text:source.substring(cursor),style:style(bold,italic)));
  return spans.isEmpty?[TextSpan(text:source,style:style(bold,italic))]:spans;
}

String plainInlineText(String source)=>TextSpan(children:inlineSpans(source)).toPlainText();

class FormattedText extends StatelessWidget{
  const FormattedText(this.data,{super.key,this.style,this.maxLines,this.overflow,this.textAlign});
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  @override Widget build(BuildContext context)=>Text.rich(TextSpan(style:style,children:inlineSpans(data)),maxLines:maxLines,overflow:overflow,textAlign:textAlign,semanticsLabel:plainInlineText(data));
}
