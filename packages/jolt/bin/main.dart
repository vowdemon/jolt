import 'package:jolt/jolt.dart';
import 'package:jolt/src/dev.dart';

void main() {
  JoltConfig.observer = DebugJoltObserver();
  print('Hello, World!');
}
