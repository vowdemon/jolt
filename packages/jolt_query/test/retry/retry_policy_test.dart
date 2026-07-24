import 'dart:async';

import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  test('marker policies are covariant and inference neutral', () {
    final RetryPolicy<int> none = RetryPolicy.none;
    final RetryPolicy<String> standard = RetryPolicy.standard;

    expect(identical(none, RetryPolicy.none), isTrue);
    expect(identical(standard, RetryPolicy.standard), isTrue);
  });

  test('RetryBuilder keeps exception-only strategy expressions typed', () {
    final policy = RetryPolicy<_User>.custom((retry) {
      final RetryIf<_User> exceptions = retry.exceptions;
      final RetryIf<_User> filtered = retry.exceptionWhere(
        (error, stackTrace) => error is StateError,
      );
      final RetryIf<_User> typed = retry.exceptionType<ArgumentError>();
      final RetryIf<_User> results = retry.result(
        (result) => result.id.isEmpty,
      );
      final RetryIf<_User> attempts = retry.where(
        (attempt) => attempt.attemptNumber < 2,
      );
      final RetryIf<_User> any = retry.any;
      final RetryIf<_User> never = retry.never;
      final RetryIf<_User> budget = retry.maxRetries(3);

      return retry.strategy(
        name: 'typed-users',
        delay: DelayPolicy.none(),
        retryIf: (exceptions | filtered | typed | results | any) &
            attempts &
            budget &
            ~never,
        onRetry: (RetryAttemptContext<_User> attempt) {},
        onGiveUp: (RetryAttemptContext<_User> attempt) {},
      );
    });

    expect(policy, isA<RetryPolicy<_User>>());
  });

  test('custom and generated delay callbacks preserve Object? erasure', () {
    final custom = DelayPolicy.custom(
      (
        RetryAttemptContext<Object?> attempt,
        double Function() random,
      ) {
        final Object? result = switch (attempt.outcome) {
          AttemptOutcomeResult<Object?>(:final result) => result,
          AttemptOutcomeError<Object?>() => null,
        };
        expect(result, isNull);
        return Duration.zero;
      },
    );
    final generated = DelayPolicy.generated(
      (
        RetryAttemptContext<Object?> attempt,
        double Function() random,
      ) async {
        await Future<void>.value();
        return null;
      },
    );

    expect(custom, isA<DelayPolicy>());
    expect(generated, isA<DelayPolicy>());
  });
}

final class _User {
  const _User(this.id);

  final String id;
}
