import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../services/trip_date_utils.dart';
import '../widgets/departure_tools.dart';
import 'manager_tools_screen.dart' show bulkDates;

class DepartureManagementScreen extends StatelessWidget {
  const DepartureManagementScreen({super.key});
  Future<void> _duplicate(BuildContext context, TripsProvider provider, String id, String label) async {
    final scope=provider.draftScope;
    final range=TripDateUtils.parse(label);
    if(range==null)return;
    final selected=await showDateRangePicker(context:context,firstDate:DateTime(1900),lastDate:DateTime(2199,12,31),
      initialDateRange:DateTimeRange(start:DateTime(range.start.year,range.start.month,range.start.day),end:DateTime(range.end.year,range.end.month,range.end.day)),helpText:'Choose dates for the new departure');
    if(selected==null||!context.mounted)return;
    if(scope!=provider.draftScope||provider.isLoading)return;
    final current=provider.getTripById(id);if(current==null)return;
    final date=TripDateUtils.fromDates(selected.start,selected.end);
    if((current['availableDates'] as List? ?? []).any((label)=>TripDateUtils.parse(label.toString())?.key==date.key)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('That departure already exists.')));return;
    }
    provider.applyBulkDates({id},TripDateUtils.formatCanonical(date));await provider.flushDraft();
  }
  @override
  Widget build(BuildContext context){
    final provider=context.watch<TripsProvider>();
    return Scaffold(appBar:AppBar(title:const Text('Manage departures')),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:850),child:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Close or reopen bookings without deleting a date, or duplicate a departure into a new range. Changes stay in your trip draft until you publish.'),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:provider.isLoading?null:()=>bulkDates(context,provider),icon:const Icon(Icons.edit_calendar),label:const Text('Bulk date edit')),
      if(provider.isLoading)const LinearProgressIndicator(),
      if(provider.trips.isEmpty)const ListTile(title:Text('Load trips before managing departures.')),
      for(final trip in provider.trips)Card(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        ListTile(title:Text(trip['title']?.toString()??trip['id'].toString()),subtitle:Text(trip['isActive']==false?'Inactive trip': '${TripDateUtils.getUpcomingDateRanges(trip).length} bookable departures')),
        if((trip['availableDates'] as List? ?? []).isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('New dates coming soon. Add dates from Trips or Bulk date edit.'))
        else AbsorbPointer(absorbing:provider.isLoading,child:DepartureTools(
          dates:List<String>.from(trip['availableDates']),closedKeys:List<String>.from(trip['closedDepartures'] as List? ?? []),
          onToggle:(key)async{
            final id=trip['id'].toString(),index=provider.trips.indexWhere((t)=>t['id']==id);if(index<0||provider.isLoading)return;
            final draft=Map<String,dynamic>.from(provider.trips[index]);
            final closed=List<String>.from(draft['closedDepartures'] as List? ?? []);
            if(!closed.remove(key))closed.add(key);draft['closedDepartures']=closed;
            provider.updateTrip(index,draft);await provider.flushDraft();
          },
          onDuplicate:(index)=>_duplicate(context,provider,trip['id'].toString(),trip['availableDates'][index].toString()),
        )),
      ])),
    ]))));
  }
}
