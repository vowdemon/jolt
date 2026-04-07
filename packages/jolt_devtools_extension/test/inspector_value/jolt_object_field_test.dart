import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';

void main() {
  group('JoltObjectField', () {
    test('stable identity only depends on name ownerUri and ownerName', () {
      final a = JoltObjectField(
        name: 'count',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: false,
      );
      final b = JoltObjectField(
        name: 'count',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: true,
      );

      expect(a.stableId, 'package:app/counter.dart::Counter::count');
      expect(a.stableId, b.stableId);
      expect(a, b);
    });
  });
}
