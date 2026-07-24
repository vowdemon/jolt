import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  group('structural keys', () {
    test('normalize nested values and ignore map insertion order', () {
      final first = QueryKey(<Object?>[
        'todos',
        <String, Object?>{
          'filter': <Object?>[1, 2.5],
          'done': false,
        },
      ]);
      final second = QueryKey(<Object?>[
        'todos',
        <String, Object?>{
          'done': false,
          'filter': <Object?>[1.0, 2.5],
        },
      ]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('defensively isolates mutable source collections', () {
      final nested = <Object?>[1];
      final source = <Object?>['todos', nested];
      final key = QueryKey(source);
      final originalHash = key.hashCode;

      nested.add(2);
      source.add('later');

      final originalValue = QueryKey(<Object?>[
        'todos',
        <Object?>[1],
      ]);
      expect(key, originalValue);
      expect(key.hashCode, originalHash);
      expect(key.hashCode, originalValue.hashCode);
    });

    test('canonicalizes integral doubles and negative zero recursively', () {
      final integerForm = QueryKey(<Object?>[
        1,
        <String, Object?>{'zero': 0},
      ]);
      final doubleForm = QueryKey(<Object?>[
        1.0,
        <String, Object?>{'zero': -0.0},
      ]);

      expect(integerForm, doubleForm);
      expect(integerForm.hashCode, doubleForm.hashCode);
      expect(QueryKey(<Object?>[1]), isNot(QueryKey(<Object?>[1.5])));
    });

    test('rejects unsupported and non-finite values at every depth', () {
      expect(
          () => QueryKey(<Object?>[
                {1, 2}
              ]),
          throwsArgumentError);
      expect(() => QueryKey(<Object?>[DateTime(2025)]), throwsArgumentError);
      expect(
        () => QueryKey(<Object?>[
          <String, Object?>{'bad': double.nan},
        ]),
        throwsArgumentError,
      );
      expect(() => QueryKey(<Object?>[double.infinity]), throwsArgumentError);
      expect(
        () => QueryKey(<Object?>[
          <Object?, Object?>{1: 'bad'},
        ]),
        throwsArgumentError,
      );
    });

    test('prefix matching is structural', () {
      final key = QueryKey(<Object?>[
        'todos',
        <String, Object?>{'page': 1},
      ]);

      expect(key.startsWith(QueryKey(<Object?>['todos'])), isTrue);
      expect(
        key.startsWith(
          QueryKey(<Object?>[
            'todos',
            <String, Object?>{'page': 2},
          ]),
        ),
        isFalse,
      );
    });

    test('prefix matching recursively accepts nested map and list subsets', () {
      final key = QueryKey(<Object?>[
        'todos',
        <String, Object?>{
          'filters': <String, Object?>{
            'page': 1,
            'labels': <Object?>['important', 'personal'],
          },
          'sort': 'recent',
        },
      ]);

      expect(
        key.startsWith(
          QueryKey(<Object?>[
            'todos',
            <String, Object?>{
              'filters': <String, Object?>{
                'page': 1,
                'labels': <Object?>['important'],
              },
            },
          ]),
        ),
        isTrue,
      );
      expect(
        key.startsWith(
          QueryKey(<Object?>[
            'todos',
            <String, Object?>{
              'filters': <String, Object?>{
                'labels': <Object?>['personal'],
              },
            },
          ]),
        ),
        isFalse,
      );
      expect(
        key,
        isNot(
          QueryKey(<Object?>[
            'todos',
            <String, Object?>{
              'filters': <String, Object?>{'page': 1},
            },
          ]),
        ),
      );
    });

    test('uses package-local FIC configuration', () {
      final oldListConfig = IList.defaultConfig;
      final oldMapConfig = IMap.defaultConfig;
      addTearDown(() {
        IList.defaultConfig = oldListConfig;
        IMap.defaultConfig = oldMapConfig;
      });
      IList.defaultConfig = const ConfigList(isDeepEquals: false);
      IMap.defaultConfig = const ConfigMap(isDeepEquals: false);

      expect(
        QueryKey(<Object?>[
          <String, Object?>{'value': 1},
        ]),
        QueryKey(<Object?>[
          <String, Object?>{'value': 1.0},
        ]),
      );
    });

    test('MutationKey shares normalization without execution identity', () {
      final first = MutationKey(<Object?>['save', 1]);
      final second = MutationKey(<Object?>['save', 1.0]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.startsWith(MutationKey(<Object?>['save'])), isTrue);
    });

    test('MutationKey uses the same recursive partial-prefix rules', () {
      final key = MutationKey(<Object?>[
        'save',
        <String, Object?>{
          'entity': <String, Object?>{'id': 1, 'revision': 2},
        },
      ]);

      expect(
        key.startsWith(
          MutationKey(<Object?>[
            'save',
            <String, Object?>{
              'entity': <String, Object?>{'id': 1},
            },
          ]),
        ),
        isTrue,
      );
    });
  });
}
