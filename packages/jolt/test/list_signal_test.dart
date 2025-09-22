import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('listSignal', () {
    test('list', () {
      final a = ListSignal<int>([]);

      Effect(() {
        print(a.length);
      });

      a.value = [1, 2, 3];
      expect(a.value, equals([1, 2, 3]));

      expect(a.firstOrNull, equals(1));
      expect(a.lastOrNull, equals(3));

      Effect(() {
        print(a.firstOrNull);
      });

      a.add(33);
      a[0] = 12;
    });
  });
}
