import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/mutation/client_extension.dart';
import 'package:jolt_query/src/mutation/recipe.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:test/test.dart';

void main() {
  test('class-first mutation only requires mutate', () {
    final Mutation<_Variables, int, void> definition = _ReusableMutation();
    final client = QueryClient();
    addTearDown(client.dispose);
    final context = MutationContext(client: client, key: definition.key);

    expect(definition.mutate(const _Variables(3), context), 3);
    expect(definition.onMutate, isNull);
    expect(definition.retryPolicy, same(RetryPolicy.none));
    expect(definition.networkMode, NetworkMode.online);
    expect(definition.retentionPolicy.duration, const Duration(minutes: 5));
  });

  test('class-first constructor accepts explicit built-in policies', () {
    const definition = _ConfiguredMutation();

    expect(definition.retryPolicy, same(RetryPolicy.none));
    expect(definition.networkMode, NetworkMode.online);
    expect(definition.retentionPolicy, same(RetentionPolicy.standard));
  });

  test('class-first mutation can expose a typed onMutate result', () async {
    final definition = _ReusableResultMutation();
    final client = QueryClient();
    addTearDown(client.dispose);
    final observer = client.observeMutation(definition);

    expect(await observer.execute(const _Variables(3)), 4);
    await Future<void>.delayed(Duration.zero);
    expect(
      observer.onMutateResult,
      const QueryValue<String>.present('previous:3'),
    );
  });

  test('inline onMutate infers the complete V D R definition', () async {
    final inferred = mutation(
      onMutate: (int variables, MutationContext context) => variables.isEven,
      mutate: (int variables, MutationContext context) => 'saved:$variables',
    );
    final Mutation<int, String, bool> exact = inferred;
    final client = QueryClient();
    addTearDown(client.dispose);
    final observer = client.observeMutation(exact);

    expect(await observer.execute(2), 'saved:2');
    await Future<void>.delayed(Duration.zero);
    expect(observer.onMutateResult, const QueryValue<bool>.present(true));
  });

  test('inline factory freezes definition and context metadata', () async {
    final metadata = <String, Object?>{'source': 'settings'};
    final Mutation<_Variables, int, void> definition = mutation(
      key: MutationKey(<Object?>['save', 1]),
      scope: const MutationScope('account'),
      metadata: metadata,
      networkMode: NetworkMode.offlineFirst,
      retention: RetentionPolicy.duration(const Duration(minutes: 2)),
      retry: RetryPolicy.standard,
      mutate: (_Variables variables, MutationContext context) =>
          variables.value + (context.metadata['increment'] as int? ?? 0),
    );
    metadata['source'] = 'changed';
    final contextMetadata = <String, Object?>{'increment': 2};
    final client = QueryClient();
    addTearDown(client.dispose);
    final context = MutationContext(
      client: client,
      key: definition.key,
      scope: definition.scope,
      metadata: contextMetadata,
    );
    contextMetadata['increment'] = 10;

    expect(await definition.mutate(const _Variables(3), context), 5);
    expect(definition.metadata, <String, Object?>{'source': 'settings'});
    expect(() => definition.metadata.clear(), throwsUnsupportedError);
    expect(context.metadata, <String, Object?>{'increment': 2});
    expect(() => context.metadata.clear(), throwsUnsupportedError);
    expect(definition.retryPolicy, same(RetryPolicy.standard));
  });

  test('typed retry transformation preserves all definition behavior',
      () async {
    final calls = <String>[];
    final original = mutation<_Variables, int, void>(
      key: MutationKey(<Object?>['save']),
      mutate: (variables, context) => variables.value,
      onSuccess: (data, variables, result, context) {
        expect(result.isAbsent, isTrue);
        calls.add('success:$data');
      },
    );
    final Mutation<_Variables, int, void> transformed = original.withRetry(
      (retry) => retry.strategy(
        retryIf: retry.result((int result) => result == 0),
      ),
    );
    final client = QueryClient();
    addTearDown(client.dispose);

    expect(transformed.key, original.key);
    expect(transformed.retryPolicy, isA<RetryPolicy<int>>());
    expect(await client.execute(transformed, const _Variables(4)), 4);
    expect(calls, <String>['success:4']);
  });

  test('callbacks preserve typed present-null onMutate result', () async {
    QueryValue<String?>? successResult;
    QueryValue<String?>? settledResult;
    final definition = mutation<_Variables, int, String?>(
      mutate: (variables, context) => variables.value,
      onMutate: (variables, context) => null,
      onSuccess: (data, variables, result, context) {
        successResult = result;
      },
      onSettled: (data, failure, variables, result, context) {
        settledResult = result;
      },
    );
    final client = QueryClient();
    addTearDown(client.dispose);

    expect(await client.execute(definition, const _Variables(1)), 1);
    expect(successResult, const QueryValue<String?>.present(null));
    expect(settledResult, const QueryValue<String?>.present(null));
  });

  test('action callbacks omit sentinel variables', () async {
    final calls = <String>[];
    final definition = action<int, String>(
      onMutate: (context) {
        calls.add('mutate-stage');
        return 'before';
      },
      mutate: (context) {
        calls.add('function');
        return 7;
      },
      onSuccess: (data, result, context) {
        calls.add('success:$data:${result.requireValue()}');
      },
      onSettled: (data, failure, result, context) {
        calls.add('settled:${data.requireValue()}');
      },
    );
    final client = QueryClient();
    addTearDown(client.dispose);

    expect(await client.executeAction(definition), 7);
    expect(
      calls,
      <String>[
        'mutate-stage',
        'function',
        'success:7:before',
        'settled:7',
      ],
    );
  });

  test('MutationScope compares only by ID', () {
    const first = MutationScope('save-account');
    const second = MutationScope('save-account');
    const other = MutationScope('save-profile');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(other));
  });
}

final class _ReusableMutation extends Mutation<_Variables, int, void> {
  @override
  MutationKey get key => MutationKey(<Object?>['counter']);

  @override
  int mutate(_Variables variables, MutationContext context) => variables.value;
}

final class _ConfiguredMutation extends Mutation<_Variables, int, void> {
  const _ConfiguredMutation()
      : super(
          retry: RetryPolicy.none,
          networkMode: NetworkMode.online,
          retention: RetentionPolicy.standard,
        );

  @override
  int mutate(_Variables variables, MutationContext context) => variables.value;
}

final class _ReusableResultMutation extends Mutation<_Variables, int, String> {
  @override
  MutationOnMutate<_Variables, String> get onMutate =>
      (variables, context) => 'previous:${variables.value}';

  @override
  int mutate(_Variables variables, MutationContext context) =>
      variables.value + 1;
}

final class _Variables {
  const _Variables(this.value);

  final int value;
}
