import 'package:jolt/jolt.dart';

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
