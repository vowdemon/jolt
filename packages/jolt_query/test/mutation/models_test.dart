import 'package:jolt_query/src/foundation/query_failure.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/mutation/models.dart';
import 'package:jolt_query/src/mutation/recipe.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:test/test.dart';

void main() {
  test('success snapshot preserves present-null and immutable erased state',
      () {
    final metadata = <String, Object?>{'source': 'profile'};
    final snapshot = MutationSnapshot(
      id: 3,
      key: MutationKey(<Object?>['profile', 1]),
      status: MutationStatus.success,
      variables: null,
      data: const QueryValue<Object?>.present(null),
      submittedAt: DateTime.utc(2026, 7, 20),
      onMutateResult: const QueryValue<Object?>.present(null),
      scope: const MutationScope('profile'),
      metadata: metadata,
    );
    metadata['source'] = 'changed';

    expect(snapshot.data.isPresent, isTrue);
    expect(snapshot.data.requireValue(), isNull);
    expect(snapshot.onMutateResult.isPresent, isTrue);
    expect(snapshot.onMutateResult.requireValue(), isNull);
    expect(snapshot.variables, isNull);
    expect(snapshot.isSuccess, isTrue);
    expect(snapshot.failureCount, 0);
    expect(snapshot.metadata, <String, Object?>{'source': 'profile'});
    expect(() => snapshot.metadata.clear(), throwsUnsupportedError);
  });

  test('pending retry delay is not paused but retains attempt failure', () {
    final failure = QueryFailure(StateError('retry'), StackTrace.current);
    final snapshot = MutationSnapshot(
      id: 1,
      status: MutationStatus.pending,
      variables: 'input',
      data: const QueryValue<Object?>.absent(),
      failure: failure,
      failureCount: 1,
      submittedAt: DateTime.utc(2026, 7, 20),
    );

    expect(snapshot.isPending, isTrue);
    expect(snapshot.isPaused, isFalse);
    expect(snapshot.pauseReason, isNull);
    expect(snapshot.failure, same(failure));
    expect(snapshot.failureCount, 1);
  });

  test('snapshot rejects idle and inconsistent terminal state', () {
    MutationSnapshot create({
      MutationStatus status = MutationStatus.pending,
      QueryValue<Object?> data = const QueryValue<Object?>.absent(),
      QueryFailure? failure,
      int failureCount = 0,
    }) =>
        MutationSnapshot(
          id: 0,
          status: status,
          variables: 'input',
          data: data,
          failure: failure,
          failureCount: failureCount,
          submittedAt: DateTime.utc(2026, 7, 20),
        );

    expect(
      () => create(status: MutationStatus.idle),
      throwsArgumentError,
    );
    expect(
      () => create(status: MutationStatus.success),
      throwsArgumentError,
    );
    expect(
      () => create(
        status: MutationStatus.pending,
        data: const QueryValue<Object?>.present(1),
      ),
      throwsArgumentError,
    );
    expect(
      () => create(status: MutationStatus.error),
      throwsArgumentError,
    );
    expect(
      () => create(
        status: MutationStatus.success,
        data: const QueryValue<Object?>.present(1),
        failureCount: 1,
      ),
      throwsArgumentError,
    );
  });

  test('pause state requires a pending status and matching reason', () {
    MutationSnapshot create({
      bool isPaused = false,
      PauseReason? pauseReason,
      MutationStatus status = MutationStatus.pending,
      MutationScope? scope,
    }) =>
        MutationSnapshot(
          id: 0,
          status: status,
          variables: 'input',
          data: status == MutationStatus.success
              ? const QueryValue<Object?>.present(1)
              : const QueryValue<Object?>.absent(),
          submittedAt: DateTime.utc(2026, 7, 20),
          isPaused: isPaused,
          pauseReason: pauseReason,
          scope: scope,
        );

    expect(
      () => create(isPaused: true),
      throwsArgumentError,
    );
    expect(
      () => create(pauseReason: PauseReason.offline),
      throwsArgumentError,
    );
    expect(
      () => create(
        isPaused: true,
        pauseReason: PauseReason.offline,
        status: MutationStatus.success,
      ),
      throwsArgumentError,
    );
    expect(
      () => create(
        isPaused: true,
        pauseReason: PauseReason.scope,
      ),
      throwsArgumentError,
    );

    final scoped = create(
      isPaused: true,
      pauseReason: PauseReason.scope,
      scope: const MutationScope('save'),
    );
    expect(scoped.isPaused, isTrue);
  });

  test('filter composes key status pause scope and predicate constraints', () {
    var predicateCalls = 0;
    final snapshot = MutationSnapshot(
      id: 1,
      key: MutationKey(<Object?>['todos', 1]),
      status: MutationStatus.pending,
      variables: 'input',
      data: const QueryValue<Object?>.absent(),
      submittedAt: DateTime.utc(2026, 7, 20),
      isPaused: true,
      pauseReason: PauseReason.scope,
      scope: const MutationScope('todos'),
      metadata: const <String, Object?>{'include': true},
    );
    final filter = MutationFilter(
      key: MutationKey(<Object?>['todos']),
      status: MutationStatus.pending,
      isPaused: true,
      scope: const MutationScope('todos'),
      predicate: (value) {
        predicateCalls += 1;
        return value.metadata['include'] == true;
      },
    );

    expect(filter.matches(snapshot), isTrue);
    expect(predicateCalls, 1);
    expect(
      MutationFilter(
        key: MutationKey(<Object?>['todos']),
        exact: true,
      ).matches(snapshot),
      isFalse,
    );
    expect(
      MutationFilter(
        key: MutationKey(<Object?>['todos', 1.0]),
        exact: true,
      ).matches(snapshot),
      isTrue,
    );
    expect(
      const MutationFilter(
        status: MutationStatus.success,
        predicate: _countUnexpectedPredicate,
      ).matches(snapshot),
      isFalse,
    );
  });
}

bool _countUnexpectedPredicate(MutationSnapshot snapshot) {
  throw StateError('predicate should have short-circuited');
}
