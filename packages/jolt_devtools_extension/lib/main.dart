import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/views/inspector_page.dart';

void main() {
  runApp(const JoltDevToolsExtension());
}

class JoltDevToolsExtension extends StatelessWidget {
  const JoltDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: JoltInspectorPage(),
    );
  }
}
