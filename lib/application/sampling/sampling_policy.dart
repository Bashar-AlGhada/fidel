import 'active_module.dart';

class SamplingPolicy {
  const SamplingPolicy();

  Duration intervalFor(ActiveModule module) {
    return switch (module) {
      ActiveModule.cpu => const Duration(milliseconds: 500),
      ActiveModule.dashboard => const Duration(seconds: 1),
      ActiveModule.info => const Duration(seconds: 2),
      ActiveModule.testers => const Duration(milliseconds: 500),
      ActiveModule.sections => const Duration(seconds: 2),
      ActiveModule.sensors => const Duration(milliseconds: 200),
      ActiveModule.memory => const Duration(seconds: 1),
      ActiveModule.battery => const Duration(seconds: 1),
      ActiveModule.settings => const Duration(seconds: 2),
    };
  }
}
