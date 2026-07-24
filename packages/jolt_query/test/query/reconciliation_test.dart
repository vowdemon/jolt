import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:jolt_query/src/query/reconciliation.dart';
import 'package:test/test.dart';

void main() {
  group('DataReconciler.standard', () {
    test('preserves an identical value', () {
      final value = Object();
      final reconciler = DataReconciler<Object>.standard();

      expect(reconciler.reconcile(value, value), same(value));
    });

    test('uses immutable collection equality as a fast path', () {
      final previous = <int>[1, 2].lock;
      final next = <int>[1, 2].lock;
      final reconciler = DataReconciler<IList<int>>.standard();

      expect(reconciler.reconcile(previous, next), same(previous));
    });

    test('reuses unchanged JSON-compatible branches', () {
      final unchanged = <String, Object?>{
        'profile': <String, Object?>{'name': 'Ada'},
      };
      final changed = <String, Object?>{'count': 1};
      final previous = <String, Object?>{
        'unchanged': unchanged,
        'changed': changed,
      };
      final nextChanged = <String, Object?>{'count': 2};
      final next = <String, Object?>{
        'unchanged': <String, Object?>{
          'profile': <String, Object?>{'name': 'Ada'},
        },
        'changed': nextChanged,
      };
      final reconciler = DataReconciler<Map<String, Object?>>.standard();

      final result = reconciler.reconcile(previous, next);

      expect(result, isNot(same(previous)));
      expect(result, isNot(same(next)));
      expect(result['unchanged'], same(unchanged));
      expect(result['changed'], isNot(same(changed)));
      expect(result['changed'], isNot(same(nextChanged)));
      expect(result, next);
    });

    test('returns the complete previous JSON value when deeply equal', () {
      final previous = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'id': 1},
        ],
      };
      final next = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'id': 1},
        ],
      };
      final reconciler = DataReconciler<Map<String, Object?>>.standard();

      expect(reconciler.reconcile(previous, next), same(previous));
    });

    test('does not use overloaded equality for domain values', () {
      final previous = _EqualDomain(1);
      final next = _EqualDomain(1);
      final reconciler = DataReconciler<_EqualDomain>.standard();

      expect(previous, next);
      expect(reconciler.reconcile(previous, next), same(next));
      expect(reconciler.reconcile(previous, next), isNot(same(previous)));
    });

    test('preserves caller-declared typed collections', () {
      final previous = <String>['old'];
      final next = <String>['new'];
      final reconciler = DataReconciler<List<String>>.standard();

      final result = reconciler.reconcile(previous, next);

      expect(result, isNot(same(previous)));
      expect(result, isA<List<String>>());
    });

    test('shares branches in a list with a narrower element type', () {
      final unchanged = <String, Object?>{'id': 1, 'name': 'Ada'};
      final previous = <Map<String, Object?>>[
        unchanged,
        <String, Object?>{'id': 2, 'name': 'before'},
      ];
      final next = <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Ada'},
        <String, Object?>{'id': 2, 'name': 'after'},
      ];
      final reconciler = DataReconciler<List<Map<String, Object?>>>.standard();

      final result = reconciler.reconcile(previous, next);

      expect(result, isA<List<Map<String, Object?>>>());
      expect(result, isNot(same(previous)));
      expect(result, isNot(same(next)));
      expect(result.first, same(unchanged));
      expect(result.last, <String, Object?>{'id': 2, 'name': 'after'});
    });

    test('shares branches in a map with a narrower value type', () {
      final unchanged = <int>[1, 2];
      final previous = <String, List<int>>{
        'unchanged': unchanged,
        'changed': <int>[3],
      };
      final next = <String, List<int>>{
        'unchanged': <int>[1, 2],
        'changed': <int>[4],
      };
      final reconciler = DataReconciler<Map<String, List<int>>>.standard();

      final result = reconciler.reconcile(previous, next);

      expect(result, isA<Map<String, List<int>>>());
      expect(result['unchanged'], same(unchanged));
      expect(result['changed'], <int>[4]);
    });

    test('reports identical mutable collection reuse', () {
      final diagnostics = <DataReconciliationDiagnostic>[];
      final value = <Object?>[1];
      final reconciler = DataReconciler<List<Object?>>.standard(
        diagnostics: diagnostics.add,
      );

      expect(reconciler.reconcile(value, value), same(value));
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.value, same(value));
      expect(diagnostics.single.message, contains('same mutable'));
    });
  });

  test('identity policy preserves only identical values', () {
    final previous = <Object?>[1];
    final equalNext = <Object?>[1];
    final reconciler = DataReconciler<List<Object?>>.identity();

    expect(reconciler.reconcile(previous, previous), same(previous));
    expect(reconciler.reconcile(previous, equalNext), same(equalNext));
  });

  test('custom policy controls the returned typed value', () {
    final previous = <int>[1];
    final next = <int>[2];
    final reconciler = DataReconciler<List<int>>.custom(
      (oldValue, newValue) => oldValue,
    );

    expect(reconciler.reconcile(previous, next), same(previous));
  });
}

final class _EqualDomain {
  const _EqualDomain(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is _EqualDomain && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
