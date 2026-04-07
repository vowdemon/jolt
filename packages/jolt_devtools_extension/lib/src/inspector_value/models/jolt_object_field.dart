class JoltObjectField {
  const JoltObjectField({
    required this.name,
    required this.ownerName,
    required this.ownerUri,
    this.isGetter = false,
    this.isFinal = false,
    this.isPrivate = false,
    this.isDefinedByDependency = false,
  });

  final String name;
  final String ownerName;
  final String ownerUri;
  final bool isGetter;
  final bool isFinal;
  final bool isPrivate;
  final bool isDefinedByDependency;

  String get stableId => '$ownerUri::$ownerName::$name';

  @override
  bool operator ==(Object other) {
    return other is JoltObjectField && other.stableId == stableId;
  }

  @override
  int get hashCode => stableId.hashCode;

  @override
  String toString() => stableId;
}
