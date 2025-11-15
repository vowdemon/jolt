import "dart:async";

import "package:jolt/jolt.dart";
import "package:meta/meta.dart";

class DebugCounter {
  int createCount = 0;
  int disposeCount = 0;
  int notifyCount = 0;
  int setCount = 0;
  int getCount = 0;
  int linked = 0;
  int unlinked = 0;
  int effectCount = 0;
  int count = 0;

  void reset() {
    createCount = 0;
    disposeCount = 0;
    notifyCount = 0;
    setCount = 0;
    getCount = 0;
    linked = 0;
    unlinked = 0;
    effectCount = 0;
    count = 0;
  }

  void increment(DebugNodeOperationType type) {
    switch (type) {
      case DebugNodeOperationType.create:
        createCount++;
      case DebugNodeOperationType.dispose:
        disposeCount++;
      case DebugNodeOperationType.notify:
        notifyCount++;
      case DebugNodeOperationType.set:
        setCount++;
      case DebugNodeOperationType.get:
        getCount++;
      case DebugNodeOperationType.linked:
        linked++;
      case DebugNodeOperationType.unlinked:
        unlinked++;
      case DebugNodeOperationType.effect:
        effectCount++;
    }
    count++;
  }

  @override
  String toString() =>
      "DebugCounter(createCount: $createCount, disposeCount: $disposeCount, notifyCount: $notifyCount, setCount: $setCount, getCount: $getCount, linkedCount: $linked, unlinkedCount: $unlinked, effectCount: $effectCount, count: $count)";

  void onDebug(DebugNodeOperationType type, _) {
    increment(type);
  }
}

@immutable
class TestPerson {
  TestPerson(this.name, this.age);
  final String name;
  final int age;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPerson && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

class TestSource<T> extends AsyncSource<T> {
  bool _disposed = false;

  @override
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) {}

  @override
  void dispose() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}
