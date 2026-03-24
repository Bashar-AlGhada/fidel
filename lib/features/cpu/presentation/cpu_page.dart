import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/routing/app_nav_shell.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';

class CpuPage extends ConsumerWidget {
  const CpuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.cpu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.cpu);
      });
    }
    final cpu = ref.watch(cpuStreamProvider);
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
        title: Text('nav.cpu'.tr),
      ),
      body: cpu.when(
        data: (v) {
          final percent = v.usage.toWholePercent();
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: tokens.space3),
              RepaintBoundary(
                child: LinearProgressIndicator(value: v.usage.value),
              ),
              SizedBox(height: tokens.space3),
              Text('Cores: ${v.cores}'),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(cpuStreamProvider),
        ),
      ),
    );
  }
}
