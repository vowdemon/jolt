import 'package:jolt/jolt.dart';

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
        break;
      case DebugNodeOperationType.dispose:
        disposeCount++;
        break;
      case DebugNodeOperationType.notify:
        notifyCount++;
        break;
      case DebugNodeOperationType.set:
        setCount++;
        break;
      case DebugNodeOperationType.get:
        getCount++;
        break;
      case DebugNodeOperationType.linked:
        linked++;
        break;
      case DebugNodeOperationType.unlinked:
        unlinked++;
        break;
      case DebugNodeOperationType.effect:
        effectCount++;
        break;
    }
    count++;
  }

  @override
  String toString() {
    return 'DebugCounter(createCount: $createCount, disposeCount: $disposeCount, notifyCount: $notifyCount, setCount: $setCount, getCount: $getCount, linkedCount: $linked, unlinkedCount: $unlinked, effectCount: $effectCount, count: $count)';
  }

  void onDebug(DebugNodeOperationType type, _) {
    increment(type);
  }
}

class TestPerson {
  final String name;
  final int age;

  TestPerson(this.name, this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPerson && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

class TestSource<T> implements AsyncSource<T> {
  bool _disposed = false;

  @override
  void start(dynamic emit) {
    // emit.set(AsyncData('test' as T));
  }

  @override
  void dispose() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}
