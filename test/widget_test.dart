import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jalrakshak/screens/intro_screen.dart';
import 'package:jalrakshak/screens/portal_home_screen.dart';
import 'package:jalrakshak/screens/flash_flood_portal_screen.dart';
import 'package:jalrakshak/screens/street_waterlogging_portal_screen.dart';
import 'package:jalrakshak/screens/report_incident_portal_screen.dart';
import 'package:jalrakshak/screens/about_portal_screen.dart';

void main() {
  testWidgets('JalRakshak smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('JALRAKSHAK'),
      ),
      findsWidgets,
    );
  });

  testWidgets('PortalHomeScreen mobile 360px layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PortalHomeScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('JALRAKSHAK'), findsWidgets);
    expect(find.text('“Know the risk. Act early.”'), findsOneWidget);
    expect(find.text('FLASH FLOOD'), findsWidgets);
    expect(find.text('STREET WATERLOGGING'), findsWidgets);
  });

  testWidgets('FlashFloodPortalScreen mobile layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FlashFloodPortalScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('FLASH FLOOD WARNING'), findsOneWidget);
    expect(find.text('WARD 12 (STATION ROAD / MARKET)'), findsOneWidget);
  });

  testWidgets('StreetWaterloggingPortalScreen mobile layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StreetWaterloggingPortalScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Why is this road flooded?'), findsOneWidget);
    expect(find.text('PREDICTED DRAINAGE BLOCKAGE'), findsOneWidget);
  });

  testWidgets('ReportIncidentPortalScreen mobile layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ReportIncidentPortalScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Report Flood or Waterlogged Road'), findsOneWidget);
    expect(find.text('Send Alert Report'), findsOneWidget);
  });

  testWidgets('AboutPortalScreen mobile layout test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AboutPortalScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ABOUT JALRAKSHAK'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
  });
}
