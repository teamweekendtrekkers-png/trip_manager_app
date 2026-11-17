import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/manager_navigation.dart';

void main() {
  test('task words locate tools without knowing menu names', () {
    expect(findManagerTools('animation'), [ManagerDestination.homepage]);
    expect(findManagerTools('coupon'), [ManagerDestination.payments]);
    expect(findManagerTools('refund'), [ManagerDestination.sharedContent]);
    expect(findManagerTools('sold out'), [
      ManagerDestination.departureManagement,
    ]);
    expect(findManagerTools('   '), managerNavigationOrder);
    expect(findManagerTools('unknown thing'), isEmpty);
  });

  testWidgets('phone search supports selection, clearing and empty results', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ManagerDestination? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManagerToolFinder(onSelected: (d) => chosen = d)),
      ),
    );
    await tester.tap(find.byKey(const Key('find-manager-tool')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('manager-tool-search')),
      'unknown thing',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching tools.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear tool search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('manager-tool-search')),
      'coupon',
    );
    await tester.pumpAndSettle();
    expect(find.text('Payments & coupons'), findsOneWidget);
    await tester.tap(find.text('Payments & coupons'));
    await tester.pumpAndSettle();
    expect(chosen, ManagerDestination.payments);
    expect(find.byKey(const Key('manager-tool-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard search opens the first matching tool and cancel does nothing',
    (tester) async {
      ManagerDestination? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagerToolFinder(onSelected: (d) => chosen = d),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('find-manager-tool')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close tool finder'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      await tester.tap(find.byKey(const Key('find-manager-tool')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('manager-tool-search')),
        'publish',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(chosen, ManagerDestination.deployment);
    },
  );
}
