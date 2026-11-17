import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/manager_page_layout.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('cards stay readable at $width with enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: ManagerPageBody(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ManagerCardGrid(
                      minWidth: 150,
                      children: [
                        for (var i = 0; i < 5; i++)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Unpublished trip changes $i'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Unpublished trip changes 4'));
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(ManagerPageBody));
      expect(box.width, lessThanOrEqualTo(width));
    });
  }

  testWidgets(
    'phone section picker changes section and follows search selection',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var selection = 'All';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ManagerSectionPicker(
                    sections: const ['All', 'Hero', 'Reviews'],
                    selected: selection,
                    onChanged: (value) => setState(() => selection = value),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('homepage-section-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reviews').last);
      await tester.pumpAndSettle();
      expect(selection, 'Reviews');
      update(() => selection = 'Trip gallery');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Trip gallery'), findsWidgets);
    },
  );
}
