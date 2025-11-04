/// Represents a state change with the current and next state values.
///
/// Change is used to encapsulate state transitions in Surge, providing
/// information about both the current state and the state that will be
/// applied. This is useful for change notifications, logging, and validation.
///
/// Example:
/// ```dart
/// final change = Change(currentState: 0, nextState: 1);
/// print('Changing from ${change.currentState} to ${change.nextState}');
/// ```
class Change<State> {
  /// Creates a new change object with the given states.
  ///
  /// Parameters:
  /// - [currentState]: The current state value before the change
  /// - [nextState]: The next state value that will be applied
  ///
  /// Example:
  /// ```dart
  /// final change = Change(currentState: 'old', nextState: 'new');
  /// ```
  const Change({required this.currentState, required this.nextState});

  /// The current state value before the change.
  ///
  /// This is the state value that exists before the change is applied.
  final State currentState;

  /// The next state value that will be applied.
  ///
  /// This is the state value that will replace the current state.
  final State nextState;

  /// Compares two Change objects for equality.
  ///
  /// Parameters:
  /// - [other]: The object to compare with
  ///
  /// Returns: true if both Change objects have the same current and next states
  ///
  /// Two Change objects are considered equal if they have the same
  /// [currentState] and [nextState] values.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Change<State> &&
          runtimeType == other.runtimeType &&
          currentState == other.currentState &&
          nextState == other.nextState;

  /// Returns the hash code for this Change object.
  ///
  /// Returns: A hash code based on the current and next state values
  ///
  /// The hash code is computed from both [currentState] and [nextState].
  @override
  int get hashCode => Object.hashAll([currentState, nextState]);

  /// Returns a string representation of this Change object.
  ///
  /// Returns: A string containing the current and next state values
  ///
  /// Example:
  /// ```dart
  /// final change = Change(currentState: 0, nextState: 1);
  /// print(change.toString()); // "Change { currentState: 0, nextState: 1 }"
  /// ```
  @override
  String toString() {
    return 'Change { currentState: $currentState, nextState: $nextState }';
  }
}
