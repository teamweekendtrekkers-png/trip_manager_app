import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// These fixture suites use tester.enterText, not native IME automation.
/// Keep the keyboard channel consistent with that simulated input so Gboard
/// cannot asynchronously overwrite a fixture edit with its previous value.
void registerFixtureKeyboard() {
  // flutter test initializes the integration binding before invoking main.
  // Register/unregister the input stub per test without replacing that binding.
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);
}
