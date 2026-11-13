import 'package:flutter/material.dart';
import '../services/trip_date_utils.dart';

class DepartureTools extends StatelessWidget {
  const DepartureTools({super.key,required this.dates,required this.closedKeys,required this.onToggle,required this.onDuplicate,this.confirmedKeys=const [],this.soldOutKeys=const [],this.onStatus});
  final List<String> dates,closedKeys,confirmedKeys,soldOutKeys;
  final void Function(String key,String status)? onStatus;
  final ValueChanged<String> onToggle;
  final ValueChanged<int> onDuplicate;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('departure-tools'),
    title: const Text('Close, reopen or duplicate departures'),
    subtitle: const Text('Closing keeps the date saved and prevents new bookings.'),
    children: [
      for(var index=0;index<dates.length;index++)
        if(TripDateUtils.parse(dates[index])!=null)Builder(builder:(_){
          final range=TripDateUtils.parse(dates[index])!;
          final closed=closedKeys.contains(range.key);
          return ListTile(title:Text(dates[index]),subtitle:Text(soldOutKeys.contains(range.key)?'Sold out':closed?'Bookings closed':confirmedKeys.contains(range.key)?'Confirmed departure':'Bookings follow the departure cutoff'),
            trailing:PopupMenuButton<String>(tooltip:'Departure actions',onSelected:(value){if(value=='duplicate'){onDuplicate(index);}else if(['available','confirmed','sold-out'].contains(value)){onStatus?.call(range.key,value);}else{onToggle(range.key);}},itemBuilder:(_)=>[
              if(onStatus!=null)...[
                const PopupMenuItem(value:'available',child:Text('Available to book')),
                const PopupMenuItem(value:'confirmed',child:Text('Confirm departure')),
                const PopupMenuItem(value:'sold-out',child:Text('Mark sold out')),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(value:'toggle',child:Text(closed?'Reopen bookings':'Close bookings')),
              const PopupMenuItem(value:'duplicate',child:Text('Duplicate departure')),
            ]),
          );
        }),
    ],
  );
}
