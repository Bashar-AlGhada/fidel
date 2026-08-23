import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/theme_tokens.dart';

import 'sensor_sampling_options.dart';

/// Sampling-period / window controls shared by the sensors list page and
/// the sensor detail page.
class SensorControlsCard extends StatelessWidget {
  const SensorControlsCard({
    required this.samplingPeriodUs,
    required this.maxSamples,
    required this.onSamplingChanged,
    required this.onMaxSamplesChanged,
    super.key,
  });

  final int samplingPeriodUs;
  final int maxSamples;
  final ValueChanged<int> onSamplingChanged;
  final ValueChanged<int> onMaxSamplesChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sensors.controls'.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space2),
            Row(
              children: [
                Expanded(child: Text('sensors.sampling'.tr)),
                DropdownButton<int>(
                  value: samplingPeriodUs,
                  onChanged: (v) {
                    if (v != null) onSamplingChanged(v);
                  },
                  items: [
                    for (final v in samplingPeriodUsOptions)
                      DropdownMenuItem(value: v, child: Text('${v ~/ 1000}ms')),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('sensors.window'.tr)),
                DropdownButton<int>(
                  value: maxSamples,
                  onChanged: (v) {
                    if (v != null) onMaxSamplesChanged(v);
                  },
                  items: [
                    for (final v in maxSamplesOptions)
                      DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
