enum JoltInspectedValueKind {
  nullValue,
  boolean,
  number,
  string,
  enumeration,
  range,
  list,
  map,
  object,
  set,
  record,
  error,
  unknown,
}

enum JoltInspectedValueState {
  available,
  loading,
  stale,
  unavailable,
  error,
}

enum JoltEditableKind {
  boolean,
  number,
  string,
  nullValue,
}

class JoltValueSetter {
  const JoltValueSetter.rootSignal({
    required this.nodeId,
    required this.editableKind,
  });

  final int nodeId;
  final JoltEditableKind editableKind;
}

class JoltInspectedValue {
  const JoltInspectedValue({
    required this.kind,
    required this.state,
    required this.displayValue,
    this.typeName,
    this.objectId,
    this.length,
    this.isExpandable = false,
    this.setter,
    this.hashCodeDisplay,
  });

  final JoltInspectedValueKind kind;
  final JoltInspectedValueState state;
  final String displayValue;
  final String? typeName;
  final String? objectId;
  final int? length;
  final bool isExpandable;
  final JoltValueSetter? setter;
  final String? hashCodeDisplay;

  factory JoltInspectedValue.error(String message) {
    return JoltInspectedValue(
      kind: JoltInspectedValueKind.error,
      state: JoltInspectedValueState.error,
      displayValue: '<error: $message>',
    );
  }

  factory JoltInspectedValue.unavailable(String message) {
    return JoltInspectedValue(
      kind: JoltInspectedValueKind.unknown,
      state: JoltInspectedValueState.unavailable,
      displayValue: '<$message>',
    );
  }

  JoltInspectedValue copyWith({
    JoltInspectedValueKind? kind,
    JoltInspectedValueState? state,
    String? displayValue,
    String? typeName,
    String? objectId,
    int? length,
    bool? isExpandable,
    JoltValueSetter? setter,
    String? hashCodeDisplay,
  }) {
    return JoltInspectedValue(
      kind: kind ?? this.kind,
      state: state ?? this.state,
      displayValue: displayValue ?? this.displayValue,
      typeName: typeName ?? this.typeName,
      objectId: objectId ?? this.objectId,
      length: length ?? this.length,
      isExpandable: isExpandable ?? this.isExpandable,
      setter: setter ?? this.setter,
      hashCodeDisplay: hashCodeDisplay ?? this.hashCodeDisplay,
    );
  }
}
