import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  group('source-preserving trips document', () {
    const source = '''// prefix with a decoy: const tripsData = { nope: true };
const decoy = "const tripsData = { alsoNope: {} }";
const /* declaration comment */ tripsData = {
  "alpha-trip": {
    title: "Alpha } { trip",
    location: "Karnataka",
    availableDates: ["Aug 14-16, 2026"],
    itinerary: [{day: "Day 1", title: "Nested", activities: ["A { brace }"]}],
    about: "Safe",
    featured: true,
    isActive: true,
  },
  beta: {
    title: "Beta",
    location: "Kerala",
    availableDates: [],
    about: "Also safe",
    featured: false,
    isActive: true,
  },
};
// suffix must stay byte-for-byte
function getTripData(id) { return tripsData[id]; }
''';

    test(
      'balanced scan ignores declarations and braces in strings/comments',
      () {
        final result = TripsParser.parseTripsDocument(source);

        expect(result.isValid, isTrue, reason: result.errors.join('\n'));
        expect(result.trips.map((trip) => trip['id']), ['alpha-trip', 'beta']);
        expect(result.trips.first['title'], 'Alpha } { trip');
      },
    );

    test('declaration-shaped regular expressions are never rewritten', () {
      const regexOnly = r'const matcher = /const tripsData = { fake: {} }/;';
      final parsedOnly = TripsParser.parseTripsDocument(regexOnly);
      expect(parsedOnly.isValid, isFalse);
      expect(parsedOnly.document, isNull);
      expect(parsedOnly.trips, isEmpty);

      final blocked = TripsParser.replaceTripsDataObject(
        source: regexOnly,
        trips: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'safe', 'title': 'Safe'},
        ],
      );
      expect(blocked.success, isFalse);
      expect(blocked.content, isNull);

      const regexThenDeclaration =
          r'''const matcher = /const tripsData = { fake: {} }/;
const tripsData = {safe: {title: "Safe"}};
''';
      final parsed = TripsParser.parseTripsDocument(regexThenDeclaration);
      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
      expect(parsed.trips.single['id'], 'safe');
      expect(
        parsed.document!.prefix,
        r'''const matcher = /const tripsData = { fake: {} }/;
const tripsData = ''',
      );
    });

    test(
      'declarations inside nested template expressions are never rewritten',
      () {
        const templateOnly = r'''const outer = `prefix ${`
const tripsData = {decoy: {title: "Decoy"}};
`} suffix`;
''';
        final parsedOnly = TripsParser.parseTripsDocument(templateOnly);
        expect(parsedOnly.isValid, isFalse);
        expect(parsedOnly.document, isNull);
        expect(parsedOnly.trips, isEmpty);

        final blocked = TripsParser.replaceTripsDataObject(
          source: templateOnly,
          trips: const <Map<String, dynamic>>[
            <String, dynamic>{'id': 'safe', 'title': 'Safe'},
          ],
        );
        expect(blocked.success, isFalse);
        expect(blocked.content, isNull);

        const templateThenDeclaration = r'''const outer = `prefix ${`
const tripsData = {decoy: {title: "Decoy"}};
`} suffix`;
const tripsData = {safe: {title: "Safe"}};
''';
        final parsed = TripsParser.parseTripsDocument(templateThenDeclaration);
        expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
        expect(parsed.trips.single['id'], 'safe');
      },
    );

    test('postfix update followed by division does not hide a declaration', () {
      for (final operator in const <String>['++', '--']) {
        final source = '''const helper = `\${index$operator / count}`;
const tripsData = {safe: {title: "Safe"}};
''';
        final parsed = TripsParser.parseTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$operator: ${parsed.errors.join('\n')}',
        );
        expect(parsed.trips.single['id'], 'safe');
      }
    });

    test('regex after expression keywords does not hide a declaration', () {
      for (final expression in const <String>[
        r'for (const x of /`/) {}',
        r'for (holder.item of /`/) { break; }',
        r'for (const x /* ok */ of /`/) { break; }',
        r'for(const{x,y}of/`/){break;}',
        r'for(let[x,y]of/`/){break;}',
        r'class Child extends (() => /`/) {}',
        r'(async () => await /`/)();',
        r'(function* () { yield /`/; })().next();',
      ]) {
        final source = '''const helper = `\${(()=>{ $expression })()}`;
const tripsData = {safe: {title: "Safe"}};
''';
        final parsed = TripsParser.parseTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$expression: ${parsed.errors.join('\n')}',
        );
        expect(parsed.trips.single['id'], 'safe');
      }
    });

    test('keyword-named properties keep a following slash as division', () {
      for (final expression in const <String>[
        r'holder.of / count',
        r'holder.extends / count',
        r'holder?.of / count',
      ]) {
        final source = '''const helper = `\${$expression}`;
const tripsData = {safe: {title: "Safe"}};
''';
        final parsed = TripsParser.parseTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$expression: ${parsed.errors.join('\n')}',
        );
        expect(parsed.trips.single['id'], 'safe');
      }
    });

    test('classic-script contextual identifiers can be divided', () {
      for (final identifier in const <String>['of', 'await', 'yield']) {
        final source = '''const helper = `\${$identifier / count}`;
const tripsData = {safe: {title: "Safe"}};
''';
        final parsed = TripsParser.parseTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$identifier: ${parsed.errors.join('\n')}',
        );
        expect(parsed.trips.single['id'], 'safe');
      }
    });

    test('replacement changes only the object source span', () {
      final parsed = TripsParser.parseTripsDocument(source);
      final replacement = TripsParser.replaceTripsDataObject(
        source: source,
        trips: [
          {...parsed.trips.first, 'title': 'Changed', 'name': 'Changed'},
          parsed.trips.last,
        ],
      );

      expect(replacement.success, isTrue, reason: replacement.error);
      final updated = replacement.content!;
      final reparsed = TripsParser.parseTripsDocument(updated);
      expect(reparsed.trips.first['title'], 'Changed');
      expect(
        updated.substring(0, reparsed.document!.objectStart),
        parsed.document!.prefix,
      );
      expect(
        updated.substring(reparsed.document!.objectEnd + 1),
        parsed.document!.suffix,
      );
    });

    test('duplicate IDs are reported and publication is blocked', () {
      const duplicateSource = '''const tripsData = {
  same: {title: "One"},
  same: {title: "Two"},
};''';
      final parsed = TripsParser.parseTripsDocument(duplicateSource);

      expect(parsed.isValid, isFalse);
      expect(parsed.duplicateIds, {'same'});
      expect(parsed.trips, hasLength(2));
      expect(
        TripsParser.replaceTripsDataObject(
          source: duplicateSource,
          trips: parsed.trips,
        ).success,
        isFalse,
      );
    });

    test('unknown source field is reported instead of being dropped', () {
      const unsupported = '''const tripsData = {
  alpha: {title: "Alpha", newlyAddedWebsiteField: "retain me"},
};''';
      final parsed = TripsParser.parseTripsDocument(unsupported);

      expect(parsed.isValid, isFalse);
      expect(parsed.unsupportedFields['alpha'], {'newlyAddedWebsiteField'});
      expect(
        parsed.errors.join('\n'),
        contains('unsupported top-level fields'),
      );
    });

    test('malformed object is rejected', () {
      const malformed = 'const tripsData = { alpha: {title: "Alpha"}';
      final parsed = TripsParser.parseTripsDocument(malformed);

      expect(parsed.isValid, isFalse);
      expect(parsed.document, isNull);
      expect(parsed.errors.join('\n'), contains('malformed or unterminated'));
    });

    test(
      'quoted keys, comments, escapes, and nested braces parse losslessly',
      () {
        const flexibleSource = r'''const tripsData = {
  'alpha-trip': {
    'title': 'A \'quoted\' {trip}', // a brace in a comment: }
    location: 'Karnataka',
    availableDates: ['Aug 14-16, 2026'],
    itinerary: [
      {'day': 'Day 1', title: 'Nested } title', activities: ['A { brace }', 'Say \'hi\'']},
    ],
    boardingLocations: [
      {name: 'Stop', landmark: 'Near {gate}', time: '9 PM', mapLink: 'https://maps.test/a'},
    ],
    featured: true,
    isActive: true,
  },
};
''';

        final before = TripsParser.parseTripsDocument(flexibleSource);
        expect(before.isValid, isTrue, reason: before.errors.join('\n'));
        expect(before.trips.single['title'], "A 'quoted' {trip}");
        expect(
          (before.trips.single['itinerary'] as List).single['activities'],
          ['A { brace }', "Say 'hi'"],
        );

        final write = TripsParser.replaceTripsDataObject(
          source: flexibleSource,
          trips: before.trips,
        );
        expect(write.success, isTrue, reason: write.error);
        final after = TripsParser.parseTripsDocument(write.content!);
        expect(after.isValid, isTrue, reason: after.errors.join('\n'));
        expect(after.trips.single['title'], before.trips.single['title']);
        expect(
          after.trips.single['itinerary'],
          before.trips.single['itinerary'],
        );
        expect(
          after.trips.single['boardingLocations'],
          before.trips.single['boardingLocations'],
        );
      },
    );

    test('JavaScript hexadecimal string escapes retain their meaning', () {
      const escapedSource = r'''const tripsData = {
  alpha: {title: "\x41lpha", about: "Gate \x7bA\x7d"},
};''';

      final before = TripsParser.parseTripsDocument(escapedSource);
      expect(before.isValid, isTrue, reason: before.errors.join('\n'));
      expect(before.trips.single['title'], 'Alpha');
      expect(before.trips.single['about'], 'Gate {A}');

      final write = TripsParser.replaceTripsDataObject(
        source: escapedSource,
        trips: before.trips,
      );
      expect(write.success, isTrue, reason: write.error);
      final after = TripsParser.parseTripsDocument(write.content!);
      expect(after.trips.single['title'], 'Alpha');
      expect(after.trips.single['about'], 'Gate {A}');
    });

    test('JavaScript line continuations contribute no character', () {
      const backslash = '\\';
      for (final terminator in <String>['\n', '\r\n', '\u2028', '\u2029']) {
        final continuedSource =
            'const tripsData = {'
            'alpha: {title: "left$backslash${terminator}right"}'
            '};';

        final before = TripsParser.parseTripsDocument(continuedSource);
        expect(before.isValid, isTrue, reason: before.errors.join('\n'));
        expect(before.trips.single['title'], 'leftright');

        final write = TripsParser.replaceTripsDataObject(
          source: continuedSource,
          trips: before.trips,
        );
        expect(write.success, isTrue, reason: write.error);
        final after = TripsParser.parseTripsDocument(write.content!);
        expect(after.isValid, isTrue, reason: after.errors.join('\n'));
        expect(after.trips.single['title'], 'leftright');
      }
    });

    test('raw JavaScript line terminators inside strings block writing', () {
      for (final terminator in <String>['\n', '\r', '\u2028', '\u2029']) {
        final invalidSource =
            'const tripsData = {'
            'alpha: {title: "left${terminator}right"}'
            '};';

        final parsed = TripsParser.parseTripsDocument(invalidSource);
        expect(parsed.isValid, isFalse);
        final write = TripsParser.replaceTripsDataObject(
          source: invalidSource,
          trips: const <Map<String, dynamic>>[
            <String, dynamic>{'id': 'alpha', 'title': 'safe'},
          ],
        );
        expect(write.success, isFalse);
        expect(write.content, isNull);
      }
    });

    test('incomplete, invalid, and legacy numeric escapes are rejected', () {
      const invalidEscapes = <String>[
        r'\x',
        r'\x1',
        r'\xGG',
        r'\x+1',
        r'\x-1',
        r'\u',
        r'\u123',
        r'\uZZZZ',
        r'\u+001',
        r'\u{41}',
        r'\1',
        r'\9',
        r'\01',
        r'\08',
      ];
      for (final escape in invalidEscapes) {
        final invalidSource =
            'const tripsData = {'
            'alpha: {title: "$escape"}'
            '};';

        final parsed = TripsParser.parseTripsDocument(invalidSource);
        expect(parsed.isValid, isFalse, reason: 'accepted $escape');
        final write = TripsParser.replaceTripsDataObject(
          source: invalidSource,
          trips: const <Map<String, dynamic>>[
            <String, dynamic>{'id': 'alpha', 'title': 'safe'},
          ],
        );
        expect(write.success, isFalse, reason: 'rewrote $escape');
        expect(write.content, isNull);
      }
    });

    test('generated line separators are escaped and round-trip safely', () {
      const title = 'Before\u2028Middle\u2029After';
      final generated = TripsParser.generateTripsDataJs(
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'alpha', 'title': title},
        ],
      );

      expect(generated, contains(r'Before\u2028Middle\u2029After'));
      expect(generated, isNot(contains(title)));
      final parsed = TripsParser.parseTripsDocument(generated);
      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
      expect(parsed.trips.single['title'], title);
    });

    test('lone and paired Unicode surrogates round-trip as escapes', () {
      const surrogateSource = r'''// surrogate prefix
const tripsData = {
  lone: {title: "\uD800"},
  pair: {title: "\uD83D\uDE00"},
};
// surrogate suffix
''';
      final before = TripsParser.parseTripsDocument(surrogateSource);
      expect(before.isValid, isTrue, reason: before.errors.join('\n'));
      expect((before.trips[0]['title'] as String).codeUnits, <int>[0xd800]);
      expect((before.trips[1]['title'] as String).codeUnits, <int>[
        0xd83d,
        0xde00,
      ]);

      final write = TripsParser.replaceTripsDataObject(
        source: surrogateSource,
        trips: before.trips,
      );
      expect(write.success, isTrue, reason: write.error);
      expect(write.content, contains(r'title: "\uD800"'));
      expect(write.content, contains(r'title: "\uD83D\uDE00"'));
      expect(
        write.content!.codeUnits.where(
          (codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdfff,
        ),
        isEmpty,
      );
      expect(utf8.decode(utf8.encode(write.content!)), write.content);

      final after = TripsParser.parseTripsDocument(write.content!);
      expect(after.isValid, isTrue, reason: after.errors.join('\n'));
      expect((after.trips[0]['title'] as String).codeUnits, <int>[0xd800]);
      expect((after.trips[1]['title'] as String).codeUnits, <int>[
        0xd83d,
        0xde00,
      ]);
      expect(after.document!.prefix, before.document!.prefix);
      expect(after.document!.suffix, before.document!.suffix);
    });

    test('sparse documents do not gain synthesized canonical fields', () {
      const sparseSource = '''// sparse prefix
const tripsData = {alpha: {title: "Alpha"}};
// sparse suffix
''';
      final before = TripsParser.parseTripsDocument(sparseSource);
      expect(before.isValid, isTrue, reason: before.errors.join('\n'));
      expect(
        before.trips.single.keys,
        unorderedEquals(['id', 'title', 'name']),
      );

      final write = TripsParser.replaceTripsDataObject(
        source: sparseSource,
        trips: before.trips,
      );
      expect(write.success, isTrue, reason: write.error);
      final after = TripsParser.parseTripsDocument(write.content!);
      expect(after.isValid, isTrue, reason: after.errors.join('\n'));
      expect(after.trips.single.keys, unorderedEquals(['id', 'title', 'name']));
      expect(after.document!.prefix, before.document!.prefix);
      expect(after.document!.suffix, before.document!.suffix);
    });

    test('optional-field deletions remain absent in the rewritten source', () {
      const richSource = '''// rich prefix
const tripsData = {
  alpha: {
    title: "Alpha",
    badge: "Trek",
    price: "₹1,000",
    availableDates: ["Aug 14-16, 2026"],
    includes: ["Transport"],
    thingsToCarry: ["Shoes"],
    boardingLocations: [
      {name: "Stop", landmark: "Gate", time: "9 PM", mapLink: "map"},
    ],
    galleryImages: ["one.jpg"],
    featured: false,
    isActive: true,
  },
};
// rich suffix
''';
      final before = TripsParser.parseTripsDocument(richSource);
      expect(before.isValid, isTrue, reason: before.errors.join('\n'));
      final edited = Map<String, dynamic>.from(before.trips.single)
        ..['price'] = '₹1,250'
        ..remove('badge')
        ..remove('availableDates')
        ..remove('date')
        ..remove('inclusions')
        ..remove('thingsToCarry')
        ..remove('boardingLocations')
        ..remove('galleryImages')
        ..remove('featured')
        ..remove('isActive');

      final write = TripsParser.replaceTripsDataObject(
        source: richSource,
        trips: <Map<String, dynamic>>[edited],
      );
      expect(write.success, isTrue, reason: write.error);
      final after = TripsParser.parseTripsDocument(write.content!);
      expect(after.isValid, isTrue, reason: after.errors.join('\n'));
      expect(after.trips.single['price'], '₹1,250');
      for (final field in const <String>[
        'badge',
        'availableDates',
        'inclusions',
        'thingsToCarry',
        'boardingLocations',
        'galleryImages',
        'featured',
        'isActive',
      ]) {
        expect(after.trips.single.containsKey(field), isFalse, reason: field);
      }
      expect(after.document!.prefix, before.document!.prefix);
      expect(after.document!.suffix, before.document!.suffix);
    });

    test('unsafe app-side scalar and nested values produce no content', () {
      const validSource = 'const tripsData = {alpha: {title: "Alpha"}};';
      const base = <String, dynamic>{'id': 'alpha', 'title': 'Alpha'};
      final cases = <({Map<String, dynamic> trip, String message})>[
        (trip: <String, dynamic>{...base, 'id': 7}, message: '"id"'),
        (trip: <String, dynamic>{...base, 'title': 7}, message: '"title"'),
        (trip: <String, dynamic>{...base, 'price': false}, message: '"price"'),
        (
          trip: <String, dynamic>{...base, 'isActive': 'notABool'},
          message: '"isActive"',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'availableDates': <dynamic>[7],
          },
          message: '"availableDates"',
        ),
        (
          trip: <String, dynamic>{...base, 'itinerary': 'not a list'},
          message: '"itinerary"',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'itinerary': <dynamic>['not a map'],
          },
          message: 'must be an object',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'itinerary': <dynamic>[
              <String, dynamic>{
                'day': 'Day 1',
                'title': 'Start',
                'activities': <String>[],
                'notes': 'unsupported',
              },
            ],
          },
          message: 'unsupported fields',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'itinerary': <dynamic>[
              <String, dynamic>{
                'day': false,
                'title': 'Start',
                'activities': <dynamic>[1],
              },
            ],
          },
          message: 'field "day"',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'boardingLocations': <dynamic>['not a map'],
          },
          message: 'must be an object',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'boardingLocations': <dynamic>[
              <String, dynamic>{
                'name': 'Stop',
                'landmark': 'Gate',
                'time': '9 PM',
                'mapLink': 'map',
                'notes': 'unsupported',
              },
            ],
          },
          message: 'unsupported fields',
        ),
        (
          trip: <String, dynamic>{
            ...base,
            'boardingLocations': <dynamic>[
              <String, dynamic>{
                'name': 1,
                'landmark': 'Gate',
                'time': '9 PM',
                'mapLink': 'map',
              },
            ],
          },
          message: 'field "name"',
        ),
      ];

      for (final entry in cases) {
        final write = TripsParser.replaceTripsDataObject(
          source: validSource,
          trips: <Map<String, dynamic>>[entry.trip],
        );
        expect(write.success, isFalse, reason: entry.trip.toString());
        expect(write.content, isNull);
        expect(write.error, contains(entry.message));
        expect(
          () => TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
            entry.trip,
          ]),
          throwsFormatException,
        );
      }
    });

    test('valid app aliases and numeric nested values rewrite and reparse', () {
      const validSource = '''// prefix
const tripsData = {alpha: {title: "Old"}};
// suffix
''';
      final write = TripsParser.replaceTripsDataObject(
        source: validSource,
        trips: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'alpha',
            'name': 'New',
            'price': 1250,
            'groupSize': 20,
            'itinerary': <Map<String, dynamic>>[
              <String, dynamic>{
                'day': 1,
                'title': 'Start',
                'description': 'Breakfast\nTrek',
              },
            ],
            'boardingLocations': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Stop',
                'landmark': 'Gate',
                'time': '9 PM',
                'mapLink': 'map',
              },
            ],
          },
        ],
      );

      expect(write.success, isTrue, reason: write.error);
      final reparsed = TripsParser.parseTripsDocument(write.content!);
      expect(reparsed.isValid, isTrue, reason: reparsed.errors.join('\n'));
      expect(reparsed.trips.single['title'], 'New');
      expect(reparsed.trips.single['price'], '1250');
      expect(reparsed.trips.single['groupSize'], '20');
      expect(
        (reparsed.trips.single['itinerary'] as List).single['activities'],
        <String>['Breakfast', 'Trek'],
      );
      expect(reparsed.document!.prefix, '// prefix\nconst tripsData = ');
      expect(reparsed.document!.suffix, ';\n// suffix\n');
    });

    test('expressions and unsupported nested fields block publication', () {
      const expressionSource = '''const tripsData = {
  alpha: {title: "Alpha", availableDates: buildDates()},
};''';
      final expression = TripsParser.parseTripsDocument(expressionSource);
      expect(expression.isValid, isFalse);
      expect(expression.errors.join('\n'), contains('only literal values'));

      const nestedDrift = '''const tripsData = {
  alpha: {
    title: "Alpha",
    itinerary: [{day: "Day 1", title: "Start", activities: [], notes: "new"}],
  },
};''';
      final drift = TripsParser.parseTripsDocument(nestedDrift);
      expect(drift.isValid, isFalse);
      expect(drift.errors.join('\n'), contains('unsupported fields: [notes]'));
      expect(
        TripsParser.replaceTripsDataObject(
          source: nestedDrift,
          trips: drift.trips,
        ).success,
        isFalse,
      );
    });

    test('generator throws instead of silently deduplicating IDs', () {
      expect(
        () => TripsParser.generateTripsDataJs([
          {'id': 'same', 'title': 'One'},
          {'id': 'same', 'title': 'Two'},
        ]),
        throwsFormatException,
      );
    });
  });

  group('source-preserving featured document', () {
    const source = '''// prefix
const featuredTripIds = ["alpha", 'beta'];
// helper suffix
function getFeaturedTrips() { return featuredTripIds; }
''';

    test('replaces only the array and supports either quote style', () {
      final parsed = TripsParser.parseFeaturedTripsDocument(source);
      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
      expect(parsed.ids, ['alpha', 'beta']);

      final replacement = TripsParser.replaceFeaturedTripIdsArray(
        source: source,
        ids: ['beta', 'gamma'],
      );
      expect(replacement.success, isTrue, reason: replacement.error);

      final updated = replacement.content!;
      final reparsed = TripsParser.parseFeaturedTripsDocument(updated);
      expect(reparsed.ids, ['beta', 'gamma']);
      expect(reparsed.document!.prefix, parsed.document!.prefix);
      expect(reparsed.document!.suffix, parsed.document!.suffix);
    });

    test('duplicate IDs are never silently removed', () {
      final replacement = TripsParser.replaceFeaturedTripIdsArray(
        source: source,
        ids: ['alpha', 'alpha'],
      );
      expect(replacement.success, isFalse);
      expect(replacement.error, contains('Duplicate featured trip IDs'));
    });

    test('declaration-shaped regular expressions are never rewritten', () {
      const regexOnly = r'const matcher = /const featuredTripIds = ["fake"]/;';
      final parsed = TripsParser.parseFeaturedTripsDocument(regexOnly);
      expect(parsed.isValid, isFalse);
      expect(parsed.document, isNull);
      expect(parsed.ids, isEmpty);

      final blocked = TripsParser.replaceFeaturedTripIdsArray(
        source: regexOnly,
        ids: const <String>['safe'],
      );
      expect(blocked.success, isFalse);
      expect(blocked.content, isNull);
    });

    test(
      'declarations inside nested template expressions are never rewritten',
      () {
        const templateOnly = r'''const outer = `prefix ${`
const featuredTripIds = ["decoy"];
`} suffix`;
''';
        final parsed = TripsParser.parseFeaturedTripsDocument(templateOnly);
        expect(parsed.isValid, isFalse);
        expect(parsed.document, isNull);
        expect(parsed.ids, isEmpty);

        final blocked = TripsParser.replaceFeaturedTripIdsArray(
          source: templateOnly,
          ids: const <String>['safe'],
        );
        expect(blocked.success, isFalse);
        expect(blocked.content, isNull);
      },
    );

    test('postfix update followed by division does not hide a declaration', () {
      for (final operator in const <String>['++', '--']) {
        final source = '''const helper = `\${index$operator / count}`;
const featuredTripIds = ["safe"];
''';
        final parsed = TripsParser.parseFeaturedTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$operator: ${parsed.errors.join('\n')}',
        );
        expect(parsed.ids, const <String>['safe']);
      }
    });

    test('regex after expression keywords does not hide a declaration', () {
      for (final expression in const <String>[
        r'for (const x of /`/) {}',
        r'for (holder.item of /`/) { break; }',
        r'for (const x /* ok */ of /`/) { break; }',
        r'for(const{x,y}of/`/){break;}',
        r'for(let[x,y]of/`/){break;}',
        r'class Child extends (() => /`/) {}',
        r'(async () => await /`/)();',
        r'(function* () { yield /`/; })().next();',
      ]) {
        final source = '''const helper = `\${(()=>{ $expression })()}`;
const featuredTripIds = ["safe"];
''';
        final parsed = TripsParser.parseFeaturedTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$expression: ${parsed.errors.join('\n')}',
        );
        expect(parsed.ids, const <String>['safe']);
      }
    });

    test('keyword-named properties keep a following slash as division', () {
      for (final expression in const <String>[
        r'holder.of / count',
        r'holder.extends / count',
        r'holder?.of / count',
      ]) {
        final source = '''const helper = `\${$expression}`;
const featuredTripIds = ["safe"];
''';
        final parsed = TripsParser.parseFeaturedTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$expression: ${parsed.errors.join('\n')}',
        );
        expect(parsed.ids, const <String>['safe']);
      }
    });

    test('classic-script contextual identifiers can be divided', () {
      for (final identifier in const <String>['of', 'await', 'yield']) {
        final source = '''const helper = `\${$identifier / count}`;
const featuredTripIds = ["safe"];
''';
        final parsed = TripsParser.parseFeaturedTripsDocument(source);
        expect(
          parsed.isValid,
          isTrue,
          reason: '$identifier: ${parsed.errors.join('\n')}',
        );
        expect(parsed.ids, const <String>['safe']);
      }
    });

    test('escaped featured IDs reparse without changing surrounding source', () {
      const ids = <String>['quoted"id', 'line\u2028separator'];
      final replacement = TripsParser.replaceFeaturedTripIdsArray(
        source: source,
        ids: ids,
      );

      expect(replacement.success, isTrue, reason: replacement.error);
      final reparsed = TripsParser.parseFeaturedTripsDocument(
        replacement.content!,
      );
      expect(reparsed.isValid, isTrue, reason: reparsed.errors.join('\n'));
      expect(reparsed.ids, ids);
      expect(reparsed.document!.prefix, '// prefix\nconst featuredTripIds = ');
      expect(
        reparsed.document!.suffix,
        ';\n// helper suffix\nfunction getFeaturedTrips() { return featuredTripIds; }\n',
      );
    });

    test('featured generator rejects malformed app booleans', () {
      expect(
        () => TripsParser.generateFeaturedTripsJs(const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'alpha', 'featured': 'notABool'},
        ]),
        throwsFormatException,
      );
    });
  });

  group('GitHub atomic multi-file commit', () {
    late Dio dio;
    late List<RequestOptions> requests;
    late int blobNumber;

    setUp(() {
      requests = [];
      blobNumber = 0;
      dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            dynamic data;
            if (options.method == 'GET' &&
                options.path.endsWith('/git/ref/heads/main')) {
              data = {
                'object': {'sha': 'head-1'},
              };
            } else if (options.method == 'GET' &&
                options.path.endsWith('/git/commits/head-1')) {
              data = {
                'tree': {'sha': 'tree-1'},
              };
            } else if (options.method == 'GET' &&
                options.path.endsWith('/git/trees/tree-1')) {
              data = {
                'truncated': false,
                'tree': [
                  {
                    'path': 'js/trips-data.js',
                    'mode': '100644',
                    'type': 'blob',
                    'sha': 'trips-old',
                  },
                  {
                    'path': 'js/featured-trips.js',
                    'mode': '100644',
                    'type': 'blob',
                    'sha': 'featured-old',
                  },
                ],
              };
            } else if (options.method == 'POST' &&
                options.path.endsWith('/git/blobs')) {
              blobNumber++;
              data = {'sha': 'blob-$blobNumber'};
            } else if (options.method == 'POST' &&
                options.path.endsWith('/git/trees')) {
              data = {'sha': 'tree-2'};
            } else if (options.method == 'POST' &&
                options.path.endsWith('/git/commits')) {
              data = {'sha': 'commit-2'};
            } else if (options.method == 'PATCH' &&
                options.path.endsWith('/git/refs/heads/main')) {
              data = {
                'object': {'sha': 'commit-2'},
              };
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Unexpected request ${options.method} ${options.path}',
                ),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: data,
              ),
            );
          },
        ),
      );
    });

    GitHubService service() => GitHubService(
      settings: AppSettings(
        githubToken: 'test-token',
        repositoryOwner: 'owner',
        repositoryName: 'repo',
        branch: 'main',
      ),
      dio: dio,
    );

    test('creates both replacements in one non-force commit', () async {
      final result = await service().commitFilesAtomically(
        files: {
          'js/trips-data.js': 'new trips',
          'js/featured-trips.js': 'new featured',
        },
        expectedBlobShas: {
          'js/trips-data.js': 'trips-old',
          'js/featured-trips.js': 'featured-old',
        },
        commitMessage: 'Update trips',
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.commitSha, 'commit-2');
      expect(result.baseCommitSha, 'head-1');
      expect(result.fileBlobShas, {
        'js/trips-data.js': 'blob-1',
        'js/featured-trips.js': 'blob-2',
      });

      final blobRequests = requests.where(
        (request) =>
            request.method == 'POST' && request.path.endsWith('/git/blobs'),
      );
      expect(blobRequests, hasLength(2));
      expect(
        utf8.decode(
          base64.decode(
            (blobRequests.first.data as Map<String, dynamic>)['content']
                as String,
          ),
        ),
        'new trips',
      );

      final commit = requests.singleWhere(
        (request) =>
            request.method == 'POST' && request.path.endsWith('/git/commits'),
      );
      expect((commit.data as Map<String, dynamic>)['parents'], ['head-1']);

      final refUpdate = requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect((refUpdate.data as Map<String, dynamic>)['force'], isFalse);
    });

    test(
      'blob mismatch returns conflict before creating Git objects',
      () async {
        final result = await service().commitFilesAtomically(
          files: {'js/trips-data.js': 'new trips'},
          expectedBlobShas: {'js/trips-data.js': 'stale-sha'},
          commitMessage: 'Update trips',
        );

        expect(result.success, isFalse);
        expect(result.hasConflict, isTrue);
        expect(result.error, contains('Remote files changed'));
        expect(requests.where((request) => request.method == 'POST'), isEmpty);
        expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
      },
    );

    test('a raced ref update is surfaced as a conflict', () async {
      dio.interceptors.clear();
      requests = [];
      blobNumber = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.method == 'PATCH') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 422,
                    data: {'message': 'Update is not a fast forward'},
                  ),
                ),
              );
              return;
            }
            dynamic data;
            if (options.path.endsWith('/git/ref/heads/main')) {
              data = {
                'object': {'sha': 'head-1'},
              };
            } else if (options.path.endsWith('/git/commits/head-1')) {
              data = {
                'tree': {'sha': 'tree-1'},
              };
            } else if (options.method == 'GET') {
              data = {
                'truncated': false,
                'tree': [
                  {
                    'path': 'js/trips-data.js',
                    'mode': '100644',
                    'type': 'blob',
                    'sha': 'trips-old',
                  },
                ],
              };
            } else if (options.path.endsWith('/git/blobs')) {
              data = {'sha': 'blob-1'};
            } else if (options.path.endsWith('/git/trees')) {
              data = {'sha': 'tree-2'};
            } else {
              data = {'sha': 'commit-2'};
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: data,
              ),
            );
          },
        ),
      );

      final result = await service().commitFilesAtomically(
        files: {'js/trips-data.js': 'new trips'},
        expectedBlobShas: {'js/trips-data.js': 'trips-old'},
        commitMessage: 'Update trips',
      );

      expect(result.success, isFalse);
      expect(result.hasConflict, isTrue);
      expect(result.error, contains('branch changed'));
      final refUpdate = requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect((refUpdate.data as Map<String, dynamic>)['force'], isFalse);
    });
  });
}
