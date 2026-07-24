/// A failure that preserves the exact thrown object and stack trace.
final class QueryFailure {
  /// Creates a captured failure.
  const QueryFailure(this.error, this.stackTrace);

  /// The exact object that was thrown.
  final Object error;

  /// The exact stack trace captured with [error].
  final StackTrace stackTrace;

  @override
  bool operator ==(Object other) =>
      other is QueryFailure &&
      identical(other.error, error) &&
      identical(other.stackTrace, stackTrace);

  @override
  int get hashCode => Object.hash(
        identityHashCode(error),
        identityHashCode(stackTrace),
      );

  @override
  String toString() {
    String errorText;
    try {
      errorText = error.toString();
    } on Object {
      errorText = '<error.toString() threw>';
    }
    return 'QueryFailure($errorText)';
  }
}
