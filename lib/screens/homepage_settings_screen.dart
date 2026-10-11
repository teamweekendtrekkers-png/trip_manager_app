import 'dart:convert';
import 'dart:io';
import '../widgets/footer_settings_editor.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/homepage_config.dart';
import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/github_service.dart';
import '../services/homepage_settings_service.dart';
import '../services/image_upload_service.dart';
import '../services/photo_advice.dart';
import '../services/trip_date_utils.dart';
import 'deployment_status_screen.dart';
import '../widgets/homepage_sections_editor.dart';
import '../widgets/discovery_settings_editor.dart';

class HomepageSettingsScreen extends StatefulWidget {
  const HomepageSettingsScreen({
    super.key,
    this.service,
    this.trips,
    this.referenceDate,
    this.imageUploader,
    this.imagePreviewBuilder,
  });
  final HomepageSettingsService? service;
  final List<Map<String, dynamic>>? trips;
  final DateTime? referenceDate;
  final Future<String?> Function()? imageUploader;
  final Widget Function(String imageUrl)? imagePreviewBuilder;

  @override
  State<HomepageSettingsScreen> createState() => _HomepageSettingsScreenState();
}

class _HomepageSettingsScreenState extends State<HomepageSettingsScreen> {
  late HomepageSettingsService _service;
  late AppSettings _target;
  Map<String, dynamic>? _draft;
  String? _saved;
  String? _error;
  String? _savedCommit;
  bool _busy = true;
  bool _allowExit = false;
  int _sectionsRevision = 0;
  final _controllers = <String, TextEditingController>{};
  bool get _dirty => _draft != null && jsonEncode(_draft) != _saved;
  Map<String, dynamic> get _hero => _draft!['hero'] as Map<String, dynamic>;
  Map<String, dynamic> get _batches =>
      _draft!['upcomingBatches'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get _trips =>
      widget.trips ?? context.read<TripsProvider>().trips;
  bool get _targetMatches {
    final current = context.read<SettingsProvider>().settings;
    return current.repositoryOwner == _target.repositoryOwner &&
        current.repositoryName == _target.repositoryName &&
        current.branch == _target.branch &&
        current.tripsDataPath == _target.tripsDataPath &&
        current.githubToken == _target.githubToken;
  }

  @override
  void initState() {
    super.initState();
    _target = context.read<SettingsProvider>().settings.copyWith();
    _service =
        widget.service ??
        HomepageSettingsService(GitHubService(settings: _target));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final config = await _service.load();
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      setState(() {
        _draft = config.toJson();
        _saved = jsonEncode(_draft);
        _sectionsRevision++;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard homepage edits?'),
        content: const Text(
          'These changes have not been published. Your trip edits are separate and will not be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _reload() async {
    if (_busy || !_targetMatches) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard and reload homepage?'),
          content: const Text(
            'Replace only this unsaved homepage draft with the current GitHub version? Trip edits are not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reload'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted || !_targetMatches) return;
    }
    await _load();
  }

  Future<void> _publish() async {
    if (_busy || !_targetMatches || _draft == null) return;
    HomepageConfig config;
    try {
      config = HomepageConfig.parse(jsonEncode(_draft));
    } catch (error) {
      setState(() => _error = error.toString());
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish homepage?'),
        content: Text(
          'Publish homepage settings to ${_target.repositoryOwner}/${_target.repositoryName} (${_target.branch})? Trip data, booking links and payment settings are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_targetMatches) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _service.save(config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) {
        _draft = _service.savedConfig!.toJson();
        _saved = jsonEncode(_draft);
        _sectionsRevision++;
        _savedCommit = result.commitSha;
        for (final entry in _controllers.entries) {
          final parts = entry.key.split('.');
          entry.value.text =
              (_draft![parts.first] as Map)[parts.last] as String;
        }
      } else {
        _error =
            result.error ??
            'Homepage publication failed. Your edits are retained.';
      }
    });
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homepage settings published.')),
      );
    }
  }

  Future<void> _upload({String group = 'hero', String field = 'backgroundImage'}) async {
    if (_busy || !_targetMatches) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? path;
      if (widget.imageUploader != null) {
        path = await widget.imageUploader!();
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          if (!mounted || !_targetMatches) {
            throw StateError(
              'GitHub settings changed. Reopen the homepage editor.',
            );
          }
          if (![
            'jpg',
            'jpeg',
            'png',
            'webp',
          ].contains(image.path.split('.').last.toLowerCase())) {
            throw StateError('Choose a JPG, PNG or WebP image.');
          }
          final result = await ImageUploadService(settings: _target)
              .uploadImage(
                imageFile: File(image.path),
                tripId: field == 'heroMobileImage' ? 'homepage_mobile' : 'homepage',
                isMainImage: true,
              );
          if (!result.success) {
            throw StateError(result.error ?? 'Image upload failed.');
          }
          path = result.imagePath;
          final advice = await photoResolutionAdvice(File(image.path), minWidth: 1600);
          if (advice != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(advice)));
          }
        }
      }
      if (path != null && mounted) {
        setState(() {
          _draft![group][field] = path;
          _controllers['$group.$field']?.text = path!;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _text(String group, String field, String label, {int lines = 1}) {
    final values = _draft![group] as Map;
    final controller = _controllers.putIfAbsent(
      '$group.$field',
      () => TextEditingController(text: values[field] as String),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey('homepage-$group-$field'),
        controller: controller,
        enabled: !_busy,
        minLines: 1,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => values[field] = value),
      ),
    );
  }

  Widget _backgroundPreview() {
    final path = _hero['backgroundImage'] as String;
    final url = path.startsWith('https://')
        ? path
        : 'https://raw.githubusercontent.com/${_target.repositoryOwner}/${_target.repositoryName}/${_target.branch}/$path';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child:
          widget.imagePreviewBuilder?.call(url) ??
          Image.network(
            url,
            key: const Key('homepage-background-preview'),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Image preview unavailable. Check the path or URL.',
                ),
              ),
            ),
          ),
    );
  }

  Widget _cropPreview(String path, double ratio, String label, double width) {
    final url = path.startsWith('https://') ? path : 'https://raw.githubusercontent.com/' + _target.repositoryOwner + '/' + _target.repositoryName + '/' + _target.branch + '/' + path;
    final focus = _draft!['presentation'][ratio < 1 ? 'heroMobileFocalPoint' : 'heroFocalPoint'];
    final alignment = switch (focus) {
      'top' => Alignment.topCenter,
      'bottom' => Alignment.bottomCenter,
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
    return SizedBox(width: width, child: Column(children: [
      Text(label),
      AspectRatio(aspectRatio: ratio, child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.imagePreviewBuilder?.call(url) ?? Image.network(url, fit: BoxFit.cover, alignment: alignment,
          errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image))),
      )),
    ]));
  }

  void _toggleTrip(String id, bool selected) => setState(() {
    final ids = List<String>.from(_batches['tripIds'] as List);
    selected ? ids.add(id) : ids.remove(id);
    _batches['tripIds'] = ids.toSet().toList();
  });

  void _toggleDeparture(String id, TripDateRange range, bool selected) =>
      setState(() {
        final entries = List<Map<String, dynamic>>.from(
          (_batches['departures'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        entries.removeWhere(
          (item) =>
              item['tripId'] == id &&
              TripDateUtils.parse(item['date'] as String)?.key == range.key,
        );
        if (selected) {
          entries.add({
            'tripId': id,
            'date': TripDateUtils.formatCanonical(range),
          });
        }
        _batches['departures'] = entries;
      });

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    return PopScope(
      canPop: !_busy && (!_dirty || _allowExit),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Homepage Customization'),
          actions: [
            IconButton(
              tooltip: 'Reload homepage',
              onPressed: _busy || !_targetMatches ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _draft == null
            ? Center(
                child: _busy
                    ? const CircularProgressIndicator()
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error ?? 'Unable to load homepage settings.',
                              ),
                            ),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
              )
            : AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    const Text(
                      'Homepage-only settings. Trip records, featured trips, payments and booking links are unchanged. Image uploads add an asset; Publish applies it to the homepage.',
                    ),
                    if (!_targetMatches)
                      const Text(
                        'GitHub settings changed. Go back and reopen this editor before publishing.',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          key: const Key('homepage-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Hero / Background',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _text(
                      'hero',
                      'backgroundImage',
                      'Background image path or HTTPS URL',
                    ),
                    if (HomepageConfig.safeImage(
                      _hero['backgroundImage'] as String,
                    ))
                      _backgroundPreview(),
                    OutlinedButton.icon(
                      key: const Key('homepage-upload'),
                      onPressed: _upload,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Upload background image'),
                    ),
                    const SizedBox(height: 12),
                    _text('hero', 'title', 'Headline', lines: 3),
                    _text('hero', 'tagline', 'Tagline', lines: 3),
                    _text('hero', 'description', 'Description', lines: 3),
                    ExpansionTile(
                      title: const Text('Website appearance and hero photos'),
                      children: [
                        DropdownButtonFormField<String>(
                          key: const Key('homepage-presentation-preset'),
                          initialValue: _draft!['presentation']['preset'] as String,
                          decoration: const InputDecoration(labelText: 'Colour palette'),
                          items: [for (final preset in ['forest', 'ocean', 'earth']) DropdownMenuItem(value: preset, child: Text(preset))],
                          onChanged: (value) => setState(() => _draft!['presentation']['preset'] = value),
                        ),
                        const SizedBox(height: 12),
                        _text('presentation', 'heroMobileImage', 'Mobile hero photo (optional path or HTTPS URL)'),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _upload(group: 'presentation', field: 'heroMobileImage'),
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Upload mobile hero photo'),
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey('desktop-focus-' + _draft!['presentation']['heroFocalPoint'].toString()),
                          initialValue: _draft!['presentation']['heroFocalPoint'] as String,
                          decoration: const InputDecoration(labelText: 'Desktop hero photo focus'),
                          items: [for (final focus in ['center', 'top', 'bottom', 'left', 'right']) DropdownMenuItem(value: focus, child: Text(focus))],
                          onChanged: (value) => setState(() => _draft!['presentation']['heroFocalPoint'] = value),
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey('mobile-focus-' + _draft!['presentation']['heroMobileFocalPoint'].toString()),
                          initialValue: _draft!['presentation']['heroMobileFocalPoint'] as String,
                          decoration: const InputDecoration(labelText: 'Mobile hero photo focus'),
                          items: [for (final focus in ['center', 'top', 'bottom', 'left', 'right']) DropdownMenuItem(value: focus, child: Text(focus))],
                          onChanged: (value) => setState(() => _draft!['presentation']['heroMobileFocalPoint'] = value),
                        ),
                        TextButton(onPressed: () => setState(() { _draft!['presentation']['heroFocalPoint'] = 'center'; _draft!['presentation']['heroMobileFocalPoint'] = 'center'; }), child: const Text('Reset both crops to centre')),
                        TextFormField(
                          key: const Key('homepage-hero-slides'),
                          initialValue: (_draft!['presentation']['heroSlides'] as List).join('\n'),
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Additional hero photos (up to 2, one path per line)'),
                          onChanged: (value) => setState(() => _draft!['presentation']['heroSlides'] = value.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList()),
                        ),
                        SwitchListTile(
                          title: const Text('Slow hero photo crossfade'),
                          subtitle: const Text('One pass only. Text stays still; reduced motion uses one photo.'),
                          value: _draft!['presentation']['heroMotion'] as bool,
                          onChanged: (value) => setState(() => _draft!['presentation']['heroMotion'] = value),
                        ),
                        const Text('Desktop hero 16:7 — 1920×840 px. Mobile hero 4:5 — 1080×1350 px. Trip cards 16:9 — 1200×675 px. Gallery 4:3 — 1200×900 px. Keep faces and text away from crop edges. Original photos are retained.'),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          _cropPreview(_hero['backgroundImage'] as String, 16 / 7, 'Desktop hero', 300),
                          _cropPreview((_draft!['presentation']['heroMobileImage'] as String).isEmpty ? _hero['backgroundImage'] as String : _draft!['presentation']['heroMobileImage'] as String, 4 / 5, 'Mobile hero', 160),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upcoming Batches',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SwitchListTile(
                      key: const Key('homepage-enabled'),
                      title: const Text('Show Upcoming Batches'),
                      value: _batches['enabled'] as bool,
                      onChanged: (value) =>
                          setState(() => _batches['enabled'] = value),
                    ),
                    _text('upcomingBatches', 'title', 'Section title'),
                    _text(
                      'upcomingBatches',
                      'subtitle',
                      'Section subtitle',
                      lines: 3,
                    ),
                    DropdownButtonFormField<int>(
                      key: const Key('homepage-batch-count'),
                      initialValue: _batches['maxBatches'] as int,
                      decoration: const InputDecoration(
                        labelText: 'Maximum date groups',
                      ),
                      items: [
                        for (var count = 1; count <= 12; count++)
                          DropdownMenuItem(value: count, child: Text('$count')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _batches['maxBatches'] = value);
                        }
                      },
                    ),
                    SwitchListTile(
                      key: const Key('homepage-choose-trips'),
                      title: const Text('Choose specific trips'),
                      subtitle: const Text(
                        'Off: automatically use all active trips. On with none selected: show an empty state.',
                      ),
                      value: _batches['tripSelection'] == 'selected',
                      onChanged: (value) => setState(
                        () => _batches['tripSelection'] = value
                            ? 'selected'
                            : 'all',
                      ),
                    ),
                    if (_batches['tripSelection'] == 'selected') ...[
                      for (final trip in _trips.where(
                        (trip) => trip['isActive'] != false,
                      ))
                        CheckboxListTile(
                          key: ValueKey('homepage-trip-${trip['id']}'),
                          title: Text('${trip['title'] ?? trip['id']}'),
                          value: (_batches['tripIds'] as List).contains(
                            trip['id'],
                          ),
                          onChanged: (value) =>
                              _toggleTrip(trip['id'] as String, value == true),
                        ),
                      for (final id in (_batches['tripIds'] as List).where(
                        (id) => !_trips.any(
                          (trip) =>
                              trip['id'] == id && trip['isActive'] != false,
                        ),
                      ))
                        ListTile(
                          title: Text('Unavailable selection: $id'),
                          subtitle: const Text(
                            'Ignored until this trip is active and available.',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove unavailable trip',
                            icon: const Icon(Icons.close),
                            onPressed: () => _toggleTrip(id as String, false),
                          ),
                        ),
                    ],
                    SwitchListTile(
                      key: const Key('homepage-choose-departures'),
                      title: const Text('Choose specific departures'),
                      subtitle: const Text(
                        'Only matching current/upcoming dates appear. Expired dates and inactive trips are always excluded.',
                      ),
                      value: _batches['departureSelection'] == 'selected',
                      onChanged: (value) => setState(
                        () => _batches['departureSelection'] = value
                            ? 'selected'
                            : 'all',
                      ),
                    ),
                    if (_batches['departureSelection'] == 'selected')
                      ..._departureOptions(),
                    const SizedBox(height: 16),
                    Text(
                      'Visible card details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Trip name, date and the trip link always remain available.',
                    ),
                    for (final field in [
                      'price',
                      'status',
                      'weekday',
                      'location',
                      'duration',
                      'difficulty',
                      'image',
                    ])
                      CheckboxListTile(
                        key: ValueKey('homepage-field-$field'),
                        title: Text(
                          field[0].toUpperCase() + field.substring(1),
                        ),
                        value: (_batches['fields'] as Map)[field] as bool,
                        onChanged: (value) => setState(
                          () => (_batches['fields'] as Map)[field] =
                              value == true,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _preview(),
                    const SizedBox(height: 16),
                    DiscoverySettingsEditor(
                      discovery: _draft!['discovery'] as Map<String, dynamic>,
                      onChanged: (field, value) => setState(() {
                        (_draft!['discovery'] as Map)[field] = value;
                      }),
                    ),
                    const SizedBox(height: 16),
                    HomepageSectionsEditor(
                      key: ValueKey(_sectionsRevision),
                      sections: _draft!['sections'] as Map<String, dynamic>,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    FooterSettingsEditor(
                      key: ValueKey('footer-$_sectionsRevision'),
                      footer: _draft!['footer'] as Map<String, dynamic>,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('homepage-publish'),
                      onPressed: _busy || !_targetMatches ? null : _publish,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Publish homepage'),
                    ),
                    if (_savedCommit != null)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeploymentStatusScreen(
                              savedCommitSha: _savedCommit,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.cloud_sync),
                        label: const Text('View homepage deployment'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _departureOptions() {
    final valid = <String>{};
    final widgets = <Widget>[];
    for (final trip in _trips) {
      for (final range in TripDateUtils.getUpcomingDateRanges(
        trip,
        referenceDate: widget.referenceDate,
      )) {
        final key = '${trip['id']}|${range.key}';
        valid.add(key);
        widgets.add(
          CheckboxListTile(
            key: ValueKey('homepage-departure-$key'),
            title: Text('${trip['title']} — ${range.fullLabel}'),
            value: (_batches['departures'] as List).any(
              (item) =>
                  item['tripId'] == trip['id'] &&
                  TripDateUtils.parse(item['date'] as String)?.key == range.key,
            ),
            onChanged: (value) =>
                _toggleDeparture(trip['id'] as String, range, value == true),
          ),
        );
      }
    }
    for (final item in _batches['departures'] as List) {
      final range = TripDateUtils.parse(item['date'] as String)!;
      if (!valid.contains('${item['tripId']}|${range.key}')) {
        widgets.add(
          ListTile(
            title: Text(
              'Unavailable/expired: ${item['tripId']} — ${item['date']}',
            ),
            subtitle: const Text('Not shown on the website.'),
            trailing: IconButton(
              tooltip: 'Remove unavailable departure',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  _toggleDeparture(item['tripId'] as String, range, false),
            ),
          ),
        );
      }
    }
    if (widgets.isEmpty) {
      widgets.add(
        const Text(
          'No current or upcoming dates. Add dates in the trip editor first.',
        ),
      );
    }
    return widgets;
  }

  Widget _preview() {
    try {
      final config = HomepageConfig.parse(jsonEncode(_draft));
      final batches = config.buildBatches(
        _trips,
        referenceDate: widget.referenceDate,
      );
      final fields = _batches['fields'] as Map;
      return Card(
        key: const Key('homepage-preview'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unsaved homepage preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Uses current in-app trip data. Publish trip edits separately before relying on new dates on the live website.',
              ),
              const SizedBox(height: 12),
              Text(
                _hero['title'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(_hero['tagline'] as String),
              Text(_hero['description'] as String),
              Text('Background: ${_hero['backgroundImage']}'),
              if (_batches['enabled'] == false)
                const Text('Upcoming Batches is hidden.')
              else ...[
                Text(_batches['title'] as String),
                Text(_batches['subtitle'] as String),
                if (batches.isEmpty) const Text('New dates coming soon'),
                for (final batch in batches) ...[
                  const Divider(),
                  Text(
                    batch.dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (fields['weekday'] == true) Text(batch.weekdayLabel),
                  for (final trip in batch.trips) ...[
                    Text(trip.title),
                    if (fields['price'] == true) Text('${trip.price ?? ''}'),
                    if (fields['status'] == true) const Text('Upcoming'),
                    for (final field in ['location', 'duration', 'difficulty'])
                      if (fields[field] == true)
                        Text(
                          '${_trips.firstWhere((item) => item['id'] == trip.id)[field] ?? ''}',
                        ),
                    if (fields['image'] == true)
                      const Text('Trip thumbnail enabled'),
                  ],
                ],
              ],
            ],
          ),
        ),
      );
    } catch (error) {
      return Text('Preview unavailable: $error');
    }
  }
}
