import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fidel/core/localization/translations.dart';
import 'package:fidel/core/theme/app_themes.dart';
import 'package:fidel/core/ui/app_states.dart';
import 'package:fidel/domain/entities/sensors/sensor_reading_entity.dart';
import 'package:fidel/features/sections/presentation/widgets/sensor_chart.dart';

void main() {
  testWidgets('SensorChart shows empty state with no samples', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: buildLightTheme(),
        home: const Scaffold(body: SensorChart(samples: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('SensorChart with constrained height does not overflow', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SizedBox(height: 116, child: SensorChart(samples: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SensorChart with one sample shows not-enough state safely', (tester) async {
    final sample = SensorReadingEntity(
      timestamp: DateTime(2026, 1, 1),
      values: const [0.12, 0.34, 0.56],
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: buildLightTheme(),
        home: Scaffold(body: SensorChart(samples: [sample])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
