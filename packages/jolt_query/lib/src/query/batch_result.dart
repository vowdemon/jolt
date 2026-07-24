import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../foundation/query_failure.dart';
import '../keys/query_key.dart';

/// A key-associated failure from one affected bulk-query entry.
final class QueryBatchFailure {
  /// Creates a bulk-query failure record.
  const QueryBatchFailure({required this.key, required this.failure});

  /// The structural key whose requested work failed.
  final QueryKey key;

  /// The exact captured operation failure.
  final QueryFailure failure;
}

/// A deterministic report for a filtered bulk-query operation.
final class QueryBatchResult {
  /// Creates and validates a bulk-operation report.
  factory QueryBatchResult({
    required int matched,
    required int affected,
    int skippedNonExecutable = 0,
    Iterable<QueryBatchFailure> failures = const <QueryBatchFailure>[],
  }) {
    _requireNonNegative('matched', matched);
    _requireNonNegative('affected', affected);
    _requireNonNegative('skippedNonExecutable', skippedNonExecutable);
    if (affected + skippedNonExecutable > matched) {
      throw ArgumentError(
        'affected plus skippedNonExecutable must not exceed matched.',
      );
    }

    final immutableFailures = IList<QueryBatchFailure>(failures);
    if (immutableFailures.length > affected) {
      throw ArgumentError.value(
        immutableFailures.length,
        'failures',
        'Failures must be a subset of affected entries.',
      );
    }
    return QueryBatchResult._(
      matched: matched,
      affected: affected,
      skippedNonExecutable: skippedNonExecutable,
      failures: immutableFailures,
    );
  }

  const QueryBatchResult._({
    required this.matched,
    required this.affected,
    required this.skippedNonExecutable,
    required this.failures,
  });

  /// The stable number of matches captured before work began.
  final int matched;

  /// The matches whose state transition or asynchronous attempt began.
  final int affected;

  /// Matches that required execution but had no retained executable plan.
  final int skippedNonExecutable;

  /// Affected failures in stable pre-operation match order.
  final IList<QueryBatchFailure> failures;

  /// Matched entries for which the requested operation was a no-op.
  int get noOp => matched - affected - skippedNonExecutable;

  /// Whether any affected entry failed.
  bool get hasFailures => failures.isNotEmpty;
}

void _requireNonNegative(String name, int value) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}
