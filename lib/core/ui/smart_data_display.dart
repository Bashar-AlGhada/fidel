import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SmartDataDisplay extends StatelessWidget {
  const SmartDataDisplay({required this.data, super.key});

  final Object? data;

  @override
  Widget build(BuildContext context) {
    final value = data;
    if (value == null) {
      return Text(
        'common.na'.tr,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    if (value is Map) {
      final entries = value.entries.toList(growable: false);
      if (entries.isEmpty) return Text('common.empty'.tr);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: SmartDataDisplay(data: entry.value),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      );
    }

    if (value is List) {
      if (value.isEmpty) return Text('common.empty'.tr);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value
            .asMap()
            .entries
            .map((entry) {
              final item = entry.value;
              if (item is Map || item is List) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      'common.item'.trParams({'n': '${entry.key + 1}'}),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SmartDataDisplay(data: item),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${item.toString()}'),
              );
            })
            .toList(growable: false),
      );
    }

    return Text(value.toString());
  }
}
