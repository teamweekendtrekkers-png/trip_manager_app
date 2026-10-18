import 'package:flutter/material.dart';
import 'trip_price.dart';
import '../models/trip_card_settings.dart';
import '../services/trip_date_utils.dart';

/// A draft-only editor. Uploads add an asset; normal trip publication applies it.
class TripCardSettingsEditor extends StatefulWidget {
  const TripCardSettingsEditor({
    super.key,
    required this.trip,
    required this.onChanged,
    this.onUploadCover,
    this.onChooseCover,
    this.imagePreviewBuilder,
    this.referenceDate,
  });

  final Map<String, dynamic> trip;
  final void Function(String field, Object? value) onChanged;
  final Future<String?> Function()? onUploadCover;
  final VoidCallback? onChooseCover;
  final Widget Function(String path)? imagePreviewBuilder;
  final DateTime? referenceDate;

  @override
  State<TripCardSettingsEditor> createState() => _TripCardSettingsEditorState();
}

class _TripCardSettingsEditorState extends State<TripCardSettingsEditor> {
  final _controllers = <String, TextEditingController>{};
  bool _uploading = false;
  String? _uploadError;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TripCardSettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Synchronizing a controller during Form layout can mark its ancestor
    // dirty while the child is building. Use the latest value after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final entry in _controllers.entries) {
        final next = '${widget.trip[entry.key] ?? ''}';
        if (entry.value.text != next) entry.value.text = next;
      }
    });
  }

  Widget _text(String field, String label, String hint, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('trip-card-$field'),
        controller: _controllers.putIfAbsent(
          field,
          () => TextEditingController(text: '${widget.trip[field] ?? ''}'),
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        minLines: 1,
        maxLines: lines,
        validator: (value) => TripCardSettings.fieldError(
          field,
          widget.trip.containsKey(field) && widget.trip[field] is! String
              ? widget.trip[field]
              : value ?? '',
        ),
        onChanged: (value) => widget.onChanged(field, value),
      ),
    );
  }

  Future<void> _upload() async {
    if (_uploading || widget.onUploadCover == null) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final path = await widget.onUploadCover!();
      if (!mounted || path == null) return;
      final error = TripCardSettings.fieldError('cardImage', path);
      if (error != null) throw FormatException(error);
      _controllers['cardImage']?.text = path;
      widget.onChanged('cardImage', path);
    } catch (error) {
      if (mounted) setState(() => _uploadError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnings = TripCardSettings.qualityWarnings(
      widget.trip,
      referenceDate: widget.referenceDate,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Website trip card',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a clear photograph for cards. Posters can stay in the gallery or brochure. '
              'These optional fields do not change prices, dates or booking rules.',
            ),
            const SizedBox(height: 16),
            _text(
              'cardImage',
              'Card cover path or HTTPS URL',
              'Optional. Leave blank to use the display image.',
            ),
            if (widget.onChooseCover != null)
              TextButton.icon(
                onPressed: widget.onChooseCover,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from photo library'),
              ),
            if (widget.onUploadCover != null)
              OutlinedButton.icon(
                key: const Key('trip-card-upload'),
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  _uploading ? 'Uploading cover…' : 'Upload card cover',
                ),
              ),
            if (_uploadError != null)
              Text(
                _uploadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            _text(
              'cardTitle',
              'Short display title',
              'Optional; full trip name remains on details',
            ),
            _text(
              'cardSummary',
              'Short card highlight',
              'Optional, up to 160 characters. Describe the experience without promises you cannot verify.',
              lines: 3,
            ),
            _text(
              'departureCity',
              'Departure city',
              'Optional, up to 80 characters. Enter the actual departure city.',
            ),
            FormField<String>(
              key: const Key('trip-card-experience'),
              validator: (_) {
                if (widget.trip.containsKey('experience')) {
                  final error = TripCardSettings.fieldError('experience', widget.trip['experience']);
                  if (error != null) return error;
                }
                final errors = TripCardSettings.validationErrors(widget.trip);
                return errors.isEmpty ? null : errors.first;
              },
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Experience categories', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Choose all that apply. No selection uses Other experiences on the website.'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final entry in TripCardSettings.experiences.entries)
                      FilterChip(
                        key: ValueKey('trip-card-experience-${entry.key}'),
                        label: Text(entry.value),
                        selected: TripCardSettings.selectedExperiencesFor(widget.trip).contains(entry.key),
                        onSelected: (selected) {
                          final values = [...TripCardSettings.selectedExperiencesFor(widget.trip)];
                          if (selected) { values.add(entry.key); } else { values.remove(entry.key); }
                          widget.onChanged('experience', null);
                          widget.onChanged('experiences', values);
                        },
                      ),
                  ]),
                  if (state.hasError)
                    Text(state.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
            SwitchListTile.adaptive(
              key: const Key('trip-card-bestseller'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Bestseller'),
              subtitle: const Text('Show a Bestseller badge on this trip’s website card.'),
              value: widget.trip['isBestseller'] == true,
              onChanged: (value) => widget.onChanged('isBestseller', value),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Photo crops and focus'),
              children: [
                TextButton(
                  onPressed: () {
                    widget.onChanged('cardFocalPoint', 'center');
                    widget.onChanged('imageFocalPoint', 'center');
                  },
                  child: const Text('Reset crops to centre'),
                ),
                const Text(
                  'Card: 16:9 · 1600×900 px. Gallery: 4:3 · 1600×1200 px. Original photographs remain fully viewable.',
                ),
                for (final field in ['cardFocalPoint', 'imageFocalPoint'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('trip-card-$field'),
                      initialValue:
                          [
                            'center',
                            'top',
                            'bottom',
                            'left',
                            'right',
                          ].contains(widget.trip[field])
                          ? widget.trip[field] as String
                          : 'center',
                      decoration: InputDecoration(
                        labelText: field == 'cardFocalPoint'
                            ? 'Card photo focus (16:9)'
                            : 'Gallery photo focus (4:3 on mobile)',
                      ),
                      items: [
                        for (final focus in [
                          'center',
                          'top',
                          'bottom',
                          'left',
                          'right',
                        ])
                          DropdownMenuItem(value: focus, child: Text(focus)),
                      ],
                      onChanged: (value) => widget.onChanged(field, value),
                    ),
                  ),
                const Text(
                  'Keep the subject clear in the centre or choose its position. Original uploads are retained; the website generates smaller WebP photos when published.',
                ),
              ],
            ),
            const Text('Unsaved mobile card preview'),
            const SizedBox(height: 8),
            TripCardPreview(
              trip: widget.trip,
              referenceDate: widget.referenceDate,
              imagePreviewBuilder: widget.imagePreviewBuilder,
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Content suggestions (do not block saving)'),
              for (var index = 0; index < warnings.length; index++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '• ${warnings[index]}',
                    key: ValueKey('trip-card-warning-$index'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class TripCardPreview extends StatelessWidget {
  const TripCardPreview({
    super.key,
    required this.trip,
    this.referenceDate,
    this.imagePreviewBuilder,
  });
  final Map<String, dynamic> trip;
  final DateTime? referenceDate;
  final Widget Function(String path)? imagePreviewBuilder;

  @override
  Widget build(BuildContext context) {
    final cover = TripCardSettings.coverFor(trip);
    final dates = TripDateUtils.getUpcomingDateRanges(
      trip,
      referenceDate: referenceDate,
    );
    final summary = '${trip['cardSummary'] ?? ''}'.trim();
    final location = '${trip['location'] ?? trip['destination'] ?? ''}'.trim();
    final departure = '${trip['departureCity'] ?? ''}'.trim();
    final details = [
      if ('${trip['duration'] ?? ''}'.trim().isNotEmpty) '${trip['duration']}',
      if (departure.isNotEmpty) 'From $departure',
      if ('${trip['difficulty'] ?? ''}'.trim().isNotEmpty)
        '${trip['difficulty']}',
    ];
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          key: const Key('trip-card-preview'),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover.isNotEmpty && imagePreviewBuilder != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imagePreviewBuilder!(cover),
                )
              else
                const SizedBox(
                  height: 140,
                  child: Center(child: Icon(Icons.landscape, size: 48)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in TripCardSettings.selectedExperiencesFor(trip))
                      if (category != 'other')
                        Text(TripCardSettings.experiences[category]!),
                    if (trip['isBestseller'] == true)
                      const Chip(
                        label: Text('Bestseller'),
                        backgroundColor: Color(0xFFFFF0BA),
                        labelStyle: TextStyle(color: Color(0xFF713F12)),
                      ),
                    Text(
                      '${trip['cardTitle'] ?? trip['title'] ?? trip['name'] ?? 'Trip name'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (location.isNotEmpty) Text(location),
                    if (summary.isNotEmpty) Text(summary),
                    if (details.isNotEmpty) Text(details.join(' · ')),
                    const SizedBox(height: 8),
                    Text(
                      dates.isEmpty
                          ? 'New dates coming soon'
                          : dates.first.fullLabel,
                    ),
                    if ('${trip['price'] ?? ''}'.isNotEmpty)
                      if (TripPrice.hasDiscount(trip))
                        TripPrice(trip: trip)
                      else
                        Text('${trip['price']} per person'),
                    const SizedBox(height: 8),
                    const Text('View Dates & Details →'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
