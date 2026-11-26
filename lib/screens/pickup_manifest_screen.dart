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

  int _total(Iterable<Map<String, dynamic>> parties) => parties.fold(
    0,
    (sum, row) => sum + ((row['party_size'] as num?)?.toInt() ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final byStop = <String, List<Map<String, dynamic>>>{};
    final stopLabels = {for (final stop in stops) stop['id']: stop};
    for (final row in rows) {
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
                if (!busy && error == null && rows.isEmpty)
                  Text(
                    departures.isEmpty
                        ? 'No departure lists yet.'
                        : 'No travellers have checked in.',
                  ),
                if (rows.isNotEmpty)
                  ListTile(
                    title: Text('${_total(rows)} travellers checked in'),
                    subtitle: Text('${rows.length} parties'),
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
                            trailing: IconButton(
                              icon: const Icon(Icons.call_outlined),
                              tooltip: 'Call ${party['lead_name']}',
                              onPressed: party['phone'] == null
                                  ? null
                                  : () => _call(party['phone'].toString()),
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
