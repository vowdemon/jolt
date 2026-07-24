import 'package:jolt_query/src/foundation/query_failure.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/mutation/models.dart';
import 'package:jolt_query/src/mutation/observer_result.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:test/test.dart';

void main() {
  test('idle presentation has no stale values', () {
    final MutationObserverResult<String?, int?, void> result =
        MutationObserverResult.idle();

    expect(result.isIdle, isTrue);
    expect(result.variables.isAbsent, isTrue);
    expect(result.data.isAbsent, isTrue);
    expect(result.onMutateResult.isAbsent, isTrue);
    expect(result.failure, isNull);
    expect(result.failureCount, 0);
    expect(result.submittedAt, isNull);
  });

  test('submitted nullable values preserve present-null', () {
    final result = MutationObserverResult<String?, int?, String?>(
      status: MutationStatus.success,
      variables: const QueryValue<String?>.present(null),
      data: const QueryValue<int?>.present(null),
      onMutateResult: const QueryValue<String?>.present(null),
      submittedAt: DateTime.utc(2026, 7, 20),
    );

    expect(result.variables, const QueryValue<String?>.present(null));
    expect(result.data, const QueryValue<int?>.present(null));
    expect(result.onMutateResult, const QueryValue<String?>.present(null));
  });

  test('successful result may have no onMutate result', () {
    final result = MutationObserverResult<int, int, String>(
      status: MutationStatus.success,
      variables: const QueryValue<int>.present(1),
      data: const QueryValue<int>.present(2),
      onMutateResult: const QueryValue<String>.absent(),
      submittedAt: DateTime.utc(2026, 7, 20),
    );

    expect(result.isSuccess, isTrue);
    expect(result.onMutateResult.isAbsent, isTrue);
  });

  test('error distinguishes absent from present-null onMutate result', () {
    final failure = QueryFailure(StateError('failed'), StackTrace.current);
    final submittedAt = DateTime.utc(2026, 7, 20);
    final absent = MutationObserverResult<int, int, String?>(
      status: MutationStatus.error,
      variables: const QueryValue<int>.present(1),
      data: const QueryValue<int>.absent(),
      onMutateResult: const QueryValue<String?>.absent(),
      failure: failure,
      submittedAt: submittedAt,
    );
    final presentNull = MutationObserverResult<int, int, String?>(
      status: MutationStatus.error,
      variables: const QueryValue<int>.present(1),
      data: const QueryValue<int>.absent(),
      onMutateResult: const QueryValue<String?>.present(null),
      failure: failure,
      submittedAt: submittedAt,
    );

    expect(absent.onMutateResult.isAbsent, isTrue);
    expect(presentNull.onMutateResult, const QueryValue<String?>.present(null));
  });

  test('observer result rejects impossible lifecycle combinations', () {
    final submittedAt = DateTime.utc(2026, 7, 20);

    MutationObserverResult<int, int, void> result({
      required MutationStatus status,
      QueryValue<int> variables = const QueryValue<int>.present(1),
      QueryValue<int> data = const QueryValue<int>.absent(),
      QueryValue<void> onMutateResult = const QueryValue<void>.absent(),
      QueryFailure? failure,
      bool isPaused = false,
      PauseReason? pauseReason,
      DateTime? time,
    }) {
      return MutationObserverResult<int, int, void>(
        status: status,
        variables: variables,
        data: data,
        onMutateResult: onMutateResult,
        failure: failure,
        isPaused: isPaused,
        pauseReason: pauseReason,
        submittedAt: time,
      );
    }

    expect(
      () => result(status: MutationStatus.idle),
      throwsArgumentError,
    );
    expect(
      () => result(status: MutationStatus.pending),
      throwsArgumentError,
    );
    expect(
      () => result(status: MutationStatus.error, time: submittedAt),
      throwsArgumentError,
    );
    expect(
      () => result(
        status: MutationStatus.success,
        data: const QueryValue<int>.present(1),
        time: submittedAt,
        isPaused: true,
        pauseReason: PauseReason.offline,
      ),
      throwsArgumentError,
    );
  });
}
