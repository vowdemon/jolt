import "dart:async";

import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/signal.dart";
import "package:test/test.dart";

import "utils.dart";

class DebouncedSignal<T> extends SignalImpl<T> {
  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });
  final Duration delay;
  Timer? _timer;

  @override
  T set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
    return value;
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

void main() {
  group("Custom Features", () {
    group("DebouncedSignal", () {
      test("should delay value update", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        expect(signal.value, equals(0));
        expect(signal.peek, equals(0));

        signal.set(1);
        expect(signal.value, equals(0));
        expect(signal.peek, equals(0));

        await Future.delayed(const Duration(milliseconds: 150));
        expect(signal.value, equals(1));
        expect(signal.peek, equals(1));
        expect(counter.setCount, equals(1));

        signal.dispose();
      });

      test("should reset timer when updated multiple times during delay",
          () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );
        // test code
        // ignore: cascade_invocations
        signal.set(1);
        await Future.delayed(const Duration(milliseconds: 50));
        signal.set(2);
        await Future.delayed(const Duration(milliseconds: 50));
        signal.set(3);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(signal.value, equals(0));

        await Future.delayed(const Duration(milliseconds: 60));
        expect(signal.value, equals(3));
        expect(counter.setCount, equals(1));

        signal.dispose();
      });

      test("should cancel pending updates on dispose", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        final initialValue = signal.value;
        expect(initialValue, equals(0));

        signal
          ..set(1)
          ..dispose();

        await Future.delayed(const Duration(milliseconds: 150));
        expect(counter.setCount, equals(0));
      });

      test("should notify subscribers after debounce completes", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        final values = <int>[];
        final effect = Effect(() {
          values.add(signal.value);
        });

        signal
          ..set(1)
          ..set(2)
          ..set(3);

        await Future.delayed(const Duration(milliseconds: 150));

        expect(values, equals([0, 3]));
        expect(counter.setCount, equals(1));

        effect.dispose();
        signal.dispose();
      });

      test("basic usage example", () async {
        final searchQuery = DebouncedSignal(
          "",
          delay: const Duration(milliseconds: 300),
        );

        final results = <String>[];
        final effect = Effect(() {
          final query = searchQuery.value;
          if (query.isNotEmpty) {
            results.add("Results for: $query");
          }
        });

        searchQuery.value = "j";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jo";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jol";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jolt";

        expect(results, isEmpty);

        await Future.delayed(const Duration(milliseconds: 350));

        expect(results, equals(["Results for: jolt"]));
        expect(searchQuery.value, equals("jolt"));

        effect.dispose();
        searchQuery.dispose();
      });
    });
  });
}
