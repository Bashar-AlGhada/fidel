/// One microphone level sample from the noise tester.
///
/// [dbfs] is the raw digital RMS level (0 = clipping); [splApprox] is an
/// *uncalibrated* SPL estimate (dbfs + 100 dB offset) useful for relative
/// readings only.
class NoiseLevelEntity {
  const NoiseLevelEntity({
    required this.dbfs,
    required this.splApprox,
    required this.peakDbfs,
  });

  final double dbfs;
  final double splApprox;
  final double peakDbfs;
}
