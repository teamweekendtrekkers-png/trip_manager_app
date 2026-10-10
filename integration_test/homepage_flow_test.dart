import 'package:integration_test/integration_test.dart';
import '../test/homepage_settings_test.dart' as homepage;

// The production editor, with in-memory GitHub and image fixtures only.
// No requests or writes are made to the live website.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  homepage.main();
}
