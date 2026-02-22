import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fidel/core/localization/translations.dart';
import 'package:fidel/core/theme/app_themes.dart';
import 'package:fidel/core/ui/app_states.dart';
import 'package:fidel/features/sections/presentation/widgets/sensor_chart.dart';

void main() {
  testWidgets('SensorChart shows empty state with no samples', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SensorChart(samples: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
  });
}

