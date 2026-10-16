import 'package:flutter/material.dart';
import '../models/trip_content_settings.dart';
import 'trip_price.dart';
import '../models/app_settings.dart';
import '../models/homepage_config.dart';
import '../services/trip_date_utils.dart';
import 'dart:convert';

class DraftPreview extends StatefulWidget {
  const DraftPreview({
    super.key,
    required this.settings,
    this.trip,
    this.homepage,
    this.trips = const [],
    this.sharedContent,
  });
  final AppSettings settings;
  final Map<String, dynamic>? trip, homepage, sharedContent;
  final List<Map<String, dynamic>> trips;
  @override
  State<DraftPreview> createState() => _DraftPreviewState();
}

class _DraftPreviewState extends State<DraftPreview> {
  bool mobile = true;
  String _photo(String image) => image.startsWith('https://')
      ? image
      : 'https://raw.githubusercontent.com/${widget.settings.repositoryOwner}/${widget.settings.repositoryName}/${widget.settings.branch}/$image';
  Widget image(String? photo, double ratio, {String focus = 'center'}) =>
      AspectRatio(
        aspectRatio: ratio,
        child: photo == null || photo.isEmpty
            ? const ColoredBox(
                color: Color(0xffeaf6f3),
                child: Icon(Icons.photo_outlined),
              )
            : Image.network(
                _photo(photo),
                fit: BoxFit.cover,
                alignment: switch (focus) {
                  'top' => Alignment.topCenter,
                  'bottom' => Alignment.bottomCenter,
                  'left' => Alignment.centerLeft,
                  'right' => Alignment.centerRight,
                  _ => Alignment.center,
                },
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('Photo unavailable')),
              ),
      );
  Widget text(String value, {bool heading = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      value,
      style: TextStyle(
        fontSize: heading ? 22 : 16,
        fontWeight: heading ? FontWeight.bold : null,
        color: const Color(0xff173f35),
      ),
    ),
  );
  Widget _trip(Map<String, dynamic> trip) {
    final dates = TripDateUtils.getUpcomingDateRanges(trip);
    final config = trip['contentSections'] as Map? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text(trip['title']?.toString() ?? '', heading: true),
        if (TripPrice.hasDiscount(trip)) ...[
          text('${trip['duration'] ?? ''} · ${trip['difficulty'] ?? ''}'),
          TripPrice(trip: trip),
        ] else
          text(
            '${trip['duration'] ?? ''} · ${trip['difficulty'] ?? ''} · ${trip['price'] ?? ''} / person',
          ),
        text(
          dates.isEmpty
              ? 'New dates coming soon'
              : 'Next departure: ${dates.first.originalLabel}',
        ),
        image(
          trip['cardImage']?.toString() ?? trip['image']?.toString(),
          4 / 3,
          focus: trip['imageFocalPoint']?.toString() ?? 'center',
        ),
        text('About this trip', heading: true),
        text(trip['about']?.toString() ?? ''),
        for (final key in [
          'glance',
          'highlights',
          'cancellation',
          'guidelines',
          'faqs',
          ...TripContentSettings.customKeys(config),
        ])
          if ((config[key] as Map?)?['mode'] != 'hidden')
            ExpansionTile(
              title: Text(
                (config[key] as Map?)?['heading']?.toString() ??
                    {
                      'glance': 'Trip at a glance',
                      'highlights': 'What Makes It Special',
                      'cancellation': 'Cancellation policy',
                      'guidelines': 'Trip guidelines',
                      'faqs': 'FAQs',
                    }[key] ?? 'Custom section',
              ),
              children: [
                for (final item
                    in ((config[key] as Map?)?['mode'] == 'custom'
                                ? (config[key] as Map)['items']
                                : (widget.sharedContent?[key]
                                      as Map?)?['items'])
                            as List? ??
                        [])
                  if (item is Map && item['enabled'] != false)
                    text(
                      item.entries
                          .where(
                            (e) =>
                                !['icon', 'field', 'enabled'].contains(e.key),
                          )
                          .map((e) => e.value.toString())
                          .join(' · '),
                    ),
                if (key == 'highlights' &&
                    ((config[key] as Map?)?['useTripHighlights'] != false))
                  for (final item in trip['highlights'] as List? ?? [])
                    text(item.toString()),
              ],
            ),
        for (final key in [
          'itinerary',
          'includes',
          'excludes',
          'thingsToCarry',
          'perfectFor',
          'boardingLocations',
          'availableDates',
        ])
          ExpansionTile(
            title: Text(
              {
                'itinerary': 'Itinerary',
                'includes': 'Inclusions',
                'excludes': 'Exclusions',
                'thingsToCarry': 'Things to carry',
                'perfectFor': 'Perfect for',
                'boardingLocations': 'Pickup points',
                'availableDates': 'Departure dates',
              }[key]!,
            ),
            children: [
              for (final item in trip[key] as List? ?? [])
                text(
                  item is Map
                      ? item.values
                            .map((v) => v is List ? v.join('\n') : v.toString())
                            .join('\n')
                      : item.toString(),
                ),
            ],
          ),
        for (final photo in trip['galleryImages'] as List? ?? [])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: image(photo.toString(), 4 / 3),
          ),
        text(
          'Continue to checkout to pay by QR code or UPI ID. Our team verifies payment and availability.',
        ),
      ],
    );
  }

  Widget _home(Map<String, dynamic> data) {
    final hero = data['hero'] as Map,
        options = data['presentation'] as Map? ?? {},
        cfg = HomepageConfig.parse(
          jsonEncode({
            ...HomepageConfig.initial().toJson(),
            'upcomingBatches': data['upcomingBatches'],
          }),
        ),
        batches = data['upcomingBatches'] as Map;
    final selected = cfg.selectedTrips(widget.trips),
        departures = batches['enabled'] == true
            ? TripDateUtils.buildUpcomingBatches(selected, limit: 1000000)
            : <UpcomingBatch>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        image(
          (mobile && options['heroMobileImage']?.toString().isNotEmpty == true
                  ? options['heroMobileImage']
                  : hero['backgroundImage'])
              .toString(),
          mobile ? 4 / 5 : 16 / 7,
          focus:
              (options[mobile ? 'heroMobileFocalPoint' : 'heroFocalPoint'] ??
                      'center')
                  .toString(),
        ),
        text(hero['title'].toString(), heading: true),
        text(hero['tagline'].toString()),
        if (!mobile) text(hero['description'].toString()),
        const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Search destinations or trips…',
          ),
        ),
        if (batches['enabled'] == true) ...[
          text(batches['title'].toString(), heading: true),
          text(batches['subtitle'].toString()),
          for (final batch in departures)
            for (final trip in batch.trips)
              Card(
                color: const Color(0xfffff0e5),
                child: ListTile(
                  title: Text(trip.title),
                  subtitle: Text(batch.dateLabel),
                ),
              ),
        ],
        text('Explore Destinations', heading: true),
        for (final trip in widget.trips.where(
          (t) => t['featured'] == true && t['isActive'] != false,
        ))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  image(
                    (trip['cardImage'] ?? trip['image'])?.toString(),
                    16 / 9,
                    focus: trip['cardFocalPoint']?.toString() ?? 'center',
                  ),
                  text(
                    (trip['cardTitle'] ?? trip['title']).toString(),
                    heading: true,
                  ),
                  if (TripPrice.hasDiscount(trip)) ...[
                    text(
                      '${trip['duration'] ?? ''} · ${trip['difficulty'] ?? ''}',
                    ),
                    TripPrice(trip: trip),
                  ] else
                    text(
                      '${trip['duration'] ?? ''} · ${trip['difficulty'] ?? ''} · ${trip['price'] ?? ''} / person',
                    ),
                ],
              ),
            ),
          ),
        for (final section in (data['sections'] as Map).values)
          if (section is Map && section['enabled'] == true) ...[
            text(section['title']?.toString() ?? 'Statistics', heading: true),
            if (section['subtitle'] != null)
              text(section['subtitle'].toString()),
            if (section['description'] != null)
              text(section['description'].toString()),
            for (final item in section['items'] as List? ?? [])
              if (item is Map && item['visible'] != false)
                text(
                  item.entries
                      .where(
                        (e) => ![
                          'id',
                          'visible',
                          'icon',
                          'color',
                          'image',
                          'googleUrl',
                        ].contains(e.key),
                      )
                      .map((e) => e.value.toString())
                      .join('\n'),
                ),
          ],
        text('Footer', heading: true),
        text(
          (data['footer'] as Map).entries
              .where((e) => e.value is String)
              .map((e) => e.value.toString())
              .join('\n'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Mobile'),
            selected: mobile,
            onSelected: (_) => setState(() => mobile = true),
          ),
          ChoiceChip(
            label: const Text('Desktop'),
            selected: !mobile,
            onSelected: (_) => setState(() => mobile = false),
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Draft content preview · Layout is approximate; links and payments are disabled.',
          textAlign: TextAlign.center,
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mobile ? 390 : 1000),
              child: ColoredBox(
                color: const Color(0xfffff9f2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: widget.trip != null
                      ? _trip(widget.trip!)
                      : _home(widget.homepage!),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

