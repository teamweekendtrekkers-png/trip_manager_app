/// A validated, calendar-day-only trip date range.
///
/// [start] and [end] are always UTC midnight values. Using UTC here mirrors the
/// website implementation and prevents a device time zone from changing the
/// departure date.
final class TripDateRange {
  const TripDateRange._({
    required this.originalLabel,
    required this.start,
    required this.end,
  });

  /// The value supplied to the parser, or the canonical label for a range
  /// created with [TripDateUtils.fromDates].
  final String originalLabel;

  final DateTime start;
  final DateTime end;

  String get startKey => TripDateUtils._toDateKey(start);
  String get endKey => TripDateUtils._toDateKey(end);
  String get key => '$startKey/$endKey';

  /// Compact website label, for example `Aug 14–16`.
  String get shortLabel =>
      TripDateUtils._formatDateRange(start, end, uppercase: false);

  /// Full website label, for example `AUG 14–16, 2026`.
  String get fullLabel =>
      TripDateUtils._formatDateRange(start, end, uppercase: true);

  String get weekdayLabel =>
      '${TripDateUtils._weekdayLabels[start.weekday - 1]} Departures';

  /// Whether the entire range finished before today's date in India.
  bool isExpired([DateTime? referenceDate]) =>
      end.isBefore(TripDateUtils.indiaToday(referenceDate));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripDateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => fullLabel;
}

/// The visible date tags for a trip and the count hidden by the limit.
final class TripDateTags {
  TripDateTags({required List<TripDateRange> visible, required this.remaining})
    : visible = List<TripDateRange>.unmodifiable(visible);

  final List<TripDateRange> visible;
  final int remaining;
}

/// The immutable trip summary displayed inside an upcoming batch.
final class UpcomingBatchTrip {
  const UpcomingBatchTrip({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
  });

  final String? id;
  final String title;
  final Object? price;
  final String? location;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'price': price,
    'location': location,
  };
}

/// Trips sharing one exact upcoming start/end range.
final class UpcomingBatch {
  UpcomingBatch({
    required this.key,
    required this.start,
    required this.end,
    required this.datetime,
    required this.dateLabel,
    required this.weekdayLabel,
    required List<UpcomingBatchTrip> trips,
  }) : trips = List<UpcomingBatchTrip>.unmodifiable(trips);

  final String key;
  final DateTime start;
  final DateTime end;
  final String datetime;
  final String dateLabel;
  final String weekdayLabel;
  final List<UpcomingBatchTrip> trips;
}

/// Website-compatible parsing and grouping for trip departure dates.
abstract final class TripDateUtils {
  static const Map<String, int> _monthIndexes = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static const List<String> _monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdayLabels = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static final RegExp _crossMonthPattern = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2})\s*-\s*([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})(?:-(\d{2,4}))?$',
  );
  static final RegExp _sameMonthPattern = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2})\s*-\s*(\d{1,2}),\s*(\d{4})$',
  );
  static final RegExp _singleDayPattern = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
  );
  static final RegExp _legacyYearPeriodPattern = RegExp(
    r'\.(?=\s*\d{4}(?:-\d{2,4})?\s*$)',
  );
  static final RegExp _whitespacePattern = RegExp(r'\s+');

  /// Parses every format accepted by the website's `trip-date-utils.js`.
  ///
  /// Returns null for unrecognized labels, impossible calendar dates, and
  /// ranges whose end precedes their start.
  static TripDateRange? parse(String value) {
    final label = _normalizeDateLabel(value);
    if (label.isEmpty) return null;

    int? startMonth;
    int? endMonth;
    int? startDay;
    int? endDay;
    int? startYear;
    int? endYear;

    final crossMonthMatch = _crossMonthPattern.firstMatch(label);
    if (crossMonthMatch != null) {
      startMonth = _monthIndexes[crossMonthMatch.group(1)!.toLowerCase()];
      endMonth = _monthIndexes[crossMonthMatch.group(3)!.toLowerCase()];
      startDay = int.parse(crossMonthMatch.group(2)!);
      endDay = int.parse(crossMonthMatch.group(4)!);
      startYear = int.parse(crossMonthMatch.group(5)!);

      final suppliedEndYearText = crossMonthMatch.group(6);
      if (suppliedEndYearText != null) {
        final suppliedEndYear = int.parse(suppliedEndYearText);
        endYear = suppliedEndYearText.length == 2
            ? (startYear ~/ 100) * 100 + suppliedEndYear
            : suppliedEndYear;
      } else if (startMonth != null && endMonth != null) {
        endYear = endMonth < startMonth ? startYear + 1 : startYear;
      }
    } else {
      final sameMonthMatch = _sameMonthPattern.firstMatch(label);
      if (sameMonthMatch != null) {
        startMonth = _monthIndexes[sameMonthMatch.group(1)!.toLowerCase()];
        endMonth = startMonth;
        startDay = int.parse(sameMonthMatch.group(2)!);
        endDay = int.parse(sameMonthMatch.group(3)!);
        startYear = int.parse(sameMonthMatch.group(4)!);
        endYear = startYear;
      } else {
        final singleDayMatch = _singleDayPattern.firstMatch(label);
        if (singleDayMatch == null) return null;

        startMonth = _monthIndexes[singleDayMatch.group(1)!.toLowerCase()];
        endMonth = startMonth;
        startDay = int.parse(singleDayMatch.group(2)!);
        endDay = startDay;
        startYear = int.parse(singleDayMatch.group(3)!);
        endYear = startYear;
      }
    }

    if (startMonth == null || endMonth == null || endYear == null) {
      return null;
    }

    final start = _createDate(startYear, startMonth, startDay);
    final end = _createDate(endYear, endMonth, endDay);
    if (start == null || end == null || end.isBefore(start)) return null;

    return TripDateRange._(originalLabel: value, start: start, end: end);
  }

  /// Creates a validated range from date-picker values.
  ///
  /// Time-of-day and time-zone flags are intentionally discarded: a date
  /// picker supplies calendar dates, not instants. Throws [ArgumentError] when
  /// the end date is earlier than the start date.
  static TripDateRange fromDates(DateTime start, DateTime end) {
    final normalizedStart = DateTime.utc(start.year, start.month, start.day);
    final normalizedEnd = DateTime.utc(end.year, end.month, end.day);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError.value(end, 'end', 'Must not precede start');
    }

    final provisional = TripDateRange._(
      originalLabel: '',
      start: normalizedStart,
      end: normalizedEnd,
    );
    return TripDateRange._(
      originalLabel: formatCanonical(provisional),
      start: normalizedStart,
      end: normalizedEnd,
    );
  }

  /// Produces a stable, parseable label for storage in `availableDates`.
  static String formatCanonical(TripDateRange range) {
    final startMonth = _monthLabels[range.start.month - 1];
    final endMonth = _monthLabels[range.end.month - 1];
    final startDay = range.start.day;
    final endDay = range.end.day;
    final startYear = range.start.year;
    final endYear = range.end.year;

    if (startYear == endYear && range.start.month == range.end.month) {
      if (startDay == endDay) return '$startMonth $startDay, $startYear';
      return '$startMonth $startDay-$endDay, $startYear';
    }
    if (startYear == endYear) {
      return '$startMonth $startDay-$endMonth $endDay, $startYear';
    }
    return '$startMonth $startDay-$endMonth $endDay, $startYear-$endYear';
  }

  /// Calendar date in Asia/Kolkata for the supplied instant, represented at
  /// UTC midnight so it can be compared with parsed ranges.
  static DateTime indiaToday([DateTime? referenceDate]) {
    final reference = (referenceDate ?? DateTime.now()).toUtc();
    const indiaOffset = Duration(hours: 5, minutes: 30);
    final indiaClock = reference.add(indiaOffset);
    return DateTime.utc(indiaClock.year, indiaClock.month, indiaClock.day);
  }

  /// Returns unique, non-expired ranges for an active trip in start-date order.
  static List<TripDateRange> getUpcomingDateRanges(
    Map<String, dynamic> trip, {
    DateTime? referenceDate,
  }) {
    if (trip['isActive'] == false || trip['availableDates'] is! List) {
      return const <TripDateRange>[];
    }

    final today = indiaToday(referenceDate);
    final seen = <String>{};
    final indexedRanges = <({int index, TripDateRange range})>[];
    final availableDates = trip['availableDates'] as List<dynamic>;

    for (var index = 0; index < availableDates.length; index += 1) {
      final value = availableDates[index];
      if (value is! String) continue;
      final range = parse(value);
      if (range == null || range.end.isBefore(today) || !seen.add(range.key)) {
        continue;
      }
      indexedRanges.add((index: index, range: range));
    }

    indexedRanges.sort((left, right) {
      final byStart = left.range.start.compareTo(right.range.start);
      return byStart != 0 ? byStart : left.index.compareTo(right.index);
    });
    return List<TripDateRange>.unmodifiable(
      indexedRanges.map((entry) => entry.range),
    );
  }

  static TripDateTags getTripDateTags(
    Map<String, dynamic> trip, {
    DateTime? referenceDate,
    int limit = 3,
  }) {
    final effectiveLimit = limit > 0 ? limit : 3;
    final dates = getUpcomingDateRanges(trip, referenceDate: referenceDate);
    final visibleCount = dates.length < effectiveLimit
        ? dates.length
        : effectiveLimit;
    return TripDateTags(
      visible: dates.sublist(0, visibleCount),
      remaining: dates.length - visibleCount,
    );
  }

  /// Groups active trips by exact range and returns the earliest batches.
  static List<UpcomingBatch> buildUpcomingBatches(
    List<Map<String, dynamic>> trips, {
    DateTime? referenceDate,
    int limit = 3,
  }) {
    final effectiveLimit = limit > 0 ? limit : 3;
    final builders = <String, _UpcomingBatchBuilder>{};
    var nextOrdinal = 0;

    for (final trip in trips) {
      if (trip['isActive'] == false) continue;
      final dateRanges = getUpcomingDateRanges(
        trip,
        referenceDate: referenceDate,
      );
      for (final dateRange in dateRanges) {
        final builder = builders.putIfAbsent(
          dateRange.key,
          () => _UpcomingBatchBuilder(dateRange, nextOrdinal++),
        );
        builder.addTrip(trip);
      }
    }

    final ordered = builders.values.toList()
      ..sort((left, right) {
        final byStart = left.range.start.compareTo(right.range.start);
        return byStart != 0 ? byStart : left.ordinal.compareTo(right.ordinal);
      });
    final count = ordered.length < effectiveLimit
        ? ordered.length
        : effectiveLimit;
    return List<UpcomingBatch>.unmodifiable(
      ordered.take(count).map((builder) => builder.build()),
    );
  }

  static String _normalizeDateLabel(String value) => value
      .trim()
      .replaceAll(RegExp('[\u2013\u2014]'), '-')
      .replaceFirst(_legacyYearPeriodPattern, ', ')
      .replaceAll(_whitespacePattern, ' ');

  static DateTime? _createDate(int year, int month, int day) {
    // JavaScript's Date.UTC remaps years 0–99 to 1900–1999. The website then
    // rejects those values during its component validation, so mirror that
    // otherwise-surprising edge case here.
    if (year >= 0 && year < 100) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String _toDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _formatDateRange(
    DateTime start,
    DateTime end, {
    required bool uppercase,
  }) {
    final rawStartMonth = _monthLabels[start.month - 1];
    final rawEndMonth = _monthLabels[end.month - 1];
    final startMonth = uppercase ? rawStartMonth.toUpperCase() : rawStartMonth;
    final endMonth = uppercase ? rawEndMonth.toUpperCase() : rawEndMonth;

    if (start.year == end.year && start.month == end.month) {
      if (start.day == end.day) {
        return uppercase
            ? '$startMonth ${start.day}, ${start.year}'
            : '$startMonth ${start.day}';
      }
      return uppercase
          ? '$startMonth ${start.day}–${end.day}, ${start.year}'
          : '$startMonth ${start.day}–${end.day}';
    }
    if (start.year == end.year) {
      return uppercase
          ? '$startMonth ${start.day}–$endMonth ${end.day}, ${start.year}'
          : '$startMonth ${start.day}–$endMonth ${end.day}';
    }
    return uppercase
        ? '$startMonth ${start.day}, ${start.year}–'
              '$endMonth ${end.day}, ${end.year}'
        : '$startMonth ${start.day}–$endMonth ${end.day}';
  }
}

final class _UpcomingBatchBuilder {
  _UpcomingBatchBuilder(this.range, this.ordinal);

  final TripDateRange range;
  final int ordinal;
  final List<UpcomingBatchTrip> _trips = <UpcomingBatchTrip>[];
  final Set<String> _tripKeys = <String>{};

  void addTrip(Map<String, dynamic> trip) {
    final String? id = trip['id']?.toString();
    final title = trip['title']?.toString() ?? '';
    final tripKey = id == null || id.isEmpty ? title : id;
    if (!_tripKeys.add(tripKey)) return;

    final String? location = trip['location']?.toString();
    _trips.add(
      UpcomingBatchTrip(
        id: id,
        title: title,
        price: trip['price'],
        location: location,
      ),
    );
  }

  UpcomingBatch build() => UpcomingBatch(
    key: range.key,
    start: range.start,
    end: range.end,
    datetime: range.startKey,
    dateLabel: range.fullLabel,
    weekdayLabel: range.weekdayLabel,
    trips: _trips,
  );
}
