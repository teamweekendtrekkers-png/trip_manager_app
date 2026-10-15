import 'package:flutter/material.dart';

class PaymentOptionsEditor extends StatelessWidget {
  const PaymentOptionsEditor({super.key,required this.payment,required this.trips,required this.onChanged,this.busy=false,this.referenceDate});
  final Map<String,dynamic> payment;
  final List<Map<String,dynamic>> trips;
  final VoidCallback onChanged;
  final bool busy;
  final DateTime? referenceDate;
  @override
  Widget build(BuildContext context){
    final requests=payment['requestTripIds'] as List;
    final known=trips.map((t)=>t['id']).toSet();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const ListTile(leading:Icon(Icons.payments_outlined),title:Text('UPI payment by default'),subtitle:Text('Every bookable trip offers payment. Customers scan a QR or copy the UPI ID. Your team verifies payments manually.')),
      ExpansionTile(key:const Key('payment-eligibility'),title:const Text('Allow booking requests for selected trips'),subtitle:Text('${requests.length} trips · payment stays selected by default'),children:[
        if(trips.isEmpty)const ListTile(title:Text('Load trips to choose where customers may request availability before paying.')),
        for(final trip in trips)CheckboxListTile(key:ValueKey('payment-trip-${trip['id']}'),title:Text(trip['title']?.toString()??trip['id'].toString()),subtitle:const Text('Also offer Request availability before paying'),value:requests.contains(trip['id']),onChanged:busy?null:(checked){requests.remove(trip['id']);if(checked==true)requests.add(trip['id']);onChanged();}),
        for(final id in requests.where((id)=>!known.contains(id)).toList())ListTile(title:Text(id.toString()),subtitle:const Text('Trip is no longer available'),trailing:IconButton(tooltip:'Remove request option',onPressed:busy?null:(){requests.remove(id);onChanged();},icon:const Icon(Icons.delete_outline))),
      ]),
    ]);
  }
}
