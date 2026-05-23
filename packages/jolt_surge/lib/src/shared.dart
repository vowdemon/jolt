/// A state transition with the current and next values.
///
/// Passed to [Surge.onChange] and [SurgeObserver.onChange].
class Change<State> {
  /// Creates a change from [currentState] to [nextState].
  const Change({required this.currentState, required this.nextState});

  /// The state before the transition.
  final State currentState;

  /// The state that will be applied.
  final State nextState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Change<State> &&
          runtimeType == other.runtimeType &&
          currentState == other.currentState &&
          nextState == other.nextState;

  @override
  int get hashCode => Object.hashAll([currentState, nextState]);

  @override
  String toString() {
    return 'Change { currentState: $currentState, nextState: $nextState }';
  }
}
