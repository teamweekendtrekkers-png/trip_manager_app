import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trip_merge_service.dart';

Map<String, dynamic> trip(
  String id, {
  String title = '',
  String price = '₹1',
  bool featured = false,
  bool active = true,
}) => {
  'id': id,
  'title': title.isEmpty ? id : title,
  'price': price,
  'featured': featured,
  'isActive': active,
  'availableDates': <String>[],
};

Map<String, dynamic> withPriority(Map<String, dynamic> value, int priority) => {
  ...value,
  'featured': priority == 2,
  'isActive': priority != 0,
};

int priorityOf(Map<String, dynamic> value) {
  if (value['isActive'] == false) return 0;
  return value['featured'] == true ? 2 : 1;
}

List<List<T>> permutations<T>(List<T> values) {
  if (values.length < 2) return [List<T>.of(values)];
  final result = <List<T>>[];
  for (var index = 0; index < values.length; index++) {
    final remaining = List<T>.of(values)..removeAt(index);
    for (final tail in permutations(remaining)) {
      result.add(<T>[values[index], ...tail]);
    }
  }
  return result;
}

void main() {
  group('TripMergeService', () {
    test('merges edits to different fields', () {
      final base = [trip('a', title: 'Old', price: '₹1')];
      final local = [trip('a', title: 'Local', price: '₹1')];
      final remote = [trip('a', title: 'Old', price: '₹2')];

      final result = TripMergeService.merge(
        base: base,
        local: local,
        remote: remote,
      );

      expect(result.success, isTrue);
      expect(result.trips.single['title'], 'Local');
      expect(result.trips.single['price'], '₹2');
    });

    test('field-only merge preserves the interleaved backing order', () {
      final base = [
        trip('active-a'),
        trip('featured-f', featured: true),
        trip('inactive-i', active: false),
        trip('active-b'),
      ];
      final local = [
        {...base[0], 'title': 'Locally edited'},
        base[1],
        base[2],
        base[3],
      ];
      final remote = [
        base[0],
        base[1],
        base[2],
        {...base[3], 'price': '₹2'},
      ];

      final result = TripMergeService.merge(
        base: base,
        local: local,
        remote: remote,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), [
        'active-a',
        'featured-f',
        'inactive-i',
        'active-b',
      ]);
    });

    test('preserves a remote field deletion beside a local edit', () {
      final baseTrip = <String, dynamic>{
        ...trip('a', price: '₹1'),
        'badge': 'Trek',
      };
      final localTrip = <String, dynamic>{...baseTrip, 'price': '₹2'};
      final remoteTrip = <String, dynamic>{...baseTrip}..remove('badge');

      final result = TripMergeService.merge(
        base: [baseTrip],
        local: [localTrip],
        remote: [remoteTrip],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.single['price'], '₹2');
      expect(result.trips.single.containsKey('badge'), isFalse);
    });

    test('preserves a local field deletion beside a remote edit', () {
      final baseTrip = <String, dynamic>{
        ...trip('a', price: '₹1'),
        'badge': 'Trek',
      };
      final localTrip = <String, dynamic>{...baseTrip}..remove('badge');
      final remoteTrip = <String, dynamic>{...baseTrip, 'price': '₹2'};

      final result = TripMergeService.merge(
        base: [baseTrip],
        local: [localTrip],
        remote: [remoteTrip],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.single['price'], '₹2');
      expect(result.trips.single.containsKey('badge'), isFalse);
    });

    test('distinguishes an explicit null from an absent field', () {
      final baseTrip = <String, dynamic>{...trip('a'), 'badge': 'Trek'};
      final localTrip = <String, dynamic>{...baseTrip, 'badge': null};
      final unchangedRemote = <String, dynamic>{...baseTrip};

      final result = TripMergeService.merge(
        base: [baseTrip],
        local: [localTrip],
        remote: [unchangedRemote],
      );
      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.single.containsKey('badge'), isTrue);
      expect(result.trips.single['badge'], isNull);

      final deletedRemote = <String, dynamic>{...baseTrip}..remove('badge');
      final conflict = TripMergeService.merge(
        base: [baseTrip],
        local: [localTrip],
        remote: [deletedRemote],
      );
      expect(conflict.success, isFalse);
      expect(conflict.conflicts.join('\n'), contains('field "badge"'));
    });

    test('blocks edits to the same field', () {
      final result = TripMergeService.merge(
        base: [trip('a', title: 'Old')],
        local: [trip('a', title: 'Local')],
        remote: [trip('a', title: 'Remote')],
      );

      expect(result.success, isFalse);
      expect(result.conflicts.single, contains('field "title"'));
    });

    test('preserves intentional delete when remote is unchanged', () {
      final result = TripMergeService.merge(
        base: [trip('a'), trip('b')],
        local: [trip('b')],
        remote: [trip('a'), trip('b')],
        intentionalDeletedIds: {'a'},
      );

      expect(result.success, isTrue);
      expect(result.trips.map((value) => value['id']), ['b']);
    });

    test('blocks unexplained disappearance', () {
      final result = TripMergeService.merge(
        base: [trip('a')],
        local: const [],
        remote: [trip('a')],
      );

      expect(result.success, isFalse);
      expect(
        result.conflicts,
        contains(contains('without an intentional delete')),
      );
    });

    test('ignores backing moves that do not change any within-tier order', () {
      final activeA = trip('active-a');
      final featuredF = trip('featured-f', featured: true);
      final activeB = trip('active-b');
      final base = [activeA, featuredF, activeB];

      final result = TripMergeService.merge(
        base: base,
        local: [featuredF, activeA, activeB],
        remote: base,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), [
        'active-a',
        'featured-f',
        'active-b',
      ]);
    });

    test('blocks delete versus remote edit', () {
      final result = TripMergeService.merge(
        base: [trip('a', title: 'Old')],
        local: const [],
        remote: [trip('a', title: 'Remote')],
        intentionalDeletedIds: {'a'},
      );

      expect(result.success, isFalse);
      expect(
        result.conflicts,
        contains(contains('deleted locally but edited remotely')),
      );
    });

    test('combines independent additions', () {
      final result = TripMergeService.merge(
        base: [trip('a')],
        local: [trip('a'), trip('local')],
        remote: [trip('a'), trip('remote')],
      );

      expect(result.success, isTrue);
      expect(result.trips.map((value) => value['id']).toSet(), {
        'a',
        'local',
        'remote',
      });
    });

    test('preserves a new trip insertion within its destination tier', () {
      final base = [trip('a'), trip('b')];
      final added = trip('new');

      final result = TripMergeService.merge(
        base: base,
        local: [base[0], added, base[1]],
        remote: base,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), ['a', 'new', 'b']);
    });

    test('blocks incompatible concurrent reorders', () {
      final base = [trip('a'), trip('b'), trip('c')];
      final result = TripMergeService.merge(
        base: base,
        local: [trip('b'), trip('a'), trip('c')],
        remote: [trip('a'), trip('c'), trip('b')],
      );

      expect(result.success, isFalse);
      expect(result.conflicts.join('\n'), contains('cycle'));
    });

    test('combines independent ordering changes', () {
      final base = [trip('a'), trip('b'), trip('c'), trip('d')];

      final result = TripMergeService.merge(
        base: base,
        local: [base[1], base[0], base[2], base[3]],
        remote: [base[0], base[1], base[3], base[2]],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), ['b', 'a', 'd', 'c']);
    });

    test('merges independent reorders in different priority tiers', () {
      final activeA = trip('active-a');
      final featuredF = trip('featured-f', featured: true);
      final activeB = trip('active-b');
      final featuredG = trip('featured-g', featured: true);
      final base = [activeA, featuredF, activeB, featuredG];

      final result = TripMergeService.merge(
        base: base,
        local: [activeB, featuredF, activeA, featuredG],
        remote: [activeA, featuredG, activeB, featuredF],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['featured'] == true)
            .map((value) => value['id']),
        ['featured-g', 'featured-f'],
      );
      expect(
        result.trips
            .where(
              (value) =>
                  value['featured'] != true && value['isActive'] != false,
            )
            .map((value) => value['id']),
        ['active-b', 'active-a'],
      );
      expect(result.trips.map((value) => value['id']), [
        'active-b',
        'featured-g',
        'active-a',
        'featured-f',
      ]);
    });

    test('combines a tier move with a remote reorder in the target tier', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final base = [featuredF, activeA, featuredG];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredF,
          {...activeA, 'featured': true},
          featuredG,
        ],
        remote: [featuredG, activeA, featuredF],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['featured'] == true)
            .map((value) => value['id']),
        ['featured-g', 'featured-f', 'active-a'],
      );
    });

    test(
      'preserves a tier move insertion when the target tier is unchanged',
      () {
        final featuredF = trip('featured-f', featured: true);
        final activeA = trip('active-a');
        final featuredG = trip('featured-g', featured: true);
        final base = [featuredF, activeA, featuredG];

        final result = TripMergeService.merge(
          base: base,
          local: [
            featuredF,
            {...activeA, 'featured': true},
            featuredG,
          ],
          remote: base,
        );

        expect(result.success, isTrue, reason: result.conflicts.join('\n'));
        expect(
          result.trips
              .where((value) => value['featured'] == true)
              .map((value) => value['id']),
          ['featured-f', 'active-a', 'featured-g'],
        );
      },
    );

    test('combines entrants inserted independently from both sides', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final activeB = trip('active-b');
      final base = [featuredF, activeA, featuredG, activeB];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredF,
          {...activeA, 'featured': true},
          featuredG,
          activeB,
        ],
        remote: [
          featuredF,
          activeA,
          featuredG,
          {...activeB, 'featured': true},
        ],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['featured'] == true)
            .map((value) => value['id']),
        ['featured-f', 'active-a', 'featured-g', 'active-b'],
      );
    });

    test('preserves a one-sided move and reorder into another tier', () {
      final activeA = trip('active-a');
      final inactiveB = trip('inactive-b', active: false);
      final inactiveC = trip('inactive-c', active: false);
      final inactiveD = trip('inactive-d', active: false);
      final base = [activeA, inactiveB, inactiveC, inactiveD];

      final result = TripMergeService.merge(
        base: base,
        local: [
          {...activeA, 'isActive': false},
          inactiveB,
          inactiveD,
          inactiveC,
        ],
        remote: base,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['isActive'] == false)
            .map((value) => value['id']),
        ['active-a', 'inactive-b', 'inactive-d', 'inactive-c'],
      );
    });

    test('preserves moved-trip insertion beside a target-tier reorder', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final base = [featuredF, activeA, featuredG];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredG,
          {...activeA, 'featured': true},
          featuredF,
        ],
        remote: base,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), [
        'featured-g',
        'active-a',
        'featured-f',
      ]);
    });

    test('blocks new-trip insertion against a reversed destination tier', () {
      final featuredF = trip('featured-f', featured: true);
      final featuredG = trip('featured-g', featured: true);
      final added = trip('new', featured: true);
      final base = [featuredF, featuredG];

      final result = TripMergeService.merge(
        base: base,
        local: [featuredF, added, featuredG],
        remote: [featuredG, featuredF],
      );

      expect(result.success, isFalse);
      expect(result.conflicts.join('\n'), contains('cycle'));
    });

    test('preserves a new insertion while its whole origin moves tiers', () {
      final activeA = trip('active-a');
      final activeB = trip('active-b');
      final added = trip('new', featured: true);
      final base = [activeA, activeB];

      final result = TripMergeService.merge(
        base: base,
        local: [
          {...activeA, 'featured': true},
          added,
          {...activeB, 'featured': true},
        ],
        remote: base,
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), [
        'active-a',
        'new',
        'active-b',
      ]);
    });

    test('retains concurrent moved and new entrants in the same gap', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final added = trip('new', featured: true);
      final base = [featuredF, activeA, featuredG];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredF,
          {...activeA, 'featured': true},
          featuredG,
        ],
        remote: [featuredF, activeA, added, featuredG],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      final featuredIds = result.trips
          .where((value) => value['featured'] == true)
          .map((value) => value['id'])
          .toList();
      expect(featuredIds.first, 'featured-f');
      expect(featuredIds.last, 'featured-g');
      expect(featuredIds.sublist(1, 3).toSet(), {'active-a', 'new'});
    });

    test('keeps insertion anchors when an unrelated origin is reordered', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final activeB = trip('active-b');
      final inactiveX = trip('inactive-x', active: false);
      final inactiveY = trip('inactive-y', active: false);
      final base = [
        featuredF,
        activeA,
        featuredG,
        activeB,
        inactiveX,
        inactiveY,
      ];
      final activeEntrants = [
        featuredF,
        {...activeA, 'featured': true},
        featuredG,
        {...activeB, 'featured': true},
        inactiveX,
        inactiveY,
      ];
      final inactiveEntrants = [
        featuredF,
        activeA,
        {...inactiveY, 'featured': true, 'isActive': true},
        featuredG,
        activeB,
        {...inactiveX, 'featured': true, 'isActive': true},
      ];

      for (final swapSides in const [false, true]) {
        final result = TripMergeService.merge(
          base: base,
          local: swapSides ? inactiveEntrants : activeEntrants,
          remote: swapSides ? activeEntrants : inactiveEntrants,
        );

        expect(result.success, isTrue, reason: result.conflicts.join('\n'));
        expect(
          result.trips
              .where((value) => value['featured'] == true)
              .map((value) => value['id']),
          [
            'featured-f',
            'active-a',
            'inactive-y',
            'featured-g',
            'active-b',
            'inactive-x',
          ],
          reason: 'swapSides=$swapSides',
        );
      }
    });

    test('blocks opposite orders for a newly shared tier', () {
      final activeA = trip('active-a');
      final inactiveX = trip('inactive-x', active: false);
      final base = [activeA, inactiveX];
      final movedA = {...activeA, 'featured': true};
      final movedX = {...inactiveX, 'featured': true, 'isActive': true};

      final result = TripMergeService.merge(
        base: base,
        local: [movedA, movedX],
        remote: [movedX, movedA],
      );

      expect(result.success, isFalse);
      expect(result.conflicts.join('\n'), contains('changed differently'));
    });

    test('substitutes a reordered origin through moved-trip slots', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final activeB = trip('active-b');
      final base = [featuredF, activeA, featuredG, activeB];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredF,
          {...activeA, 'featured': true},
          featuredG,
          {...activeB, 'featured': true},
        ],
        remote: [featuredF, activeB, featuredG, activeA],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['featured'] == true)
            .map((value) => value['id']),
        ['featured-f', 'active-b', 'featured-g', 'active-a'],
      );
    });

    test('preserves a full target-tier origin slot pattern', () {
      final activeA = trip('active-a');
      final inactiveX = trip('inactive-x', active: false);
      final activeB = trip('active-b');
      final inactiveY = trip('inactive-y', active: false);
      final base = [activeA, inactiveX, activeB, inactiveY];

      final result = TripMergeService.merge(
        base: base,
        local: [
          {...inactiveX, 'featured': true, 'isActive': true},
          {...activeA, 'featured': true},
          {...inactiveY, 'featured': true, 'isActive': true},
          {...activeB, 'featured': true},
        ],
        remote: [activeB, inactiveY, activeA, inactiveX],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(result.trips.map((value) => value['id']), [
        'inactive-y',
        'active-b',
        'inactive-x',
        'active-a',
      ]);
    });

    test('blocks a longer insertion-anchor cycle across three origins', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final inactiveX = trip('inactive-x', active: false);
      final base = [featuredF, activeA, inactiveX];
      final movedA = {...activeA, 'featured': true};
      final movedX = {...inactiveX, 'featured': true, 'isActive': true};

      final result = TripMergeService.merge(
        base: base,
        local: [featuredF, movedA, movedX],
        remote: [movedX, featuredF, movedA],
      );

      expect(result.success, isFalse);
      expect(result.conflicts.join('\n'), contains('cycle'));
    });

    test('retains the order of multiple entrants during a tier reorder', () {
      final featuredF = trip('featured-f', featured: true);
      final activeA = trip('active-a');
      final featuredG = trip('featured-g', featured: true);
      final activeB = trip('active-b');
      final base = [featuredF, activeA, featuredG, activeB];

      final result = TripMergeService.merge(
        base: base,
        local: [
          featuredF,
          {...activeB, 'featured': true},
          featuredG,
          {...activeA, 'featured': true},
        ],
        remote: [featuredG, activeA, featuredF, activeB],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      expect(
        result.trips
            .where((value) => value['featured'] == true)
            .map((value) => value['id']),
        ['featured-g', 'featured-f', 'active-b', 'active-a'],
      );
    });

    test('merges reorders from multiple origin tiers after all move tiers', () {
      final activeA = trip('active-a');
      final inactiveX = trip('inactive-x', active: false);
      final activeB = trip('active-b');
      final inactiveY = trip('inactive-y', active: false);
      final base = [activeA, inactiveX, activeB, inactiveY];
      final moved = <String, Map<String, dynamic>>{
        for (final value in base)
          value['id'] as String: {...value, 'featured': true, 'isActive': true},
      };

      final result = TripMergeService.merge(
        base: base,
        local: [
          moved['active-a']!,
          moved['inactive-x']!,
          moved['active-b']!,
          moved['inactive-y']!,
        ],
        remote: [activeB, inactiveY, activeA, inactiveX],
      );

      expect(result.success, isTrue, reason: result.conflicts.join('\n'));
      final ids = result.trips.map((value) => value['id']).toList();
      expect(ids.indexOf('active-b'), lessThan(ids.indexOf('active-a')));
      expect(ids.indexOf('inactive-y'), lessThan(ids.indexOf('inactive-x')));
      expect(ids, ['active-b', 'inactive-y', 'active-a', 'inactive-x']);
    });

    test(
      'cross-origin backing interleavings do not affect merged tier order',
      () {
        final activeA = trip('active-a');
        final inactiveX = trip('inactive-x', active: false);
        final activeB = trip('active-b');
        final inactiveY = trip('inactive-y', active: false);
        final base = [activeA, inactiveX, activeB, inactiveY];
        final moved = <String, Map<String, dynamic>>{
          for (final value in base)
            value['id'] as String: {
              ...value,
              'featured': true,
              'isActive': true,
            },
        };
        final localInterleavings = <List<Map<String, dynamic>>>[
          [
            moved['active-a']!,
            moved['inactive-x']!,
            moved['active-b']!,
            moved['inactive-y']!,
          ],
          [
            moved['inactive-x']!,
            moved['active-a']!,
            moved['inactive-y']!,
            moved['active-b']!,
          ],
        ];
        final remoteInterleavings = <List<Map<String, dynamic>>>[
          [activeB, inactiveY, activeA, inactiveX],
          [inactiveY, activeB, inactiveX, activeA],
          [activeB, activeA, inactiveY, inactiveX],
          [inactiveY, inactiveX, activeB, activeA],
        ];

        for (final local in localInterleavings) {
          for (final remote in remoteInterleavings) {
            final result = TripMergeService.merge(
              base: base,
              local: local,
              remote: remote,
            );

            expect(
              result.success,
              isTrue,
              reason:
                  'local=${local.map((trip) => trip['id']).join(',')} '
                  'remote=${remote.map((trip) => trip['id']).join(',')}: '
                  '${result.conflicts.join('; ')}',
            );
            final activeOrder = remote
                .where((trip) => trip['isActive'] != false)
                .map((trip) => trip['id'].toString())
                .toList();
            final inactiveOrder = remote
                .where((trip) => trip['isActive'] == false)
                .map((trip) => trip['id'].toString())
                .toList();
            var activeCursor = 0;
            var inactiveCursor = 0;
            final expected = [
              for (final trip in local)
                if ((trip['id'] as String).startsWith('active-'))
                  activeOrder[activeCursor++]
                else
                  inactiveOrder[inactiveCursor++],
            ];
            expect(result.trips.map((value) => value['id']), expected);
          }
        }
      },
    );

    test(
      'every full origin-slot pattern consumes independent origin reorders',
      () {
        final activeA = trip('active-a');
        final inactiveX = trip('inactive-x', active: false);
        final activeB = trip('active-b');
        final inactiveY = trip('inactive-y', active: false);
        final base = [activeA, inactiveX, activeB, inactiveY];
        final byId = {for (final value in base) value['id'] as String: value};
        final slotPatterns = <List<bool>>[
          [true, true, false, false],
          [true, false, true, false],
          [true, false, false, true],
          [false, true, true, false],
          [false, true, false, true],
          [false, false, true, true],
        ];
        final activeOrders = <List<String>>[
          ['active-a', 'active-b'],
          ['active-b', 'active-a'],
        ];
        final inactiveOrders = <List<String>>[
          ['inactive-x', 'inactive-y'],
          ['inactive-y', 'inactive-x'],
        ];

        for (final slots in slotPatterns) {
          final changedActive = <String>['active-a', 'active-b'];
          final changedInactive = <String>['inactive-x', 'inactive-y'];
          var changedActiveCursor = 0;
          var changedInactiveCursor = 0;
          final moved = [
            for (final activeSlot in slots)
              withPriority(
                byId[activeSlot
                    ? changedActive[changedActiveCursor++]
                    : changedInactive[changedInactiveCursor++]]!,
                2,
              ),
          ];

          for (final activeOrder in activeOrders) {
            for (final inactiveOrder in inactiveOrders) {
              final unchangedStatuses = [
                byId[activeOrder[0]]!,
                byId[inactiveOrder[0]]!,
                byId[activeOrder[1]]!,
                byId[inactiveOrder[1]]!,
              ];
              var expectedActiveCursor = 0;
              var expectedInactiveCursor = 0;
              final expected = [
                for (final activeSlot in slots)
                  activeSlot
                      ? activeOrder[expectedActiveCursor++]
                      : inactiveOrder[expectedInactiveCursor++],
              ];

              for (final movedIsLocal in const [true, false]) {
                final result = TripMergeService.merge(
                  base: base,
                  local: movedIsLocal ? moved : unchangedStatuses,
                  remote: movedIsLocal ? unchangedStatuses : moved,
                );
                expect(
                  result.success,
                  isTrue,
                  reason:
                      'slots=$slots active=$activeOrder '
                      'inactive=$inactiveOrder movedIsLocal=$movedIsLocal: '
                      '${result.conflicts.join('; ')}',
                );
                expect(
                  result.trips.map((value) => value['id']),
                  expected,
                  reason:
                      'slots=$slots active=$activeOrder '
                      'inactive=$inactiveOrder movedIsLocal=$movedIsLocal',
                );
              }
            }
          }
        }
      },
    );

    test(
      'an unchanged side preserves every valid n=4 tier move and reorder',
      () {
        final base = [
          trip('a', featured: true),
          trip('b'),
          trip('c', active: false),
          trip('d', active: false),
        ];
        final byId = {for (final value in base) value['id'] as String: value};
        final idOrders = permutations(byId.keys.toList());

        // 3^4 final tier assignments × 4! backing orders, in both merge
        // directions. This proves the unchanged side is an identity for every
        // semantically valid derived order of four existing trips.
        for (var assignment = 0; assignment < 81; assignment++) {
          var encoded = assignment;
          final priorities = <String, int>{};
          for (final id in byId.keys) {
            priorities[id] = encoded % 3;
            encoded ~/= 3;
          }
          for (final ids in idOrders) {
            final changed = [
              for (final id in ids) withPriority(byId[id]!, priorities[id]!),
            ];
            for (final localOnly in const [true, false]) {
              final result = TripMergeService.merge(
                base: base,
                local: localOnly ? changed : base,
                remote: localOnly ? base : changed,
              );

              expect(
                result.success,
                isTrue,
                reason:
                    'assignment=$assignment ids=${ids.join(',')} '
                    'localOnly=$localOnly: ${result.conflicts.join('; ')}',
              );
              for (final priority in const [2, 1, 0]) {
                expect(
                  result.trips
                      .where((value) => priorityOf(value) == priority)
                      .map((value) => value['id']),
                  changed
                      .where((value) => priorityOf(value) == priority)
                      .map((value) => value['id']),
                  reason:
                      'assignment=$assignment ids=${ids.join(',')} '
                      'priority=$priority localOnly=$localOnly',
                );
              }
            }
          }
        }
      },
    );
  });
}
