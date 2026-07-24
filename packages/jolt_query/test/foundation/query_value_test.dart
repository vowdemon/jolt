import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  group('QueryValue', () {
    test('application code can construct exhaustive absent variants', () {
      const root = QueryValue<int>.absent();
      const variant = QueryAbsent<int>();

      expect(root, variant);
      expect(root.isAbsent, isTrue);
      expect(root.isPresent, isFalse);
      expect(root.valueOrNull, isNull);
      expect(root.requireValue, throwsStateError);
    });

    test('application code can construct present non-null values', () {
      const root = QueryValue<int>.present(3);
      const variant = QueryPresent<int>(3);

      expect(root, variant);
      expect(root.isPresent, isTrue);
      expect(root.isAbsent, isFalse);
      expect(root.valueOrNull, 3);
      expect(root.requireValue(), 3);
    });

    test('present-null remains distinct from absence', () {
      const present = QueryValue<String?>.present(null);
      const absent = QueryValue<String?>.absent();

      expect(present.isPresent, isTrue);
      expect(present.requireValue(), isNull);
      expect(present, isNot(absent));
    });
  });
}
