import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/domain/entities/sensors/bounded_sample_window.dart';

void main() {
  test('BoundedSampleWindow retains only last N samples', () {
    final window = BoundedSampleWindow<int>(maxSamples: 3, samples: []);
    final w1 = window.pushAll([1, 2, 3, 4, 5]);
    expect(w1.samples, [3, 4, 5]);

    final w2 = w1.push(6);
    expect(w2.samples, [4, 5, 6]);
  });
}
