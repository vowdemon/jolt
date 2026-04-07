class JoltValueInspectorPolicy {
  const JoltValueInspectorPolicy({
    this.showPrivateMembers = false,
    this.showGetters = false,
    this.showObjectProperties = true,
    this.showHashCodeAndRuntimeType = false,
  });

  final bool showPrivateMembers;
  final bool showGetters;
  final bool showObjectProperties;
  final bool showHashCodeAndRuntimeType;
}
