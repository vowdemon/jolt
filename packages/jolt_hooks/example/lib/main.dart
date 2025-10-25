import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_hooks/jolt_hooks.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jolt Hooks Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: CounterWidget(),
    );
  }
}

class CounterWidget extends HookWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);

    return Scaffold(
      body: JoltBuilder(builder: (context) => Text('Count: ${count.value}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
