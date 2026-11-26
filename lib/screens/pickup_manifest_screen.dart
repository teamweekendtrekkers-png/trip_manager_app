import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/pickup_service.dart';

class PickupManifestScreen extends StatefulWidget {
  const PickupManifestScreen({super.key, this.initialDeparture, this.service});

  final String? initialDeparture;
  final PickupService? service;

  @override
  State<PickupManifestScreen> createState() => _PickupManifestScreenState();
}

class _PickupManifestScreenState extends State<PickupManifestScreen> {
  late final service = widget.service ?? PickupService.organizer;
  final email = TextEditingController();
  final password = TextEditingController();
  final rosterSearch = TextEditingController();
  String? pickupFilter;
  List<PickupDeparture> departures = [];
  List<Map<String, dynamic>> stops = [], rows = [];
  String? selected, error;
  bool busy = false, showPassword = false;

  @override
  void initState() {
    super.initState();
    if (service.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(_loadDepartures);
      });
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    rosterSearch.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on StateError catch (err) {
      if (mounted) setState(() => error = err.message.toString());
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load Pickup. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _loadDepartures() async {
    final result = await service.departures();
    if (!mounted) return;
    final requested = selected ?? widget.initialDeparture;
    setState(() {
      departures = result;
      selected = result.any((row) => row.slug == requested)
          ? requested
          : result.firstOrNull?.slug;
    });
    await _loadList();
  }

  Future<void> _loadList() async {
    final slug = selected;
    if (slug == null) return;
    final locations = await service.stops(slug);
    final checkIns = await service.checkIns(slug);
    if (!mounted || selected != slug) return;
    setState(() {
      stops = locations;
      if (!stops.any((stop) => stop['id'] == pickupFilter)) {
        pickupFilter = null;
      }
      rows = checkIns;
    });
  }

  Future<void> _call(String value) async {
    final phone = value.replaceAll(RegExp(r'[^+\d]'), '');
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: phone))) return;
    } catch (_) {
      // Devices without a dialler can still copy the number.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialler.')),
      );
    }
  }

  Future<void> _editCheckIn([Map<String, dynamic>? party]) async {
    final slug = selected;
    if (slug == null || stops.isEmpty) return;
    final form = GlobalKey<FormState>();
    var name = party?['lead_name']?.toString() ?? '';
    var phone = party?['phone']?.toString() ?? '';
    var people = party?['party_size'] as int? ?? 1;
    var passengers = ((party?['passenger_names'] as List?) ?? [])
        .whereType<String>()
        .join('\n');
    var stop = party?['stop'] as String?;
    if (!stops.any((item) => item['id'] == stop)) stop = null;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(party == null ? 'Add check-in' : 'Edit check-in'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Lead traveller'),
                    validator: (value) => value!.trim().isEmpty
                        ? 'Enter the lead traveller’s name'
                        : null,
                    onSaved: (value) => name = value!.trim(),
                  ),
                  TextFormField(
                    initialValue: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number'),
                    validator: (value) {
                      final input = value!.trim();
                      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
                      return RegExp(r'^\+?[0-9 ()-]{10,21}$').hasMatch(input) &&
                              digits.length >= 10 && digits.length <= 15
                          ? null
                          : 'Enter a valid phone number';
                    },
                    onSaved: (value) => phone = value!.trim(),
                  ),
                  TextFormField(
                    initialValue: people.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total travellers'),
                    validator: (value) {
                      final count = int.tryParse(value!.trim());
                      return count != null && count >= 1 && count <= 50
                          ? null
                          : 'Enter a count between 1 and 50';
                    },
                    onSaved: (value) => people = int.parse(value!.trim()),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: stop,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pickup point'),
                    items: [
                      for (final item in stops)
                        DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(item['name'] as String,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => stop = value,
                    validator: (value) => value == null ? 'Select a pickup point' : null,
                  ),
                  TextFormField(
                    initialValue: passengers,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional traveller names',
                      helperText: 'Optional · one name per line',
                    ),
                    validator: (value) => value!.split('\n').any((line) => line.trim().length > 100)
                        ? 'Keep each name within 100 characters'
                        : null,
                    onSaved: (value) => passengers = value!,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(dialog, true);
            },
            child: const Text('Save check-in'),
          ),
        ],
      ),
    );
    if (save != true || !mounted || selected != slug) return;
    final names = passengers.split('\n').map((name) => name.trim()).toList();
    while (names.isNotEmpty && names.last.isEmpty) {
      names.removeLast();
    }
    await _run(() async {
      if (names.length >= people) {
        throw StateError('Enter no more than ${people - 1} additional traveller names.');
      }
      await service.saveCheckIn(slug, code: party?['code'] as String?,
          name: name, phone: phone, people: people, stop: stop!, passengers: names);
      await _loadList();
    });
  }

  Future<void> _removeCheckIn(Map<String, dynamic> party) async {
    final slug = selected;
    if (slug == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove check-in?'),
        content: Text('Remove ${party['lead_name']} and their group from this departure’s roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted || selected != slug) return;
    await _run(() async {
      await service.removeCheckIn(slug, party['code'] as String);
      await _loadList();
    });
  }

  int _total(Iterable<Map<String, dynamic>> parties) => parties.fold(
    0,
    (sum, row) => sum + ((row['party_size'] as num?)?.toInt() ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final query = rosterSearch.text.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneSearch = digits.isNotEmpty && RegExp(r'^[+0-9 ()-]+$').hasMatch(query);
    final filtering = query.isNotEmpty || pickupFilter != null;
    final visibleRows = rows.where((row) {
      if (pickupFilter != null && row['stop'] != pickupFilter) return false;
      if (query.isEmpty) return true;
      final names = [
        row['lead_name'],
        ...((row['passenger_names'] as List?) ?? const []),
      ];
      return names.whereType<String>().any((name) => name.toLowerCase().contains(query)) ||
          (phoneSearch && (row['phone']?.toString() ?? '')
              .replaceAll(RegExp(r'[^0-9]'), '').contains(digits));
    }).toList();
    final byStop = <String, List<Map<String, dynamic>>>{};
    final stopLabels = {for (final stop in stops) stop['id']: stop};
    for (final row in visibleRows) {
      final id = (row['stop'] as String?) ?? '';
      (byStop[id] ??= []).add(row);
    }
    final groups = [
      for (final stop in stops)
        if (byStop.containsKey(stop['id'])) stop['id'] as String,
      for (final id in byStop.keys)
        if (!stopLabels.containsKey(id)) id,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup check-ins'),
        actions: [
          if (service.signedIn)
            TextButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      await service.signOut();
                      if (mounted) {
                        setState(() {
                          departures = [];
                          stops = [];
                          rows = [];
                          selected = null;
                          pickupFilter = null;
                          rosterSearch.clear();
                        });
                      }
                    }),
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!service.signedIn) ...[
                const Text(
                  'Use your Pickup organizer account to see private traveller details.',
                ),
                TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Organizer email',
                  ),
                ),
                TextField(
                  controller: password,
                  enabled: !busy,
                  obscureText: !showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          try {
                            await service.signIn(email.text, password.text);
                          } finally {
                            password.clear();
                          }
                          if (mounted) await _loadDepartures();
                        }),
                  child: const Text('Sign in'),
                ),
              ] else ...[
                if (departures.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Departure'),
                    items: [
                      for (final trip in departures)
                        DropdownMenuItem(
                          value: trip.slug,
                          child: Text(
                            '${trip.date} · ${trip.title}${trip.open ? '' : ' · Closed'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            setState(() {
                              selected = value;
                              pickupFilter = null;
                              rosterSearch.clear();
                              rows = [];
                              stops = [];
                            });
                            _run(_loadList);
                          },
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _run(_loadDepartures),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh check-ins'),
                    ),
                    if (selected != null)
                      FilledButton.icon(
                        onPressed: busy || stops.isEmpty ? null : () => _editCheckIn(),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Add check-in'),
                      ),
                    if (selected != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final url = Uri.https(
                            'www.teamweekendtrekkers.com',
                            '/pickup/',
                            {'trip': selected!},
                          );
                          await Clipboard.setData(
                            ClipboardData(text: url.toString()),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Shared check-in link copied.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Copy check-in link'),
                      ),
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: rosterSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search name or phone',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: rosterSearch.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(rosterSearch.clear),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  if (stops.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey(pickupFilter),
                      initialValue: pickupFilter ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Pickup point'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All pickup points')),
                        for (final stop in stops)
                          DropdownMenuItem(
                            value: stop['id'] as String,
                            child: Text(stop['name'] as String, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        pickupFilter = value == '' ? null : value;
                      }),
                    ),
                ],
                if (filtering && visibleRows.isEmpty && rows.isNotEmpty)
                  const ListTile(title: Text('No check-ins match your filters.')),
                if (!busy && error == null && rows.isEmpty)
                  Text(
                    departures.isEmpty
                        ? 'No departure lists yet.'
                        : 'No travellers have checked in.',
                  ),
                if (rows.isNotEmpty)
                  ListTile(
                    title: Text('${_total(rows)} travellers checked in'),
                    subtitle: Text(
                      filtering
                          ? 'Showing ${visibleRows.length} of ${rows.length} parties'
                          : '${rows.length} parties',
                    ),
                  ),
                for (final id in groups)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${stopLabels[id]?['name'] ?? 'Pickup not selected'} · ${_total(byStop[id]!)} travellers',
                          ),
                          subtitle: Text(
                            stopLabels[id]?['pickup_time']?.toString() ?? '',
                          ),
                        ),
                        for (final party in byStop[id]!)
                          ListTile(
                            title: Text(
                              '${party['lead_name']} · ${party['party_size']} travelling',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  party['phone']?.toString() ?? '',
                                ),
                                for (final name
                                    in ((party['passenger_names'] as List?) ??
                                            [])
                                        .whereType<String>()
                                        .take(
                                          ((party['party_size'] as num?)
                                                      ?.toInt() ??
                                                  1) -
                                              1,
                                        ))
                                  if (name.isNotEmpty) Text(name),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call_outlined),
                                  tooltip: 'Call ${party['lead_name']}',
                                  onPressed: party['phone'] == null
                                      ? null
                                      : () => _call(party['phone'].toString()),
                                ),
                                PopupMenuButton<String>(
                                  enabled: !busy,
                                  tooltip: 'Manage check-in',
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    child: Text('Manage'),
                                  ),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _editCheckIn(party);
                                    } else {
                                      _removeCheckIn(party);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      enabled: stops.isNotEmpty,
                                      child: const Text('Edit check-in'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove check-in'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
