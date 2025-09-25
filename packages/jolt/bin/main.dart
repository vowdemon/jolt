import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:jolt/src/dev.dart';

void main() {
  JoltConfig.observer = DebugJoltObserver();
  final signal = Signal<int>(0);
  Timer.periodic(const Duration(seconds: 10), (timer) {
    print('Hello, World!');
  });
}
