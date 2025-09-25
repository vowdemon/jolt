import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const JoltDevToolsExtension());
}

class JoltDevToolsExtension extends StatelessWidget {
  const JoltDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: ExtensionView(), // Build your extension here
    );
  }
}

class ExtensionView extends StatefulWidget {
  const ExtensionView({super.key});

  @override
  State<ExtensionView> createState() => _ExtensionViewState();
}

class _ExtensionViewState extends State<ExtensionView> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Hello, World! $_result'),
        ElevatedButton(
          onPressed: () async {
            final result = await serviceManager
                .callServiceExtensionOnMainIsolate('ext.jolt.getAllNodes');
            setState(() {
              _result = result.json?.toString();
            });
          },
          child: const Text('Click me'),
        ),
      ],
    );
  }
}
