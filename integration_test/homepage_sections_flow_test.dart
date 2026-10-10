import 'package:integration_test/integration_test.dart';
import '../test/homepage_sections_test.dart' as sections;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sections.main();
}
