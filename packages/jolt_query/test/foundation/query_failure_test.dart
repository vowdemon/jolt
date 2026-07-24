import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('QueryFailure preserves the exact object and stack trace', () {
    final error = Object();
    final stackTrace = StackTrace.current;
    final failure = QueryFailure(error, stackTrace);

    expect(identical(failure.error, error), isTrue);
    expect(identical(failure.stackTrace, stackTrace), isTrue);
    expect(failure, QueryFailure(error, stackTrace));
  });

  test('QueryFailure formatting is safe when error formatting throws', () {
    final failure = QueryFailure(_ThrowingToString(), StackTrace.current);

    expect(failure.toString(), contains('toString() threw'));
  });
}

final class _ThrowingToString {
  @override
  String toString() => throw StateError('format failed');
}
