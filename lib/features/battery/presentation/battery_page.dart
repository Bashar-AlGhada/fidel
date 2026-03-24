import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/routing/app_nav_shell.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';

class BatteryPage extends ConsumerWidget {
  const BatteryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.battery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.battery);
      });
    }
    final bat = ref.watch(batteryStreamProvider);
    final shell = AppNavShellScope.maybeOf(context);
    final showMenu = shell?.hasDrawer == true;
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(
        leading: showMenu
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: shell?.openDrawer,
              )
            : null,
        title: Text('nav.battery'.tr),
      ),
      body: bat.when(
        data: (b) {
          final pct = b.percent.clamp(0, 100);
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              Text('$pct%', style: Theme.of(context).textTheme.displaySmall),
              SizedBox(height: tokens.space3),
              RepaintBoundary(child: LinearProgressIndicator(value: pct / 100)),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(batteryStreamProvider),
        ),
      ),
    );
  }
}
