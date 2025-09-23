import 'dart:async';

import 'package:flutter/material.dart';
import 'package:free_disposer/free_disposer.dart';

import 'jolt_flutter.dart';

void main() {
  runZoned(() => runApp(MyApp()), zoneValues: {#currentScope: 'main'});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

int count = 0;

class _MyAppState extends State<MyApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: JoltBuilder(builder: (context) {
          final s = Signal(100, autoDispose: true);
          s.disposeWith(() {
            print('s disposed scope: ${Zone.current[#currentScope]}');
          });
          var a = s.listen(
            (value) {
              print('Stream ${value}');
            },
          );
          print('Current scope: ${Zone.current[#currentScope]}');

          Future.delayed(const Duration(seconds: 10), () {
            a?.cancel();
          });
          return Column(
            children: [
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      dark = !dark;
                    });
                    print('Theme scope: ${Zone.current[#currentScope]}');
                  },
                  child: Text('theme')),
              ElevatedButton(
                  onPressed: () {
                    gc();
                  },
                  child: Text('gc')),
              ElevatedButton(
                  onPressed: () {
                    s.value++;
                  },
                  child: Text('s+++')),
              ElevatedButton(
                onPressed: () {
                  j.value = !j.value;
                },
                child: Text('Switch: ${j.value}'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

final j = Signal(true);

abstract interface class JoltStore with DisposableMixin {
  JoltStore();
}

class MyJolt extends JoltStore {
  MyJolt(BuildContext context) {
    c = Computed(() => a.value + b.value.toDouble());
  }

  final s = Signal(true);

  final a = Signal<num>(1);
  final b = Signal<int>(2);
  final d = Signal<double>(3);
  late final Computed<double> c;

  void incA() {
    a.value++;
  }

  void incB() {
    b.value++;
  }
}

void gc() {
  final objs = <Object>[];
  for (var i = 0; i < 3000000; i++) {
    objs.add(Object());
  }
}
