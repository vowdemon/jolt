import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';

enum JoltValueChildKind {
  field,
  listIndex,
  mapValue,
  range,
}

class JoltValueChild {
  const JoltValueChild._({
    required this.kind,
    required this.label,
    required this.path,
    required this.value,
    this.field,
    this.index,
    this.rangeStart,
    this.rangeEnd,
  });

  const JoltValueChild.field({
    required String label,
    required JoltValuePath path,
    required JoltInspectedValue value,
    required JoltObjectField field,
  }) : this._(
          kind: JoltValueChildKind.field,
          label: label,
          path: path,
          value: value,
          field: field,
        );

  const JoltValueChild.index({
    required String label,
    required JoltValuePath path,
    required JoltInspectedValue value,
    required int index,
  }) : this._(
          kind: JoltValueChildKind.listIndex,
          label: label,
          path: path,
          value: value,
          index: index,
        );

  const JoltValueChild.mapValue({
    required String label,
    required JoltValuePath path,
    required JoltInspectedValue value,
  }) : this._(
          kind: JoltValueChildKind.mapValue,
          label: label,
          path: path,
          value: value,
        );

  const JoltValueChild.range({
    required String label,
    required JoltValuePath path,
    required JoltInspectedValue value,
    required int start,
    required int end,
  }) : this._(
          kind: JoltValueChildKind.range,
          label: label,
          path: path,
          value: value,
          rangeStart: start,
          rangeEnd: end,
        );

  final JoltValueChildKind kind;
  final String label;
  final JoltValuePath path;
  final JoltInspectedValue value;
  final JoltObjectField? field;
  final int? index;
  final int? rangeStart;
  final int? rangeEnd;

  JoltValueChild copyWithValue(JoltInspectedValue nextValue) {
    return switch (kind) {
      JoltValueChildKind.field => JoltValueChild.field(
          label: label,
          path: path,
          value: nextValue,
          field: field!,
        ),
      JoltValueChildKind.listIndex => JoltValueChild.index(
          label: label,
          path: path,
          value: nextValue,
          index: index!,
        ),
      JoltValueChildKind.mapValue => JoltValueChild.mapValue(
          label: label,
          path: path,
          value: nextValue,
        ),
      JoltValueChildKind.range => JoltValueChild.range(
          label: label,
          path: path,
          value: nextValue,
          start: rangeStart!,
          end: rangeEnd!,
        ),
    };
  }
}
