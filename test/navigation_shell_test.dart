import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fidel/main.dart';

void main() {
  testWidgets('Shows new bottom navigation destinations', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: FidelApp()));
    await tester.pumpAndSettle();

    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Info'), findsWidgets);
    expect(find.text('Testers'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
