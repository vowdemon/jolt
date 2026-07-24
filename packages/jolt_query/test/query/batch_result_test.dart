import 'package:jolt_query/src/foundation/query_failure.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/batch_result.dart';
import 'package:test/test.dart';

void main() {
  test('batch results preserve stable failure order and count partitions', () {
    final first = QueryBatchFailure(
      key: QueryKey(<Object?>['todos', 1]),
      failure: QueryFailure(StateError('first'), StackTrace.current),
    );
    final second = QueryBatchFailure(
      key: QueryKey(<Object?>['todos', 2]),
      failure: QueryFailure(StateError('second'), StackTrace.current),
    );
    final source = <QueryBatchFailure>[first, second];
    final result = QueryBatchResult(
      matched: 5,
      affected: 2,
      skippedNonExecutable: 1,
      failures: source,
    );
    source.clear();

    expect(result.matched, 5);
    expect(result.affected, 2);
    expect(result.skippedNonExecutable, 1);
    expect(result.noOp, 2);
    expect(result.failures, hasLength(2));
    expect(result.failures[0], same(first));
    expect(result.failures[1], same(second));
    expect(result.hasFailures, isTrue);
  });

  test('empty batch report is a valid no-op result', () {
    final result = QueryBatchResult(matched: 0, affected: 0);

    expect(result.noOp, 0);
    expect(result.failures, isEmpty);
    expect(result.hasFailures, isFalse);
  });

  test('batch result rejects inconsistent counts', () {
    final failure = QueryBatchFailure(
      key: QueryKey(<Object?>['todos']),
      failure: QueryFailure(StateError('failed'), StackTrace.current),
    );

    expect(
      () => QueryBatchResult(matched: -1, affected: 0),
      throwsArgumentError,
    );
    expect(
      () => QueryBatchResult(
        matched: 1,
        affected: 1,
        skippedNonExecutable: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => QueryBatchResult(
        matched: 1,
        affected: 0,
        failures: <QueryBatchFailure>[failure],
      ),
      throwsArgumentError,
    );
  });
}
