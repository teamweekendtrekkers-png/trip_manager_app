import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/trip_date_utils.dart';

class QuickTripEditor extends StatefulWidget {
  const QuickTripEditor({super.key, required this.trip});
  final Map<String, dynamic> trip;
  @override State<QuickTripEditor> createState() => _QuickTripEditorState();
}

class _QuickTripEditorState extends State<QuickTripEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _price;
  late final List<String> _dates;
  late bool _active, _featured;
  String? _error;
  @override void initState() {
    super.initState();
    _price = TextEditingController(text: widget.trip['price']?.toString() ?? '');
    _dates = List<String>.from(widget.trip['availableDates'] ?? []);
    _active = widget.trip['isActive'] != false;
    _featured = widget.trip['featured'] == true;
  }
  @override void dispose() { _price.dispose(); super.dispose(); }
  Future<void> _pickDate([int? index]) async {
    final current = index == null ? null : TripDateUtils.parse(_dates[index]);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900), lastDate: DateTime(2199, 12, 31),
      initialDateRange: current == null ? null : DateTimeRange(start: current.start, end: current.end),
    );
    if (range == null || !mounted) return;
    final label = TripDateUtils.formatCanonical(TripDateUtils.fromDates(range.start, range.end));
    final duplicate = _dates.asMap().entries.any((entry) => entry.key != index && TripDateUtils.parse(entry.value)?.key == TripDateUtils.parse(label)?.key);
    if (duplicate) { setState(() => _error = 'This departure is already in the list.'); return; }
    setState(() { _error = null; if (index == null) { _dates.add(label); } else { _dates[index] = label; } });
  }
  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_dates.any((label) => TripDateUtils.parse(label) == null)) {
      setState(() => _error = 'Edit or remove the invalid departure before saving.'); return;
    }
    final keys = _dates.map((label) => TripDateUtils.parse(label)!.key).toSet();
    if (keys.length != _dates.length) { setState(() => _error = 'Remove duplicate departure dates before saving.'); return; }
    final result = Map<String, dynamic>.from(jsonDecode(jsonEncode(widget.trip)) as Map);
    final text = _price.text.trim();
    result['price'] = text.startsWith('₹') ? text : '₹$text';
    if(jsonEncode(_dates)!=jsonEncode(widget.trip['availableDates']??[])){result['availableDates']=List<String>.from(_dates);if(_dates.isEmpty){result.remove('date');}else{result['date']=_dates.first;}}
    if(_active!=(widget.trip['isActive']!=false))result['isActive']=_active;
    if(_featured!=(widget.trip['featured']==true))result['featured']=_featured;
    Navigator.pop(context, result);
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('Quick edit'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: _form, child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.trip['title']?.toString() ?? 'Trip', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Save to your workspace first. Publish from the trips workspace when ready.'),
        const SizedBox(height: 16),
        TextFormField(key: const Key('quick-trip-price'), controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price per person (₹)', border: OutlineInputBorder()),
          validator: (value) { final text = (value ?? '').replaceAll('₹', '').replaceAll(',', '').trim(); final price = num.tryParse(text); return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) && price != null && price.isFinite && price >= 0 ? null : 'Enter a valid price, for example 4499.'; }),
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active trip'), value: _active, onChanged: (v) => setState(() => _active = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show on homepage'), value: _featured, onChanged: (v) => setState(() => _featured = v)),
        const Divider(), const Text('Departure dates'),
        if (_dates.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No departure dates. Customers will see new dates coming soon.')),
        for (var i = 0; i < _dates.length; i++) ListTile(contentPadding: EdgeInsets.zero, title: Text(_dates[i]),
          subtitle: TripDateUtils.parse(_dates[i]) == null ? const Text('Invalid date — tap to correct it') : null,
          onTap: () => _pickDate(i), trailing: IconButton(tooltip: 'Remove departure ${i + 1}', icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _dates.removeAt(i)))),
        OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.add), label: const Text('Add departure')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    )))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton.icon(key: const Key('quick-trip-save'), onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save draft'))],
  );
}
