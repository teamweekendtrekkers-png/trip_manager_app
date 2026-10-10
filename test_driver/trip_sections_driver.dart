import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = await Directory.systemTemp.createTemp(
    'twt-trip-sections-device-',
  );
  stdout.writeln('Trip section screenshots: ${output.path}');
  await integrationDriver(
    responseDataCallback: (_) async {},
    onScreenshot: (name, bytes, [args]) async {
      if (!const ['trip-sections-light', 'trip-sections-dark'].contains(name)) {
        throw StateError('Unexpected screenshot name: $name');
      }
      if (bytes.length < 8 || bytes[0] != 137 || bytes[1] != 80) return false;
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
