class BoundedSampleWindow<T> {
  BoundedSampleWindow({required this.maxSamples, required List<T> samples})
    : assert(maxSamples > 0),
      samples = List.unmodifiable(samples.takeLast(maxSamples));

  final int maxSamples;
  final List<T> samples;

  BoundedSampleWindow<T> push(T sample) {
    final next = [...samples, sample];
    final trimmed = next.takeLast(maxSamples);
    return BoundedSampleWindow<T>(maxSamples: maxSamples, samples: trimmed);
  }

  BoundedSampleWindow<T> pushAll(Iterable<T> newSamples) {
    final next = [...samples, ...newSamples];
    final trimmed = next.takeLast(maxSamples);
    return BoundedSampleWindow<T>(maxSamples: maxSamples, samples: trimmed);
  }
}

extension _TakeLastList<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return <T>[];
    if (length <= count) return List<T>.unmodifiable(this);
    return List<T>.unmodifiable(sublist(length - count));
  }
}
