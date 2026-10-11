import 'dart:io';
import 'dart:ui' as ui;

/// Advisory only; original bytes are always retained.
Future<String?> photoResolutionAdvice(File file, {required int minWidth}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width < minWidth) {
      return 'This photo is ' + descriptor.width.toString() + ' × ' + descriptor.height.toString() + ' px. For a clearer crop, choose a photo at least $minWidth px wide.';
    }
  } catch (_) {
    // Preview or website validation can explain an unsupported format.
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
  return null;
}
