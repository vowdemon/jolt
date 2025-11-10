import 'package:jolt/core.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group('trigger', () {
    test('should not throw when triggering with no dependencies', () {
      globalReactiveSystem.trigger(() {});
    });

    test('should trigger updates for dependent computed signals', () {
      final arr = signal(<int>[]);
      final length = computed(() => arr().length);

      expect(length(), 0);
      arr().add(1);
      globalReactiveSystem.trigger(arr);
      expect(length(), 1);
    });

    test('should trigger updates for the second source signal', () {
      final src1 = signal(<int>[]);
      final src2 = signal(<int>[]);
      final length = computed(() => src2().length);

      expect(length(), 0);
      src2().add(1);
      globalReactiveSystem.trigger(() {
        src1();
        src2();
      });
      expect(length(), 1);
    });

    test('should trigger effect once', () {
      final src1 = signal(<int>[]);
      final src2 = signal(<int>[]);

      var triggers = 0;

      effect(() {
        triggers++;
        src1();
        src2();
      });

      expect(triggers, 1);
      globalReactiveSystem.trigger(() {
        src1();
        src2();
      });
      expect(triggers, 2);
    });
  });
}
