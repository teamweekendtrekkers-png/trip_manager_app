import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Text rasterization differs between the Windows and Linux Flutter engines.
/// Keep exact comparison on each host; never add tolerance or skip goldens.
Matcher platformGolden(String path) => matchesGoldenFile(
  Platform.isWindows ? path.replaceFirst('goldens/', 'goldens/windows/') : path,
);
