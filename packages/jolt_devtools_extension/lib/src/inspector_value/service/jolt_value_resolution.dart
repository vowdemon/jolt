import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';

class JoltValueResolution {
  const JoltValueResolution({
    required this.path,
    required this.value,
  });

  final JoltValuePath path;
  final JoltInspectedValue value;
}
