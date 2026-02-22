class Percentage {
  const Percentage._(this.value);

  final double value;

  static Percentage fromRatio(double ratio) {
    if (ratio.isNaN || ratio.isInfinite) return const Percentage._(0);
    final clamped = ratio.clamp(0.0, 1.0);
    return Percentage._(clamped);
  }

  int toWholePercent() => (value * 100).round();
}
