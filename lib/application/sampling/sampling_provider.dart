import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'active_module.dart';
import 'sampling_policy.dart';

class ActiveModuleController extends Notifier<ActiveModule> {
  @override
  ActiveModule build() => ActiveModule.dashboard;

  void setModule(ActiveModule module) {
    state = module;
  }
}

final activeModuleProvider =
    NotifierProvider<ActiveModuleController, ActiveModule>(
      ActiveModuleController.new,
    );

final samplingPolicyProvider = Provider<SamplingPolicy>(
  (ref) => const SamplingPolicy(),
);
