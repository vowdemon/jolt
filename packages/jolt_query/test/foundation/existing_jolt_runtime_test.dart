import 'package:jolt/jolt.dart' show Computed, Effect, Signal;
import 'package:test/test.dart';

void main() {
  test('existing Jolt runtime works without importing jolt_query', () {
    final source = Signal<int>(2);
    final doubled = Computed<int>(() => source.value * 2);
    final observed = <int>[];
    final effect = Effect(() => observed.add(doubled.value));

    expect(doubled.value, 4);
    expect(observed, <int>[4]);

    source.value = 3;

    expect(doubled.value, 6);
    expect(observed, <int>[4, 6]);

    effect.dispose();
    doubled.dispose();
    source.dispose();
  });
}
