import '../widgets/manager_page_layout.dart';
import '../widgets/website_pages_editor.dart';
import '../services/google_review_service.dart';
import '../widgets/local_draft.dart';
import '../widgets/change_review.dart';
import '../services/workspace_changes.dart';
import '../services/draft_store.dart';
import '../widgets/departure_selection_editor.dart';
import '../widgets/draft_preview.dart';
import 'manager_tools_screen.dart';
import '../widgets/manager_navigation.dart';
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
import '../widgets/story_highlights_editor.dart';
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

class _HomepageSettingsScreenState extends State<HomepageSettingsScreen>
    with LocalDraft<HomepageSettingsScreen> {
  @override
  String get localScope => DraftStore.scope(_target);
  @override
  String get localSlot => 'homepage';
  @override
  Map<String, dynamic>? get currentDocument => _draft;
  @override
  bool get draftBusy => _busy;
  @override
  void applyDocument(Map<String, dynamic> value) {
    _draft = HomepageConfig.parse(jsonEncode(value)).toJson();
    _sectionsRevision++;
    for (final entry in _controllers.entries) {
      final parts = entry.key.split('.');
      entry.value.text =
          (_draft![parts.first] as Map)[parts.last]?.toString() ?? '';
    }
  }

  String _group = 'All';
  final _anchors = <String, GlobalKey>{};
  final _fieldFocus = <String, FocusNode>{};
  Widget _websiteSubsections(List<String> sections) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final section in sections)
        ChoiceChip(
          label: Text(section == 'Calendar' ? 'Calendar holidays' : section),
          selected: _group == section,
          onSelected: (_) => setState(() => _group = section),
        ),
    ],
  );

  Future<void> _searchFields() async {
    final choices = {
      'Trip display order and sorting': 'Trip order',
      'Calendar holidays and special dates': 'Calendar',
      'Instagram story highlights and covers': 'Story highlights',
      'Desktop cover': 'Hero|hero.backgroundImage',
      'Headline': 'Hero|hero.title',
      'Tagline': 'Hero|hero.tagline',
      'Description': 'Hero|hero.description',
      'Mobile cover and crop': 'Appearance|presentation.heroMobileImage',
      'Website animations and colours': 'Appearance',
      'Date chips, trip cards and mobile tab colours': 'Appearance',
      'Trip photo slideshow and timing': 'Trip gallery',
      'About and Contact pages, banner headings and navigation': 'Pages',
      'Upcoming trips and date selection': 'Upcoming Batches',
      'Trip discovery and Featured visibility': 'Destinations',
      'Explore Destinations automatic slideshow and timing': 'Destinations',
      'Statistics, How it works, Why choose us': 'Information',
      'Google Reviews and rating': 'Reviews',
      'Footer, contact, social links, UPI visibility': 'Footer',
    };
    String query = '';
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Find a website field'),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Search fields'),
                  onChanged: (v) => set(() => query = v),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in choices.entries.where(
                        (e) =>
                            e.key.toLowerCase().contains(query.toLowerCase()),
                      ))
                        ListTile(
                          title: Text(entry.key),
                          onTap: () => Navigator.pop(ctx, entry.value),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final parts = choice.split('|');
    setState(() => _group = parts.first);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted || !_homeScroll.hasClients) return;
    _homeScroll.jumpTo(0);
    if (parts.length < 2) return;
    for (var i = 0; i < 30 && mounted && _group == parts.first; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!mounted || !_homeScroll.hasClients) return;
      final ctx = _anchors[parts.last]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx);
        _fieldFocus[parts.last]?.requestFocus();
        return;
      }
      final next = (_homeScroll.offset + 160).clamp(
        0.0,
        _homeScroll.position.maxScrollExtent,
      );
      if (next == _homeScroll.offset) return;
      _homeScroll.jumpTo(next);
    }
  }

  final _homeScroll = ScrollController();

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
        startLocalDraft(_draft!);
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
    _homeScroll.dispose();
    for (final node in _fieldFocus.values) node.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (await leaveLocalDraft() && mounted) {
      setState(() => _allowExit = true);
      Navigator.pop(context);
    }
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

  Map<String, dynamic> _publicationDocument() {
    if (_group == 'All') return copyDocument(_draft!);
    final result = copyDocument(jsonDecode(_saved!) as Map);
    final keys = switch (_group) {
      'Hero' => ['hero'],
      'Story highlights' => ['storyHighlights'],
      'Appearance' => ['presentation'],
      'Trip gallery' => ['tripGallery'],
      'Pages' => ['pages'],
      'Upcoming Batches' => ['upcomingBatches'],
      'Calendar' => ['calendarHolidays'],
      'Trip order' => ['tripDisplayOrder'],
      'Destinations' => ['discovery', 'destinationSlider'],
      'Footer' => ['footer'],
      _ => <String>[],
    };
    for (final key in keys) result[key] = copyDocument(_draft!)[key];
    if (_group == 'Information' || _group == 'Reviews') {
      for (final key
          in _group == 'Reviews'
              ? ['reviews']
              : ['stats', 'howItWorks', 'whyChooseUs', 'cta'])
        result['sections'][key] = copyDocument(_draft!)['sections'][key];
    }
    return result;
  }

  Future<void> _publish() async {
    if (_busy || !_targetMatches || _draft == null) return;
    HomepageConfig config;
    try {
      config = HomepageConfig.parse(jsonEncode(_publicationDocument()));
    } catch (error) {
      setState(() => _error = error.toString());
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish homepage?'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ChangeReview(
                  changes: WorkspaceChanges.diff(
                    jsonDecode(_saved!),
                    _publicationDocument(),
                  ),
                ),
                Text(
                  'Publish homepage settings to ${_target.repositoryOwner}/${_target.repositoryName} (${_target.branch})? Trip data, booking links and payment settings are not changed.',
                ),
              ],
            ),
          ),
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
    final previous = copyDocument(jsonDecode(_saved!) as Map);
    final retained = copyDocument(_draft!);
    final result = await _service.save(config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) {
        final published = _service.savedConfig!.toJson();
        _saved = jsonEncode(published);
        _draft = recoverDocument(previous, retained, published);
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
      await publishedLocalDraft(
        previous,
        Map<String, dynamic>.from(jsonDecode(_saved!) as Map),
      );
      await saveLocalDraft();
      await DraftStore.recordPublication(localScope, _savedCommit);
      if (!mounted) return;
    }
  }

  Future<void> _upload({
    String group = 'hero',
    String field = 'backgroundImage',
  }) async {
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
                tripId: field == 'heroMobileImage'
                    ? 'homepage_mobile'
                    : 'homepage',
                isMainImage: true,
              );
          if (!result.success) {
            throw StateError(result.error ?? 'Image upload failed.');
          }
          path = result.imagePath;
          final advice = await photoResolutionAdvice(
            File(image.path),
            minWidth: field == 'heroMobileImage' ? 1080 : 1600,
          );
          if (advice != null && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(advice)));
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
      key: _anchors.putIfAbsent('$group.$field', () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        focusNode: _fieldFocus.putIfAbsent('$group.$field', () => FocusNode()),
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

  static const _orderViews = {
    'explore': 'Explore Trips',
    'weekend': 'This Week',
    'all': 'All Departures',
  };

  Widget _tripOrderSection() {
    final orders = _draft!['tripDisplayOrder'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set the recommended order for each list. New trips appear after your chosen order.',
        ),
        const SizedBox(height: 8),
        for (final entry in _orderViews.entries)
          Card(
            child: ListTile(
              title: Text(entry.value),
              subtitle: Text(switch (entry.key) {
                'explore' => 'All trips in the homepage carousel',
                'weekend' => 'Only departures for the current weekend',
                _ => 'All trips, including trips without dates',
              }),
              leading: Icon(switch (entry.key) {
                'explore' => Icons.explore_outlined,
                'weekend' => Icons.event_outlined,
                _ => Icons.route_outlined,
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: _trips.isEmpty
                  ? null
                  : () => _editTripOrder(entry.key, entry.value),
            ),
          ),
        if (_trips.isEmpty)
          const Text('Load your trips before setting a display order.'),
      ],
    );
  }

  Future<void> _editTripOrder(String key, String label) async {
    final orders = _draft!['tripDisplayOrder'] as Map<String, dynamic>;
    final titles = {
      for (final trip in _trips)
        if (trip['id'] case final String id)
          id: (trip['title'] ?? trip['name'] ?? id).toString(),
    };
    final existing = (orders[key] as List).whereType<String>().where(
      titles.containsKey,
    );
    final ids = <String>{...existing, ...titles.keys}.toList();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void move(int from, int to) => update(() {
            final id = ids.removeAt(from);
            ids.insert(to, id);
          });
          return AlertDialog(
            title: Text(label),
            content: SizedBox(
              width: 520,
              height: 420,
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: ids.length,
                onReorder: (from, to) => move(from, to > from ? to - 1 : to),
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final title = titles[id]!;
                  return ListTile(
                    key: ValueKey(id),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move $title up',
                          onPressed: index > 0
                              ? () => move(index, index - 1)
                              : null,
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'Move $title down',
                          onPressed: index + 1 < ids.length
                              ? () => move(index, index + 1)
                              : null,
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, <String>[]),
                child: const Text('Use workspace order'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ids),
                child: const Text('Apply order'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && result != null) setState(() => orders[key] = result);
  }

  Widget _calendarHolidaySection() {
    final holidays = (_draft!['calendarHolidays'] as List).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mark holidays and special occasions on the departure calendar.',
        ),
        const SizedBox(height: 8),
        for (final holiday in holidays)
          ListTile(
            title: Text(holiday['name'] as String),
            subtitle: Text(holiday['date'] as String),
            contentPadding: EdgeInsets.zero,
            trailing: IconButton(
              tooltip: 'Remove ${holiday['name']}',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                _draft!['calendarHolidays'] = holidays
                    .where((item) => item['date'] != holiday['date'])
                    .toList();
              }),
            ),
            onTap: () => _editHoliday(existing: holiday),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _editHoliday,
            icon: const Icon(Icons.add),
            label: const Text('Add holiday'),
          ),
        ),
      ],
    );
  }

  Future<void> _editHoliday({Map? existing}) async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(existing?['date']?.toString() ?? '') ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2020 ? initial.year : 2020),
      lastDate: DateTime(
        (initial.year > now.year ? initial.year : now.year) + 10,
        12,
        31,
      ),
      helpText: 'Choose a holiday date',
    );
    if (!mounted || date == null) return;
    final key = date.toIso8601String().substring(0, 10);
    final controller = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Holiday on $key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Holiday name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save holiday'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    setState(() {
      final holidays = [
        for (final item in (_draft!['calendarHolidays'] as List).cast<Map>())
          if (item['date'] != key && item['date'] != existing?['date']) item,
        {'date': key, 'name': name},
      ]..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      _draft!['calendarHolidays'] = holidays;
    });
  }

  Widget _partColourEditor() {
    final values = _draft!['presentation']['partColours'] as Map;
    const choices = {
      'default': ('Site default', Color(0xff657b70)),
      'teal': ('Teal', Color(0xff0b6259)),
      'blue': ('Blue', Color(0xff254f82)),
      'purple': ('Purple', Color(0xff593984)),
      'orange': ('Burnt orange', Color(0xff904017)),
      'gold': ('Gold', Color(0xffdbab37)),
      'rose': ('Rose', Color(0xff8c3555)),
      'green': ('Forest green', Color(0xff245c33)),
    };
    const groups = {
      'Departure dates': {
        'dateFirst': 'First date',
        'dateSecond': 'Second date',
        'dateThird': 'Third date',
      },
      'Trip card': {
        'cardPrice': 'Trip price',
        'cardDetails': 'View trip button',
        'cardHelp': 'Help me choose button',
      },
      'Mobile tabs': {
        'navHome': 'Home',
        'navWeekend': 'This Week',
        'navCalendar': 'Calendar',
        'navAll': 'All Departures',
        'navWhatsapp': 'WhatsApp',
      },
    };
    return Column(
      children: [
        for (final group in groups.entries)
          ExpansionTile(
            leading: Icon(switch (group.key) {
              'Departure dates' => Icons.event_outlined,
              'Trip card' => Icons.style_outlined,
              _ => Icons.navigation_outlined,
            }),
            title: Text(group.key),
            subtitle: Text(switch (group.key) {
              'Departure dates' => 'Colour the next three date chips',
              'Trip card' => 'Price and action button colours',
              _ => 'Home, This Week, Calendar, All Departures and WhatsApp',
            }),
            children: [
              for (final part in group.value.entries)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'part-colour-${part.key}-${values[part.key]}',
                    ),
                    initialValue: values[part.key] as String,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: part.value,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final choice in choices.entries)
                        DropdownMenuItem(
                          value: choice.key,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 14,
                                color: choice.value.$2,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(choice.value.$1)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => values[part.key] = value);
                    },
                  ),
                ),
            ],
          ),
      ],
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
    final url = path.startsWith('https://')
        ? path
        : 'https://raw.githubusercontent.com/' +
              _target.repositoryOwner +
              '/' +
              _target.repositoryName +
              '/' +
              _target.branch +
              '/' +
              path;
    final focus =
        _draft!['presentation'][ratio < 1
            ? 'heroMobileFocalPoint'
            : 'heroFocalPoint'];
    final alignment = switch (focus) {
      'top' => Alignment.topCenter,
      'bottom' => Alignment.bottomCenter,
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(label),
          AspectRatio(
            aspectRatio: ratio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.imagePreviewBuilder?.call(url) ??
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        alignment: alignment,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      'Your next weekend starts here',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          title: const Text('Website content & appearance'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _searchFields,
              tooltip: 'Find a website field',
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Reload homepage',
              onPressed: _busy || !_targetMatches ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: _draft == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ((MediaQuery.sizeOf(context).width - 960) / 2).clamp(
                      16.0,
                      double.infinity,
                    ),
                    8,
                    ((MediaQuery.sizeOf(context).width - 960) / 2).clamp(
                      16.0,
                      double.infinity,
                    ),
                    12,
                  ),
                  child: FilledButton.icon(
                    key: const Key('homepage-publish'),
                    onPressed: _busy || !_targetMatches ? null : _publish,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      _group == 'All'
                          ? 'Review & publish homepage'
                          : 'Review & publish $_group only',
                    ),
                  ),
                ),
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
                  key: const Key('homepage-editor-scroll'),
                  controller: _homeScroll,
                  padding: EdgeInsets.symmetric(
                    horizontal: ((MediaQuery.sizeOf(context).width - 960) / 2)
                        .clamp(16.0, double.infinity),
                    vertical: 16,
                  ),
                  children: [
                    localDraftBar(),
                    ManagerSectionPicker(
                      sections: const [
                        'All',
                        'Hero',
                        'Appearance',
                        'Upcoming Batches',
                        'Destinations',
                        'Information',
                        'Reviews',
                        'Footer',
                        'Pages',
                        'Trip gallery',
                      ],
                      selected: switch (_group) {
                        'Story highlights' => 'Hero',
                        'Calendar' => 'Upcoming Batches',
                        'Trip order' => 'Destinations',
                        _ => _group,
                      },
                      onChanged: (group) => setState(() => _group = group),
                    ),
                    if (['Hero', 'Story highlights'].contains(_group))
                      _websiteSubsections(['Hero', 'Story highlights']),
                    if (['Upcoming Batches', 'Calendar'].contains(_group))
                      _websiteSubsections(['Upcoming Batches', 'Calendar']),
                    if (['Destinations', 'Trip order'].contains(_group))
                      _websiteSubsections(['Destinations', 'Trip order']),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Draft website preview'),
                            ),
                            body: DraftPreview(
                              settings: _target,
                              homepage: _draft,
                              trips: _trips,
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.preview),
                      label: const Text('Mobile & desktop website preview'),
                    ),
                    if (_busy) const LinearProgressIndicator(),
                    const Text(
                      'Choose a section to edit. Save a draft while you work, then review and publish your changes. Appearance controls apply across the website.',
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
                    if (_group == 'Story highlights')
                      StoryHighlightsEditor(
                        value: _draft!['storyHighlights'] as Map<String, dynamic>,
                        onChanged: (value) => setState(() => _draft!['storyHighlights'] = value),
                      ),
                    if (_group == 'All' || _group == 'Hero') ...[
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
                        label: const Text('Upload desktop cover · 16:7'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          final photo = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManagerToolsScreen(
                                tool: ManagerDestination.library,
                                choosePhoto: true,
                              ),
                            ),
                          );
                          if (photo != null && mounted)
                            setState(() {
                              _hero['backgroundImage'] = photo;
                              _controllers['hero.backgroundImage']?.text =
                                  photo;
                            });
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose from photo library'),
                      ),
                      _text('hero', 'title', 'Headline', lines: 3),
                      _text('hero', 'tagline', 'Tagline', lines: 3),
                      _text('hero', 'description', 'Description', lines: 3),
                    ],
                    if (_group == 'All' || _group == 'Appearance') ...[
                      if (_group == 'Appearance')
                        Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.palette_outlined),
                            title: const Text('Card and tab colours'),
                            subtitle: const Text(
                              'Choose colours for individual website elements',
                            ),
                            initiallyExpanded: true,
                            children: [_partColourEditor()],
                          ),
                        ),
                      ExpansionTile(
                        title: const Text('Colours, photos & animations'),
                        initiallyExpanded: _group == 'Appearance',
                        children: [
                          SwitchListTile(
                            title: const Text('Use desktop cover on mobile'),
                            value:
                                (_draft!['presentation']['heroMobileImage']
                                        as String)
                                    .isEmpty,
                            onChanged: (v) {
                              if (v) {
                                setState(() {
                                  _draft!['presentation']['heroMobileImage'] =
                                      '';
                                  _controllers['presentation.heroMobileImage']
                                          ?.text =
                                      '';
                                });
                              } else {
                                _upload(
                                  group: 'presentation',
                                  field: 'heroMobileImage',
                                );
                              }
                            },
                          ),
                          DropdownButtonFormField<String>(
                            key: const Key('homepage-presentation-preset'),
                            initialValue:
                                _draft!['presentation']['preset'] as String,
                            decoration: const InputDecoration(
                              labelText: 'Colour palette',
                            ),
                            items: [
                              for (final preset in ['forest', 'ocean', 'earth'])
                                DropdownMenuItem(
                                  value: preset,
                                  child: Text(preset),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _draft!['presentation']['preset'] = value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _text(
                            'presentation',
                            'heroMobileImage',
                            'Mobile hero photo (optional path or HTTPS URL)',
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _upload(
                                    group: 'presentation',
                                    field: 'heroMobileImage',
                                  ),
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Upload mobile hero photo'),
                          ),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'desktop-focus-' +
                                  _draft!['presentation']['heroFocalPoint']
                                      .toString(),
                            ),
                            initialValue:
                                _draft!['presentation']['heroFocalPoint']
                                    as String,
                            decoration: const InputDecoration(
                              labelText: 'Desktop hero photo focus',
                            ),
                            items: [
                              for (final focus in [
                                'center',
                                'top',
                                'bottom',
                                'left',
                                'right',
                              ])
                                DropdownMenuItem(
                                  value: focus,
                                  child: Text(focus),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _draft!['presentation']['heroFocalPoint'] =
                                  value,
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'mobile-focus-' +
                                  _draft!['presentation']['heroMobileFocalPoint']
                                      .toString(),
                            ),
                            initialValue:
                                _draft!['presentation']['heroMobileFocalPoint']
                                    as String,
                            decoration: const InputDecoration(
                              labelText: 'Mobile hero photo focus',
                            ),
                            items: [
                              for (final focus in [
                                'center',
                                'top',
                                'bottom',
                                'left',
                                'right',
                              ])
                                DropdownMenuItem(
                                  value: focus,
                                  child: Text(focus),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () =>
                                  _draft!['presentation']['heroMobileFocalPoint'] =
                                      value,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _draft!['presentation']['heroFocalPoint'] =
                                  'center';
                              _draft!['presentation']['heroMobileFocalPoint'] =
                                  'center';
                            }),
                            child: const Text('Reset both crops to centre'),
                          ),
                          TextFormField(
                            key: const Key('homepage-hero-slides'),
                            initialValue:
                                (_draft!['presentation']['heroSlides'] as List)
                                    .join('\n'),
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText:
                                  'Additional hero photos (up to 2, one path per line)',
                            ),
                            onChanged: (value) => setState(
                              () =>
                                  _draft!['presentation']['heroSlides'] = value
                                      .split('\n')
                                      .map((line) => line.trim())
                                      .where((line) => line.isNotEmpty)
                                      .toList(),
                            ),
                          ),
                          SwitchListTile(
                            key: const Key('website-animations-enabled'),
                            title: const Text('Website animations'),
                            subtitle: const Text(
                              'Subtle transitions and effects. Reduced-motion preferences are always respected. Photo slideshow controls are separate.',
                            ),
                            value:
                                _draft!['presentation']['animationsEnabled']
                                    as bool,
                            onChanged: (value) => setState(
                              () =>
                                  _draft!['presentation']['animationsEnabled'] =
                                      value,
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Slow hero photo crossfade'),
                            subtitle: const Text(
                              'One pass only. Text stays still; reduced motion uses one photo.',
                            ),
                            value:
                                _draft!['presentation']['heroMotion'] as bool,
                            onChanged: (value) => setState(
                              () =>
                                  _draft!['presentation']['heroMotion'] = value,
                            ),
                          ),
                          const Text(
                            'Desktop hero 16:7 — 1600×700 px. Mobile hero 4:5 — 1080×1350 px. Trip cards 16:9 — 1600×900 px. Gallery 4:3 — 1600×1200 px. Keep faces and text away from crop edges. Original photos are retained.',
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _cropPreview(
                                _hero['backgroundImage'] as String,
                                16 / 7,
                                'Desktop hero',
                                300,
                              ),
                              _cropPreview(
                                (_draft!['presentation']['heroMobileImage']
                                            as String)
                                        .isEmpty
                                    ? _hero['backgroundImage'] as String
                                    : _draft!['presentation']['heroMobileImage']
                                          as String,
                                4 / 5,
                                'Mobile hero',
                                160,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_group == 'All' || _group == 'Upcoming Batches') ...[
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
                      DepartureSelectionEditor(
                        draft: _draft!,
                        trips: _trips,
                        referenceDate: widget.referenceDate,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    if (_group == 'All' || _group == 'Upcoming Batches')
                      _preview(),
                    if (_group == 'All' || _group == 'Calendar')
                      ExpansionTile(
                        title: const Text('Calendar holidays'),
                        initiallyExpanded: _group == 'Calendar',
                        children: [_calendarHolidaySection()],
                      ),
                    if (_group == 'All' || _group == 'Trip order')
                      ExpansionTile(
                        title: const Text('Trip display order'),
                        initiallyExpanded: _group == 'Trip order',
                        children: [_tripOrderSection()],
                      ),
                    if (_group == 'Destinations')
                      const ListTile(
                        title: Text('Explore Destinations'),
                        subtitle: Text(
                          'Use Trip display order to arrange the three lists. Collections use each trip’s experience and duration.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_group == 'All' || _group == 'Destinations')
                      DiscoverySettingsEditor(
                        discovery: _draft!['discovery'] as Map<String, dynamic>,
                        onChanged: (field, value) => setState(() {
                          (_draft!['discovery'] as Map)[field] = value;
                        }),
                      ),
                    const SizedBox(height: 16),
                    if (_group == 'All' ||
                        _group == 'Information' ||
                        _group == 'Reviews')
                      HomepageSectionsEditor(
                        loadGoogleReviews: () =>
                            GoogleReviewService(_service.github).check(),
                        onlySections: _group == 'Reviews'
                            ? {'reviews'}
                            : _group == 'Information'
                            ? {'stats', 'howItWorks', 'whyChooseUs', 'cta'}
                            : null,
                        key: ValueKey(_sectionsRevision),
                        sections: _draft!['sections'] as Map<String, dynamic>,
                        onChanged: () => setState(() {}),
                      ),
                    const SizedBox(height: 16),
                    if (_group == 'All' || _group == 'Footer')
                      FooterSettingsEditor(
                        key: ValueKey('footer-$_sectionsRevision'),
                        footer: _draft!['footer'] as Map<String, dynamic>,
                        initiallyExpanded: _group == 'Footer',
                        onChanged: () => setState(() {}),
                      ),
                    const SizedBox(height: 16),
                    if (_group == 'All' || _group == 'Pages')
                      WebsitePagesEditor(
                        key: ValueKey('website-pages-$_sectionsRevision'),
                        pages: _draft!['pages'] as Map<String, dynamic>,
                        initiallyExpanded: _group == 'Pages',
                        onChanged: () => setState(() {}),
                      ),
                    if (_group == 'All' || _group == 'Destinations') ...[
                      Text(
                        'Explore Destinations slideshow',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Automatically browse homepage destination cards. Visitors can still swipe, use arrows or pause.',
                      ),
                      SwitchListTile(
                        key: const Key('destination-auto-slide'),
                        title: const Text(
                          'Automatically slide destination cards',
                        ),
                        value:
                            _draft!['destinationSlider']['autoSlide'] as bool,
                        onChanged: (value) => setState(() {
                          _draft!['destinationSlider']['autoSlide'] = value;
                        }),
                      ),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'destination-interval-${_draft!['destinationSlider']['intervalSeconds']}',
                        ),
                        initialValue:
                            _draft!['destinationSlider']['intervalSeconds']
                                as int,
                        decoration: const InputDecoration(
                          labelText: 'Time per destination',
                        ),
                        items: [
                          for (var seconds = 3; seconds <= 30; seconds++)
                            DropdownMenuItem(
                              value: seconds,
                              child: Text('$seconds seconds'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _draft!['destinationSlider']['intervalSeconds'] =
                                  value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_group == 'All' || _group == 'Trip gallery') ...[
                      Text(
                        'Trip gallery',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Automatic photo sliding on every trip page. Saved gallery order is used.',
                      ),
                      SwitchListTile(
                        key: const Key('gallery-auto-slide'),
                        title: const Text('Automatically slide photos'),
                        value: _draft!['tripGallery']['autoSlide'] as bool,
                        onChanged: (value) => setState(() {
                          _draft!['tripGallery']['autoSlide'] = value;
                        }),
                      ),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'gallery-interval-${_draft!['tripGallery']['intervalSeconds']}',
                        ),
                        initialValue:
                            _draft!['tripGallery']['intervalSeconds'] as int,
                        decoration: const InputDecoration(
                          labelText: 'Time per photo',
                        ),
                        items: [
                          for (var seconds = 3; seconds <= 30; seconds++)
                            DropdownMenuItem(
                              value: seconds,
                              child: Text('$seconds seconds'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _draft!['tripGallery']['intervalSeconds'] = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
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

  Widget _preview() {
    try {
      final config = HomepageConfig.parse(jsonEncode(_draft));
      final batches = TripDateUtils.buildUpcomingBatches(
        config.selectedTrips(_trips, referenceDate: widget.referenceDate),
        referenceDate: widget.referenceDate,
        limit: 1000000,
      );
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
                  for (final trip in batch.trips) Text(trip.title),
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
