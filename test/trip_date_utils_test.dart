import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';

void main() {
  final august13India = DateTime.parse('2026-08-13T12:00:00+05:30');

  group('TripDateUtils.parse', () {
    test('parses same-month ranges and single-day departures', () {
      final range = TripDateUtils.parse('Aug 07-09, 2026');
      final single = TripDateUtils.parse('Jan 04, 2026');

      expect(range, isNotNull);
      expect(range!.start, DateTime.utc(2026, 8, 7));
      expect(range.end, DateTime.utc(2026, 8, 9));
      expect(range.startKey, '2026-08-07');
      expect(range.endKey, '2026-08-09');
      expect(range.key, '2026-08-07/2026-08-09');
      expect(range.shortLabel, 'Aug 7–9');
      expect(range.fullLabel, 'AUG 7–9, 2026');
      expect(range.weekdayLabel, 'Friday Departures');

      expect(single, isNotNull);
      expect(single!.startKey, '2026-01-04');
      expect(single.endKey, '2026-01-04');
      expect(single.shortLabel, 'Jan 4');
      expect(single.fullLabel, 'JAN 4, 2026');
      expect(single.weekdayLabel, 'Sunday Departures');
    });

    test('parses cross-month and inferred cross-year ranges', () {
      final crossMonth = TripDateUtils.parse('Jan 31-Feb 02, 2026');
      final inferredCrossYear = TripDateUtils.parse('Dec 30-Jan 01, 2025');

      expect(crossMonth, isNotNull);
      expect(crossMonth!.startKey, '2026-01-31');
      expect(crossMonth.endKey, '2026-02-02');
      expect(crossMonth.shortLabel, 'Jan 31–Feb 2');
      expect(crossMonth.fullLabel, 'JAN 31–FEB 2, 2026');

      expect(inferredCrossYear, isNotNull);
      expect(inferredCrossYear!.startKey, '2025-12-30');
      expect(inferredCrossYear.endKey, '2026-01-01');
      expect(inferredCrossYear.shortLabel, 'Dec 30–Jan 1');
      expect(inferredCrossYear.fullLabel, 'DEC 30, 2025–JAN 1, 2026');
    });

    test('accepts two- and four-digit explicit end years', () {
      final shortYear = TripDateUtils.parse('Dec 30-Jan 01, 2025-26');
      final fullYear = TripDateUtils.parse('Dec 30-Jan 01, 2025-2026');

      expect(shortYear, isNotNull);
      expect(fullYear, isNotNull);
      expect(shortYear!.startKey, '2025-12-30');
      expect(shortYear.endKey, '2026-01-01');
      expect(fullYear, shortYear);
    });

    test('normalizes legacy punctuation, dash variants, and whitespace', () {
      final legacyDot = TripDateUtils.parse('  Dec 27-29.2026  ');
      final enDash = TripDateUtils.parse('Aug 14 – 16, 2026');
      final emDash = TripDateUtils.parse('Aug 14—16, 2026');
      final whitespace = TripDateUtils.parse('September   11 -  14,   2026');

      expect(legacyDot!.startKey, '2026-12-27');
      expect(legacyDot.endKey, '2026-12-29');
      expect(enDash!.key, '2026-08-14/2026-08-16');
      expect(emDash, enDash);
      expect(whitespace!.fullLabel, 'SEP 11–14, 2026');
    });

    test('accepts all website September spellings case-insensitively', () {
      for (final month in <String>['Sep', 'Sept', 'September', 'SEPT']) {
        expect(
          TripDateUtils.parse('$month 11-14, 2026')?.startKey,
          '2026-09-11',
        );
      }
    });

    test('returns null for invalid, impossible, or reversed dates', () {
      for (final label in <String>[
        '',
        '   ',
        'Dates coming soon',
        'Foo 1-2, 2026',
        'Feb 30-31, 2026',
        'Apr 31, 2026',
        'Aug 16-14, 2026',
        'Dec 30-Jan 1, 2025-24',
        'Aug 14-16 2026',
        'Aug 14, 26',
        'Jan 1, 0099',
      ]) {
        expect(
          TripDateUtils.parse(label),
          isNull,
          reason: 'Expected "$label" to be rejected',
        );
      }
    });

    test('validates leap days', () {
      expect(TripDateUtils.parse('Feb 29, 2024'), isNotNull);
      expect(TripDateUtils.parse('Feb 29, 2025'), isNull);
      expect(TripDateUtils.parse('Feb 29, 1900'), isNull);
      expect(TripDateUtils.parse('Feb 29, 2000'), isNotNull);
    });

    test('retains the unmodified original label', () {
      const original = '  Aug 14 – 16, 2026  ';
      expect(TripDateUtils.parse(original)?.originalLabel, original);
    });
  });

  group('canonical formatting', () {
    test('formats single, same-month, cross-month, and cross-year ranges', () {
      expect(
        TripDateUtils.formatCanonical(
          TripDateUtils.fromDates(DateTime(2026, 8, 14), DateTime(2026, 8, 14)),
        ),
        'Aug 14, 2026',
      );
      expect(
        TripDateUtils.formatCanonical(
          TripDateUtils.fromDates(DateTime(2026, 8, 14), DateTime(2026, 8, 16)),
        ),
        'Aug 14-16, 2026',
      );
      expect(
        TripDateUtils.formatCanonical(
          TripDateUtils.fromDates(DateTime(2026, 8, 31), DateTime(2026, 9, 2)),
        ),
        'Aug 31-Sep 2, 2026',
      );
      expect(
        TripDateUtils.formatCanonical(
          TripDateUtils.fromDates(DateTime(2026, 12, 30), DateTime(2027, 1, 1)),
        ),
        'Dec 30-Jan 1, 2026-2027',
      );
    });

    test('canonical values round-trip through the website parser', () {
      final samples = <TripDateRange>[
        TripDateUtils.fromDates(DateTime(2026, 8, 14), DateTime(2026, 8, 14)),
        TripDateUtils.fromDates(DateTime(2026, 8, 14), DateTime(2026, 8, 16)),
        TripDateUtils.fromDates(DateTime(2026, 8, 31), DateTime(2026, 9, 2)),
        TripDateUtils.fromDates(DateTime(2026, 12, 30), DateTime(2027, 1, 1)),
      ];

      for (final range in samples) {
        expect(
          TripDateUtils.parse(TripDateUtils.formatCanonical(range)),
          range,
        );
      }
    });

    test('fromDates strips time and rejects a reversed range', () {
      final range = TripDateUtils.fromDates(
        DateTime(2026, 8, 14, 23, 59),
        DateTime(2026, 8, 16, 1),
      );

      expect(range.start, DateTime.utc(2026, 8, 14));
      expect(range.end, DateTime.utc(2026, 8, 16));
      expect(range.originalLabel, 'Aug 14-16, 2026');
      expect(
        () => TripDateUtils.fromDates(
          DateTime(2026, 8, 16),
          DateTime(2026, 8, 14),
        ),
        throwsArgumentError,
      );
    });
  });

  group('India calendar boundaries', () {
    test('changes date exactly at India midnight', () {
      expect(
        TripDateUtils.indiaToday(DateTime.utc(2026, 8, 12, 18, 29, 59)),
        DateTime.utc(2026, 8, 12),
      );
      expect(
        TripDateUtils.indiaToday(DateTime.utc(2026, 8, 12, 18, 30)),
        DateTime.utc(2026, 8, 13),
      );
    });

    test('uses the represented instant rather than its source offset', () {
      expect(
        TripDateUtils.indiaToday(DateTime.parse('2026-08-12T20:00:00-04:00')),
        DateTime.utc(2026, 8, 13),
      );
    });

    test('a range is expired only after its end day in India', () {
      final range = TripDateUtils.parse('Aug 12-13, 2026')!;

      expect(range.isExpired(august13India), isFalse);
      expect(
        range.isExpired(DateTime.parse('2026-08-14T00:01:00+05:30')),
        isTrue,
      );
    });
  });

  group('getUpcomingDateRanges', () {
    test('filters expired values, deduplicates, and sorts chronologically', () {
      final ranges = TripDateUtils.getUpcomingDateRanges(<String, dynamic>{
        'isActive': true,
        'availableDates': <dynamic>[
          'Sept 11-14, 2026',
          'Aug 07-09, 2026',
          'Aug 21-23, 2026',
          'Aug 14-16, 2026',
          'AUGUST 14–16, 2026',
          'Dates coming soon',
          null,
        ],
      }, referenceDate: august13India);

      expect(ranges.map((range) => range.startKey), <String>[
        '2026-08-14',
        '2026-08-21',
        '2026-09-11',
      ]);
      expect(ranges.first.originalLabel, 'Aug 14-16, 2026');
      expect(() => ranges.add(ranges.first), throwsUnsupportedError);
    });

    test('retains an ongoing range whose end is today', () {
      final ranges = TripDateUtils.getUpcomingDateRanges(<String, dynamic>{
        'availableDates': <String>[
          'Aug 10-12, 2026',
          'Aug 11-13, 2026',
          'Aug 13-14, 2026',
        ],
      }, referenceDate: august13India);

      expect(ranges.map((range) => range.key), <String>[
        '2026-08-11/2026-08-13',
        '2026-08-13/2026-08-14',
      ]);
    });

    test('returns no dates for inactive trips or non-list date data', () {
      expect(
        TripDateUtils.getUpcomingDateRanges(<String, dynamic>{
          'isActive': false,
          'availableDates': <String>['Aug 14-16, 2026'],
        }, referenceDate: august13India),
        isEmpty,
      );
      expect(
        TripDateUtils.getUpcomingDateRanges(<String, dynamic>{
          'availableDates': 'Aug 14-16, 2026',
        }, referenceDate: august13India),
        isEmpty,
      );
    });

    test('treats a missing isActive property as active like the website', () {
      expect(
        TripDateUtils.getUpcomingDateRanges(<String, dynamic>{
          'availableDates': <String>['Aug 14-16, 2026'],
        }, referenceDate: august13India),
        hasLength(1),
      );
    });
  });

  group('getTripDateTags', () {
    final trip = <String, dynamic>{
      'isActive': true,
      'availableDates': <String>[
        'Aug 14-16, 2026',
        'Aug 21-23, 2026',
        'Aug 28-30, 2026',
        'Sept 11-14, 2026',
      ],
    };

    test('limits visible tags and reports the remainder', () {
      final tags = TripDateUtils.getTripDateTags(
        trip,
        referenceDate: august13India,
        limit: 3,
      );

      expect(tags.visible.map((date) => date.shortLabel), <String>[
        'Aug 14–16',
        'Aug 21–23',
        'Aug 28–30',
      ]);
      expect(tags.remaining, 1);
      expect(() => tags.visible.clear(), throwsUnsupportedError);
    });

    test('uses the website default when a non-positive limit is supplied', () {
      final tags = TripDateUtils.getTripDateTags(
        trip,
        referenceDate: august13India,
        limit: 0,
      );

      expect(tags.visible, hasLength(3));
      expect(tags.remaining, 1);
    });
  });

  group('buildUpcomingBatches', () {
    test('UpcomingBatch takes an immutable snapshot of its trips', () {
      final sourceTrips = <UpcomingBatchTrip>[
        const UpcomingBatchTrip(
          id: 'trip',
          title: 'Trip',
          price: '₹4199',
          location: 'Coorg',
        ),
      ];
      final batch = UpcomingBatch(
        key: '2026-08-14/2026-08-16',
        start: DateTime.utc(2026, 8, 14),
        end: DateTime.utc(2026, 8, 16),
        datetime: '2026-08-14',
        dateLabel: 'AUG 14–16, 2026',
        weekdayLabel: 'Friday Departures',
        trips: sourceTrips,
      );

      sourceTrips.clear();

      expect(batch.trips, hasLength(1));
      expect(() => batch.trips.clear(), throwsUnsupportedError);
    });

    test('groups active trips into exact normalized ranges', () {
      final batches = TripDateUtils.buildUpcomingBatches(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'first',
            'title': 'First Trip',
            'price': '₹4199',
            'location': 'Coorg',
            'isActive': true,
            'availableDates': <String>['Aug 14-16, 2026', 'Aug 21-23, 2026'],
          },
          <String, dynamic>{
            'id': 'second',
            'title': 'Second Trip',
            'price': '₹5999',
            'location': 'Tamil Nadu',
            'isActive': true,
            'availableDates': <String>['AUGUST 14–16, 2026'],
          },
          <String, dynamic>{
            'id': 'inactive',
            'title': 'Inactive Trip',
            'isActive': false,
            'availableDates': <String>['Aug 14-16, 2026'],
          },
        ],
        referenceDate: august13India,
        limit: 3,
      );

      expect(batches, hasLength(2));
      expect(batches.first.key, '2026-08-14/2026-08-16');
      expect(batches.first.start, DateTime.utc(2026, 8, 14));
      expect(batches.first.end, DateTime.utc(2026, 8, 16));
      expect(batches.first.datetime, '2026-08-14');
      expect(batches.first.dateLabel, 'AUG 14–16, 2026');
      expect(batches.first.weekdayLabel, 'Friday Departures');
      expect(batches.first.trips.map((trip) => trip.id), <String?>[
        'first',
        'second',
      ]);
      expect(batches.first.trips.first.title, 'First Trip');
      expect(batches.first.trips.first.price, '₹4199');
      expect(batches.first.trips.first.location, 'Coorg');
      expect(batches.last.dateLabel, 'AUG 21–23, 2026');
      expect(() => batches.clear(), throwsUnsupportedError);
      expect(() => batches.first.trips.clear(), throwsUnsupportedError);
    });

    test('deduplicates repeated dates and duplicate trip identities', () {
      final batches = TripDateUtils.buildUpcomingBatches(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'same-id',
          'title': 'Original',
          'availableDates': <String>['Aug 14-16, 2026', 'AUG 14–16, 2026'],
        },
        <String, dynamic>{
          'id': 'same-id',
          'title': 'Duplicate',
          'availableDates': <String>['Aug 14-16, 2026'],
        },
        <String, dynamic>{
          'title': 'Title Identity',
          'availableDates': <String>['Aug 14-16, 2026'],
        },
        <String, dynamic>{
          'title': 'Title Identity',
          'availableDates': <String>['Aug 14-16, 2026'],
        },
      ], referenceDate: august13India);

      expect(batches, hasLength(1));
      expect(batches.single.trips.map((trip) => trip.title), <String>[
        'Original',
        'Title Identity',
      ]);
    });

    test('sorts distinct exact ranges and applies the earliest-N limit', () {
      final batches = TripDateUtils.buildUpcomingBatches(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'trip',
            'title': 'Trip',
            'availableDates': <String>[
              'Sep 4-6, 2026',
              'Aug 28-30, 2026',
              'Aug 21-23, 2026',
              'Aug 14-16, 2026',
            ],
          },
        ],
        referenceDate: august13India,
        limit: 3,
      );

      expect(batches.map((batch) => batch.datetime), <String>[
        '2026-08-14',
        '2026-08-21',
        '2026-08-28',
      ]);
    });

    test('matches the four-trip August 13, 2026 website fixture', () {
      final fourWebsiteTrips = <Map<String, dynamic>>[
        for (final id in <String>[
          'theyyam',
          'wayanad',
          'rameshwaram-dhanushkodi',
          'wayanad-pool-party',
        ])
          <String, dynamic>{
            'id': id,
            'title': 'Trip $id',
            'price': '₹4199',
            'isActive': true,
            'availableDates': <String>[
              'Aug 07-09, 2026',
              'Aug 14-16, 2026',
              'Aug 21-23, 2026',
              'Aug 28-30, 2026',
            ],
          },
      ];

      final batches = TripDateUtils.buildUpcomingBatches(
        fourWebsiteTrips,
        referenceDate: august13India,
        limit: 3,
      );

      expect(batches.map((batch) => batch.dateLabel), <String>[
        'AUG 14–16, 2026',
        'AUG 21–23, 2026',
        'AUG 28–30, 2026',
      ]);
      for (final batch in batches) {
        expect(batch.trips, hasLength(4));
      }
    });
  });
}
