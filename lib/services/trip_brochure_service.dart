import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'trip_date_utils.dart';
import 'trip_detail_defaults.dart';
import 'trips_parser.dart';
import '../models/trip_content_settings.dart';

class BrochureBlock {
  const BrochureBlock(this.kind, this.text);
  final String kind;
  final String text;
}

/// A read-only export snapshot; never saves a trip or calls GitHub.
class TripBrochure {
  TripBrochure._(this.title, this.bookingUrl, this.filename, this.blocks);
  final String title;
  final String bookingUrl;
  final String filename;
  final List<BrochureBlock> blocks;

  factory TripBrochure.fromTrip(
    Map<String, dynamic> trip, {
    DateTime? referenceDate,
    String? selectedDate,
    String? whatsapp,
    Map<String, dynamic>? sharedContent,
  }) {
    final title = _text(trip['title'] ?? trip['name']);
    final blocks = <BrochureBlock>[
      BrochureBlock('title', title.isEmpty ? 'Trip itinerary' : title),
    ];
    void section(String heading, List<String> lines) {
      if (lines.isEmpty) return;
      blocks.add(BrochureBlock('heading', heading));
      blocks.addAll(lines.map((line) => BrochureBlock('body', line)));
    }
    final sections = trip['contentSections'] is Map
        ? trip['contentSections'] as Map : <String, dynamic>{};
    Map? resolve(String key) {
      final own = sections[key];
      if (own is Map && own['mode'] == 'hidden') return null;
      final result = own is Map && own['mode'] == 'custom'
          ? own : sharedContent?[key];
      return result is Map && result['mode'] != 'hidden' ? result : null;
    }
    List<Map> visibleItems(Map? value) => value?['items'] is List
        ? (value!['items'] as List).whereType<Map>()
            .where((item) => item['enabled'] != false).toList() : [];
    String heading(Map? value, String fallback) =>
        _text(value?['heading']).isEmpty ? fallback : _text(value?['heading']);
    List<String> descriptions(Map? value, {bool faq = false}) =>
        visibleItems(value).map((item) => [
          _text(item[faq ? 'question' : 'title']),
          _text(item[faq ? 'answer' : 'description']),
        ].where((part) => part.isNotEmpty).join('\n'))
        .where((line) => line.isNotEmpty).toList();

    final glance = resolve('glance');
    final glanceLines = [
      'Location: ${_text(trip['location'] ?? trip['destination'])}',
      for (final key in [
        'duration',
        'difficulty',
        'distance',
        'elevation',
        'groupSize',
      ])
        if (_text(trip[key]).isNotEmpty)
          '${key == 'groupSize' ? 'Group size' : key[0].toUpperCase() + key.substring(1)}: ${_text(trip[key])}',
      if (_text(trip['price']).isNotEmpty) 'Price: ${_text(trip['price'])}',
      if (trip['isActive'] == false) 'Currently unavailable for booking.',
    ];
    final ownGlance = sections['glance'];
    final sharedGlance = sharedContent?['glance'];
    if (!(ownGlance is Map && ownGlance['mode'] == 'hidden') &&
        (glance != null || !(sharedGlance is Map && sharedGlance['mode'] == 'hidden'))) {
      section(heading(glance, 'Trip at a glance'), glance == null ? glanceLines : [
        for (final item in visibleItems(glance))
          if (_text(_text(item['field']).isNotEmpty ? trip[item['field']] : item['value']).isNotEmpty)
            '${_text(item['label'])}: ${_text(_text(item['field']).isNotEmpty ? trip[item['field']] : item['value'])}',
        if (_text(trip['price']).isNotEmpty) 'Price: ${_text(trip['price'])}',
        if (trip['isActive'] == false) 'Currently unavailable for booking.',
      ]);
    }
    final upcoming = TripDateUtils.getUpcomingDateRanges(
      trip,
      referenceDate: referenceDate,
    );
    final selected = selectedDate == null
        ? null
        : TripDateUtils.parse(selectedDate);
    final matches = upcoming
        .where((range) => range.key == selected?.key)
        .toList();
    section(
      matches.isNotEmpty ? 'Selected departure' : 'Upcoming departures',
      matches.isNotEmpty
          ? [matches.first.fullLabel]
          : upcoming.isNotEmpty
          ? upcoming.map((range) => range.fullLabel).toList()
          : ['New dates coming soon. Contact us to confirm.'],
    );
    section('About this trip', _items([trip['about'] ?? trip['description']]));
    final highlights = resolve('highlights');
    final ownHighlights = sections['highlights'];
    final sharedHighlights = sharedContent?['highlights'];
    if (!(ownHighlights is Map && ownHighlights['mode'] == 'hidden') &&
        (highlights != null || !(sharedHighlights is Map && sharedHighlights['mode'] == 'hidden'))) {
      section(heading(highlights, 'Highlights'),
        highlights == null || highlights['useTripHighlights'] == true
            ? _items(trip['highlights']).map((line) => '• $line').toList()
            : descriptions(highlights));
    }
    for (final key in TripContentSettings.customKeys(sections).take(20)) {
      final extra = sections[key];
      if (extra is Map && extra['mode'] == 'custom' && _text(extra['heading']).isNotEmpty) {
        section(_text(extra['heading']), descriptions(extra));
      }
    }
    final itinerary = trip['itinerary'] is List
        ? (trip['itinerary'] as List).whereType<Map>().toList()
        : <Map>[];
    if (itinerary.isEmpty) {
      section('Itinerary', [
        'Detailed itinerary coming soon. Contact us for details.',
      ]);
    }
    for (var index = 0; index < itinerary.length; index++) {
      final day = itinerary[index];
      final label = _text(day['day']);
      final name = _text(day['title']);
      final lines = [
        ..._items([day['description']]),
        ..._items(day['activities']).map((line) => '• $line'),
      ];
      section(
        '${label.isEmpty ? 'Day ${index + 1}' : label}${name.isEmpty ? '' : ': $name'}',
        lines.isEmpty ? ['Details to be confirmed.'] : lines,
      );
    }
    // The editor's aliases are canonical for its unsaved inclusion/exclusion edits.
    section(
      'Inclusions',
      _items(
        trip['inclusions'] ?? trip['includes'],
      ).map((line) => '• $line').toList(),
    );
    section(
      'Exclusions',
      _items(
        trip['exclusions'] ?? trip['excludes'],
      ).map((line) => '• $line').toList(),
    );
    final customPoints = trip['boardingLocations'] is List
        ? (trip['boardingLocations'] as List).whereType<Map>().toList()
        : <Map>[];
    final boarding =
        customPoints.any(
          (point) =>
              _text(point['name']).isNotEmpty &&
              _text(point['time']).isNotEmpty,
        )
        ? customPoints
        : TripsParser.getDefaultPickupPoints();
    section('Boarding points', [
      for (final point in boarding)
        if (_text(point['name']).isNotEmpty && _text(point['time']).isNotEmpty)
          [
            point['name'],
            point['time'],
            point['landmark'],
          ].map(_text).where((value) => value.isNotEmpty).join(' — '),
    ]);
    for (final entry in {
      'thingsToCarry': ('Things to carry', TripDetailDefaults.thingsToCarry),
      'perfectFor': ('Perfect for', TripDetailDefaults.perfectFor),
    }.entries) {
      final custom = _items(trip[entry.key]);
      final values = trip[entry.key] is List ? custom : entry.value.$2;
      section(
        entry.value.$1,
        entry.key == 'thingsToCarry'
            ? values.map((line) => '• $line').toList()
            : values,
      );
    }
    final id = _text(trip['publicSlug'] ?? trip['id']);
    final guidelines = resolve('guidelines');
    section(heading(guidelines, 'Trip guidelines'), descriptions(guidelines));
    final cancellation = resolve('cancellation');
    final rules = visibleItems(cancellation).where((rule) =>
        rule['minDays'] is num && rule['percent'] is num).toList()
      ..sort((a, b) => (b['minDays'] as num).compareTo(a['minDays'] as num));
    section(heading(cancellation, 'Cancellation policy'), [
      for (final rule in rules)
        '${rule['maxDays'] == null ? '${rule['minDays']}+ days' : '${rule['minDays']}–${rule['maxDays']} days'} before departure: ${rule['percent']}% cancellation fee',
      ..._items([cancellation?['refundNote'], cancellation?['changeNote']]),
    ]);
    final faqs = resolve('faqs');
    section(heading(faqs, 'Frequently asked questions'), descriptions(faqs, faq: true));
    final bookingUrl = RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id)
        ? 'https://www.teamweekendtrekkers.com/trips/$id/'
        : 'https://www.teamweekendtrekkers.com/trips.html';
    final phone = (whatsapp ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    section('Booking & enquiries', [
      bookingUrl,
      if (phone.isNotEmpty)
        'WhatsApp: +${phone.length == 10 ? '91$phone' : phone}',
      'Dates, prices and availability can change. Confirm before booking.',
    ]);
    if (blocks.fold<int>(0, (sum, block) => sum + block.text.length) > 500000) {
      throw const FormatException(
        'This itinerary is too large to export. Please shorten it.',
      );
    }
    var slug = blocks.first.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.length > 80) slug = slug.substring(0, 80);
    return TripBrochure._(
      blocks.first.text,
      bookingUrl,
      '${slug.isEmpty ? 'trip' : slug}-brochure.pdf',
      List.unmodifiable(blocks),
    );
  }
}

String _text(Object? value) =>
    value is String || value is num ? '$value'.trim() : '';
List<String> _items(Object? value) => value is List
    ? value.map(_text).where((item) => item.isNotEmpty).toList()
    : [];

class TripBrochurePdf {
  static const width = 1240, height = 1754;
  static const margin = 80.0, bottom = 1600.0;

  /// Rasterized A4 pages preserve platform Unicode/emoji without new font/network dependencies.
  static Future<Uint8List> generate(TripBrochure brochure, {
    void Function(Uint8List image, int page)? onPageRendered,
  }) async {
    final pages = <Uint8List>[];
    late ui.PictureRecorder recorder;
    late Canvas canvas;
    var y = 190.0;
    void startPage() {
      if (pages.length >= 100) {
        throw StateError(
          'This brochure exceeds 100 pages. Please shorten the itinerary.',
        );
      }
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1240, 1754),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1240, 142),
        Paint()..color = const Color(0xFF17442D),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 142, 1240, 8),
        Paint()..color = const Color(0xFFED801C),
      );
      _paint(
        canvas,
        'Team Weekend Trekkers',
        36,
        const Color(0xFFFFFFFF),
        const Offset(margin, 24),
        bold: true,
      );
      _paint(
        canvas,
        'YOUR TRIP GUIDE  /  ITINERARY & ESSENTIALS',
        20,
        const Color(0xFFCEE8D9),
        const Offset(margin, 82),
      );
      y = 190;
    }

    Future<void> finishPage() async {
      canvas.drawRect(const Rect.fromLTWH(margin, 1622, width - margin * 2, 92),
        Paint()..color = const Color(0xFFEAF4EE));
      _paint(
        canvas,
        brochure.bookingUrl,
        20,
        const Color(0xFF557062),
        const Offset(margin, 1638),
      );
      _paint(
        canvas,
        'Team Weekend Trekkers  •  Page ${pages.length + 1}',
        20,
        const Color(0xFF557062),
        const Offset(margin, 1672),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) throw StateError('Unable to render brochure.');
        final rgba = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final rgb = Uint8List(width * height * 3);
        for (int source = 0, target = 0; source < rgba.length; source += 4) {
          rgb[target++] = rgba[source];
          rgb[target++] = rgba[source + 1];
          rgb[target++] = rgba[source + 2];
        }
        pages.add(Uint8List.fromList(ZLibEncoder().convert(rgb)));
        if (onPageRendered != null) {
          final previewRecorder = ui.PictureRecorder();
          Canvas(previewRecorder).drawImageRect(image,
            const Rect.fromLTWH(0, 0, 1240, 1754),
            const Rect.fromLTWH(0, 0, 620, 877), Paint()..filterQuality = FilterQuality.medium);
          final previewPicture = previewRecorder.endRecording();
          final preview = await previewPicture.toImage(620, 877);
          previewPicture.dispose();
          try {
            final png = await preview.toByteData(format: ui.ImageByteFormat.png);
            if (png == null) throw StateError('Unable to render PDF preview.');
            onPageRendered(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), pages.length);
          } finally { preview.dispose(); }
        }
      } finally {
        image.dispose();
      }
    }

    startPage();
    for (var blockIndex = 0; blockIndex < brochure.blocks.length; blockIndex++) {
      final block = brochure.blocks[blockIndex];
      final size = block.kind == 'title'
          ? 44.0
          : block.kind == 'heading'
          ? 32.0
          : 26.0;
      final painter = _painter(
        block.text,
        size,
        block.kind == 'body'
            ? const Color(0xFF25382E)
            : const Color(0xFF17442D),
        bold: block.kind != 'body',
        inset: block.kind == 'heading' ? 18 : 0,
      );
      try {
        final metrics = painter.computeLineMetrics();
        var keepHeight = metrics.fold<double>(0, (sum, line) => sum + line.height) + 56;
        if (blockIndex + 1 < brochure.blocks.length && brochure.blocks[blockIndex + 1].kind == 'body') {
          final next = _painter(brochure.blocks[blockIndex + 1].text, 26, const Color(0xFF25382E));
          keepHeight += next.computeLineMetrics().take(2).fold<double>(0, (sum, line) => sum + line.height);
          next.dispose();
        }
        if (block.kind != 'body') {
          var sectionHeight = 0.0;
          for (var lookahead = blockIndex + 1; lookahead < brochure.blocks.length && brochure.blocks[lookahead].kind == 'body'; lookahead++) {
            final next = _painter(brochure.blocks[lookahead].text, 26, const Color(0xFF25382E));
            sectionHeight += next.height + 10;
            next.dispose();
            if (sectionHeight > 420) break;
          }
          if (sectionHeight <= 420) keepHeight = painter.height + 56 + sectionHeight;
        }
        if (block.kind != 'body' && y + keepHeight > bottom && y > 190) {
          await finishPage();
          startPage();
        }
        if (block.kind == 'body' && painter.height + 10 <= bottom - 190 && y + painter.height + 10 > bottom) {
          await finishPage();
          startPage();
        }
        y += block.kind == 'heading' ? 26 : 10;
        final lines = metrics;
        var index = 0;
        while (index < lines.length) {
          if (y + lines[index].height > bottom) {
            await finishPage();
            startPage();
          }
          final first = index;
          var partHeight = 0.0;
          while (index < lines.length &&
              y + partHeight + lines[index].height <= bottom) {
            partHeight += lines[index++].height;
          }
          if (index == first) {
            throw StateError('Unable to fit brochure text on a page.');
          }
          canvas.save();
          final inset = block.kind == 'heading' ? 18.0 : 0.0;
          if (block.kind == 'heading') {
            canvas.drawRect(Rect.fromLTWH(margin, y - 2, width - margin * 2, partHeight + 4), Paint()..color = const Color(0xFFEDF5EF));
            canvas.drawRect(Rect.fromLTWH(margin, y - 2, 5, partHeight + 4), Paint()..color = const Color(0xFFED801C));
          }
          canvas.clipRect(
            Rect.fromLTWH(margin + inset, y, width - margin * 2 - inset, partHeight),
          );
          painter.paint(
            canvas,
            Offset(margin + inset, y - (lines[first].baseline - lines[first].ascent)),
          );
          canvas.restore();
          y += partHeight;
        }
      } finally {
        painter.dispose();
      }
    }
    await finishPage();
    return encodePages(pages, brochure.bookingUrl);
  }

  static TextPainter _painter(
    String text,
    double size,
    Color color, {
    bool bold = false,
    double inset = 0,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        height: 1.4,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
    strutStyle: StrutStyle(fontSize: size, height: 1.4, forceStrutHeight: true),
  )..layout(maxWidth: width - margin * 2 - inset);

  static void _paint(
    Canvas canvas,
    String text,
    double size,
    Color color,
    Offset position, {
    bool bold = false,
  }) {
    final painter = _painter(text, size, color, bold: bold);
    painter.paint(canvas, position);
    painter.dispose();
  }

  /// PDF 1.4 with compressed RGB pages and a safe clickable booking footer.
  static Uint8List encodePages(List<Uint8List> pages, String bookingUrl) {
    if (pages.isEmpty ||
        pages.length > 100 ||
        pages.any((page) => page.isEmpty)) {
      throw const FormatException('Brochure must contain 1–100 valid pages.');
    }
    final output = BytesBuilder(copy: false), offsets = <int>[0];
    void append(String value) => output.add(ascii.encode(value));
    void object(int id, String body, [Uint8List? stream]) {
      offsets.add(output.length);
      append('$id 0 obj\n$body');
      if (stream != null) {
        append('\nstream\n');
        output.add(stream);
        append('\nendstream');
      }
      append('\nendobj\n');
    }

    final url = RegExp(r'^https://[A-Za-z0-9._/-]+$').hasMatch(bookingUrl)
        ? bookingUrl
        : 'https://www.teamweekendtrekkers.com/trips.html';
    append('%PDF-1.4\n');
    object(1, '<< /Type /Catalog /Pages 2 0 R >>');
    object(
      2,
      '<< /Type /Pages /Count ${pages.length} /Kids [${List.generate(pages.length, (index) => '${3 + index * 4} 0 R').join(' ')}] >>',
    );
    for (var index = 0; index < pages.length; index++) {
      final id = 3 + index * 4, data = pages[index];
      object(
        id,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /XObject << /Im0 ${id + 1} 0 R >> >> /Contents ${id + 2} 0 R /Annots [${id + 3} 0 R] >>',
      );
      object(
        id + 1,
        '<< /Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${data.length} >>',
        data,
      );
      final commands = Uint8List.fromList(
        ascii.encode('q 595.28 0 0 841.89 0 0 cm /Im0 Do Q'),
      );
      object(id + 2, '<< /Length ${commands.length} >>', commands);
      object(
        id + 3,
        '<< /Type /Annot /Subtype /Link /Rect [38 18 555 52] /Border [0 0 0] /A << /S /URI /URI ($url) >> >>',
      );
    }
    final start = output.length, count = offsets.length;
    append('xref\n0 $count\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      append('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    append(
      'trailer\n<< /Size $count /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n',
    );
    return output.takeBytes();
  }
}

