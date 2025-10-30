class Change<State> {
  const Change({required this.currentState, required this.nextState});

  final State currentState;
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
