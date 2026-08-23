class Percentage {
  const Percentage._(this.value);

  final double value;

  static Percentage fromRatio(double ratio) {
    if (ratio.isNaN) return const Percentage._(0);
    return Percentage._(ratio.clamp(0.0, 1.0));
  }

  int toWholePercent() => (value * 100).round();
}
