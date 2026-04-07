import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';

class JoltObjectHeader extends StatelessWidget {
  const JoltObjectHeader({
    super.key,
    required this.value,
  });

  final JoltInspectedValue value;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if ((value.typeName?.isNotEmpty ?? false) &&
          value.kind != JoltInspectedValueKind.enumeration)
        value.typeName!,
      if (value.hashCodeDisplay?.isNotEmpty ?? false)
        '#${value.hashCodeDisplay}',
      if (value.length != null && value.kind != JoltInspectedValueKind.range)
        'size ${value.length}',
      if (value.state != JoltInspectedValueState.available) value.state.name,
    ];

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      parts.join(' • '),
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade500,
      ),
    );
  }
}
