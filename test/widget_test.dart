import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:upay_ver01/main.dart';

void main() {
  testWidgets('UPay welcome screen opens without Sheets credentials',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp());

    expect(find.text('Welcome to UPay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
