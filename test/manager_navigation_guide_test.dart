import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/manager_navigation.dart';

void main() {
  testWidgets('guide shows a task path and opens its workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ManagerDestination? selected;
    String? selectedSection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManagerGuideButton(
            onSelected: (value, {section}) {
              selected = value;
              selectedSection = section;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.text('Manager guide'), findsOneWidget);
    await tester.tap(find.text('Website editing'));
    await tester.pumpAndSettle();
    expect(
      find.text('Website content → Hero → Story highlights'),
      findsOneWidget,
    );
    await tester.tap(find.text('Edit Instagram highlights'));
    await tester.pumpAndSettle();
    expect(selected, ManagerDestination.homepage);
    expect(selectedSection, 'Story highlights');
    expect(find.text('Manager guide'), findsNothing);
  });
}
