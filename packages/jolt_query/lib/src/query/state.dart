/// The canonical data state of a query entry.
enum QueryStatus {
  /// The entry has not completed an accepted result yet.
  pending,

  /// The entry has accepted query data.
  success,

  /// The entry's latest operation ended in a terminal failure.
  error,
}

/// The orthogonal execution state of a query entry.
enum FetchStatus {
  /// No query operation is currently fetching.
  idle,

  /// A query operation is executing or waiting for its retry delay.
  fetching,

  /// A query operation is waiting for an external eligibility gate.
  paused,
}

/// Why otherwise pending work is paused.
///
/// Query and mutation retries can use [offline] or [focus]. Mutation scope
/// queues also reuse this shared state vocabulary through [scope].
enum PauseReason {
  /// Work is waiting for online eligibility.
  offline,

  /// Retry work is waiting for application focus.
  focus,

  /// Mutation work is waiting for an earlier execution in the same scope.
  scope,
}
