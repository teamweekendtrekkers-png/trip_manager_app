import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/screens/analytics_screen.dart';
import 'package:trip_manager_app/services/booking_review_service.dart';
import 'booking_review_service_test.dart' show BookingConfig;

class FakeAnalytics extends BookingReviewService {
  FakeAnalytics() : super(BookingConfig());
  bool fail = false;
  String selectedTrip = '', selectedDevice = '';
  @override bool get signedIn => true;
  @override Future<Map<String, dynamic>> analytics({required String start, required String end, String trip = '', String device = ''}) async {
    selectedTrip = trip; selectedDevice = device;
    if (fail) throw StateError('Analytics unavailable');
    return {
      'sessions': 100, 'launched_at': '2026-10-21T00:00:00Z', 'direct_checkout': 8,
      'trip_options': ['kannur-theyyam', 'coorg'],
      'funnel': [
        {'label':'Viewed a trip','count':80}, {'label':'Selected a date','count':60},
        {'label':'Opened checkout','count':40}, {'label':'Reached UPI payment','count':30},
        {'label':'Submitted payment details','count':12},
      ],
      'trips':[{'trip_id':'kannur-theyyam','views':50,'checkouts':30,'submissions':10}],
      'sources':[{'source':'instagram','sessions':60,'submissions':8}],
      'devices':[{'device':'mobile','sessions':75,'submissions':10}],
      'daily':[{'day':'2026-10-21','sessions':20,'submissions':3}],
      'errors':[], 'engagement':{'upi_copied':20,'qr_downloaded':5}, 'requests':2,
      'review':{'submitted':20,'pending':3,'verified':15,'rejected':2,'average_review_hours':2.1},
    };
  }
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('analytics fits $width and displays an ordered funnel', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final file=File(Platform.isWindows?'C:/Windows/Fonts/arial.ttf':'/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
        if(await file.exists())await (FontLoader('AnalyticsPreview')..addFont(file.readAsBytes().then((b)=>ByteData.sublistView(b)))).load();
      });
      final service=FakeAnalytics(); final key=GlobalKey();
      await tester.pumpWidget(MaterialApp(theme:ThemeData(fontFamily:'AnalyticsPreview'),home:RepaintBoundary(key:key,child:AnalyticsScreen(service:service))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Where visitors leave')); await tester.pumpAndSettle();
      expect(find.text('Where visitors leave'),findsOneWidget);
      expect(find.textContaining('20 have not reached the next step'),findsWidgets);
      expect(tester.takeException(),isNull);
      await tester.runAsync(() async {
        final boundary=key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image=await boundary.toImage(pixelRatio:1);
        final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
        Directory('build/reviews').createSync(recursive:true);
        File('build/reviews/analytics-${width.toInt()}.png').writeAsBytesSync(bytes!.buffer.asUint8List()); image.dispose();
      });
      await tester.ensureVisible(find.text('All devices'));await tester.tap(find.text('All devices'));await tester.pumpAndSettle();
      await tester.tap(find.text('mobile').last);await tester.pumpAndSettle();expect(service.selectedDevice,'mobile');
      expect(tester.takeException(),isNull);
    });
  }
  testWidgets('failure clears stale report and offers retry', (tester) async {
    final service=FakeAnalytics()..fail=true;
    await tester.pumpWidget(MaterialApp(home:AnalyticsScreen(service:service)));await tester.pumpAndSettle();
    expect(find.text('Could not load analytics'),findsOneWidget);
    expect(find.text('Where visitors leave'),findsNothing);
    service.fail=false;await tester.tap(find.text('Try again'));await tester.pumpAndSettle();
    expect(find.text('Could not load analytics'),findsNothing);
  });
}
