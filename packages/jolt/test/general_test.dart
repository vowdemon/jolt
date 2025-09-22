import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('general', () {
    test('should track signal and computed', () {
      final a = Signal(1);
      final b = Computed<int>(() => a.value + 1);
      expect(a.value, equals(1));
      expect(b.value, equals(2));

      a.value = 2;
      expect(a.value, equals(2));
      expect(b.value, equals(3));
    });

    test('should capture signal and computed in effect', () {
      final a = Signal(1);
      final b = Computed<int>(() => a.value + 1);

      final List<int> as = [];
      final List<int> bs = [];
      Effect(() {
        as.add(a.value);
        bs.add(b.value);
      });

      expect(as, equals([1]));
      expect(bs, equals([2]));

      a.value = 2;
      expect(as, equals([1, 2]));
      expect(bs, equals([2, 3]));
    });

    test('should not capture signal and computed in effect', () {
      final a = Signal(1);
      final b = Computed<int>(() => a.value + 1);

      final List<int> as = [];
      final List<int> bs = [];
      Effect(() {
        as.add(untracked(() => a.value));
        bs.add(untracked(() => b.value));
      });

      expect(as, equals([1]));
      expect(bs, equals([2]));

      a.value = 2;
      expect(as, equals([1]));
      expect(bs, equals([2]));
    });

    test('should batch update value', () {
      final a = Signal(1);
      final b = Computed<int>(() => a.value + 1);

      final List<int> as = [];
      final List<int> bs = [];
      Effect(() {
        as.add(a.value);
        bs.add(b.value);
      });

      expect(as, equals([1]));
      expect(bs, equals([2]));

      batch(() {
        a.value = 2;
        a.value = 3;
      });
      expect(as, equals([1, 3]));
      expect(bs, equals([2, 4]));
    });

    test('should broadcast stream from signal and computed', () async {
      final a = Signal(1);
      final b = Computed<int>(() => a.value + 1);

      final List<int> as = [];
      final List<int> bs = [];

      a.stream.listen((value) {
        as.add(value);
      });
      b.stream.listen((value) {
        bs.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(as, equals([]));
      expect(bs, equals([]));

      a.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      expect(as, equals([2]));
      expect(bs, equals([3]));
    });
  });
}
