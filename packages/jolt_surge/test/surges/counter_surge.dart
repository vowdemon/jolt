import 'package:jolt_surge/jolt_surge.dart';
import 'package:jolt_surge/observer.dart';

class CounterSurge extends Surge<int> {
  CounterSurge({this.onChangeCallback}) : super(0);

  final void Function(Change<int>)? onChangeCallback;

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

  @override
  void onChange(Change<int> change) {
    super.onChange(change);
    onChangeCallback?.call(change);
  }
}
