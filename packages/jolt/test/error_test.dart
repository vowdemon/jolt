import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('Error classes', () {
    group('AssertionError', () {
      test('should be thrown when accessing disposed signal value', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.value, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when setting disposed signal value', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.value = 100, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling forceUpdate on disposed signal', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.notify(), throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling get on disposed signal', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.get(), throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling set on disposed signal', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.set(100), throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing stream on disposed signal', () {
        final signal = Signal(42);
        signal.dispose();

        expect(() => signal.stream, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling listen on disposed signal', () {
        final signal = Signal(42);
        signal.dispose();

        expect(
          () => signal.listen((value) {}),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should be thrown when accessing disposed signal in computed', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        signal.dispose();

        expect(() => computed.value, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed signal in effect', () {
        final signal = Signal(42);
        final List<int> values = [];

        final _ = Effect(() {
          values.add(signal.value);
        });

        signal.dispose();

        expect(() => signal.value, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed signal in batch', () {
        final signal = Signal(42);

        signal.dispose();

        expect(() {
          batch(() {
            signal.value = 100;
          });
        }, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed signal in untracked', () {
        final signal = Signal(42);

        signal.dispose();

        expect(() {
          untracked(() => signal.value);
        }, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed list signal', () {
        final listSignal = ListSignal<int>([1, 2, 3]);
        listSignal.dispose();

        expect(() => listSignal.value, throwsA(isA<AssertionError>()));
        expect(() => listSignal.add(4), throwsA(isA<AssertionError>()));
        expect(() => listSignal.length, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed map signal', () {
        final mapSignal = MapSignal<String, int>({'a': 1});
        mapSignal.dispose();

        expect(() => mapSignal.value, throwsA(isA<AssertionError>()));
        expect(() => mapSignal['b'] = 2, throwsA(isA<AssertionError>()));
        expect(() => mapSignal.length, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed set signal', () {
        final setSignal = SetSignal<int>({1, 2, 3});
        setSignal.dispose();

        expect(() => setSignal.value, throwsA(isA<AssertionError>()));
        expect(() => setSignal.add(4), throwsA(isA<AssertionError>()));
        expect(() => setSignal.length, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed async signal', () async {
        final future = Future.value(42);
        final asyncSignal = AsyncSignal.fromFuture(future);

        await Future.microtask(() {});

        asyncSignal.dispose();

        expect(() => asyncSignal.value, throwsA(isA<AssertionError>()));
        expect(() => asyncSignal.data, throwsA(isA<AssertionError>()));
      });
    });

    group('AssertionError', () {
      test('should be thrown when accessing disposed computed value', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        computed.dispose();

        expect(() => computed.value, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling get on disposed computed', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        computed.dispose();

        expect(() => computed.get(), throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing stream on disposed computed', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        computed.dispose();

        expect(() => computed.stream, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when calling listen on disposed computed', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        computed.dispose();

        expect(
          () => computed.listen((value) {}),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should be thrown when accessing disposed computed in effect', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);
        final List<int> values = [];

        final effect = Effect(() {
          values.add(computed.value);
        });

        computed.dispose();

        expect(() => effect.fn(), throwsA(isA<AssertionError>()));
      });

      test('should be thrown when accessing disposed computed in batch', () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        computed.dispose();

        expect(() {
          batch(() {
            signal.value = 100;
            // 这会触发computed重新计算，但computed已释放
            final _ = computed.value;
          });
        }, throwsA(isA<AssertionError>()));
      });

      test(
        'should be thrown when accessing disposed computed in untracked',
        () {
          final signal = Signal(42);
          final computed = Computed<int>(() => signal.value * 2);

          computed.dispose();

          expect(() {
            untracked(() => computed.value);
          }, throwsA(isA<AssertionError>()));
        },
      );

      test('should be thrown when accessing disposed dual computed value', () {
        final signal = Signal(42);
        final dualComputed = WritableComputed<int>(
          () => signal.value * 2,
          (value) => signal.value = value ~/ 2,
        );

        dualComputed.dispose();

        expect(() => dualComputed.value, throwsA(isA<AssertionError>()));
      });

      test('should be thrown when setting disposed dual computed value', () {
        final signal = Signal(42);
        final dualComputed = WritableComputed<int>(
          () => signal.value * 2,
          (value) => signal.value = value ~/ 2,
        );

        dualComputed.dispose();

        expect(
          () => dualComputed.value = 100,
          throwsA(isA<AssertionError>()),
        );
      });

      test('should be thrown when calling set on disposed dual computed', () {
        final signal = Signal(42);
        final dualComputed = WritableComputed<int>(
          () => signal.value * 2,
          (value) => signal.value = value ~/ 2,
        );

        dualComputed.dispose();

        expect(
          () => dualComputed.set(100),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should be thrown when accessing disposed iterable signal', () {
        final iterable = [1, 2, 3];
        final iterableSignal = IterableSignal.value(iterable);

        iterableSignal.dispose();

        expect(
          () => iterableSignal.value,
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => iterableSignal.length,
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => iterableSignal.first,
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Error handling in complex scenarios', () {
      test('should handle errors in nested computations', () {
        final signal = Signal(42);
        final computed1 = Computed<int>(() => signal.value * 2);
        final computed2 = Computed<int>(() => computed1.value + 1);

        computed1.dispose();

        expect(() => computed2.value, throwsA(isA<AssertionError>()));
      });

      test('should handle errors in effect chains', () {
        final signal = Signal(42);
        final List<int> values = [];

        final effect1 = Effect(() {
          values.add(signal.value);
        });

        final effect2 = Effect(() {
          values.add(signal.value * 2);
        });

        signal.dispose();

        expect(() => effect1.fn(), throwsA(isA<AssertionError>()));
        expect(() => effect2.fn(), throwsA(isA<AssertionError>()));
      });

      test('should handle errors in batch operations', () {
        final signal1 = Signal(42);
        final signal2 = Signal(100);
        final computed = Computed<int>(() => signal1.value + signal2.value);

        signal1.dispose();

        expect(() {
          batch(() {
            signal2.value = 200;
            // 这会触发computed重新计算，但signal1已释放
            final _ = computed.value;
          });
        }, throwsA(isA<AssertionError>()));
      });

      test('should handle errors in async operations', () async {
        final future = Future.value(42);
        final asyncSignal = AsyncSignal.fromFuture(future);
        final computed = Computed<String>(() {
          return asyncSignal.value.map(
                loading: () => 'loading',
                success: (data) => 'success: $data',
                error: (error, stackTrace) => 'error: $error',
              ) ??
              'unknown';
        });

        asyncSignal.dispose();

        expect(() => computed.value, throwsA(isA<AssertionError>()));
      });

      test('should handle errors in collection signals', () {
        final listSignal = ListSignal<int>([1, 2, 3]);
        final mapSignal = MapSignal<String, int>({'a': 1});
        final setSignal = SetSignal<int>({1, 2, 3});

        listSignal.dispose();
        mapSignal.dispose();
        setSignal.dispose();

        expect(() => listSignal.add(4), throwsA(isA<AssertionError>()));
        expect(() => mapSignal['b'] = 2, throwsA(isA<AssertionError>()));
        expect(() => setSignal.add(4), throwsA(isA<AssertionError>()));
      });

      test('should handle errors in stream operations', () async {
        final signal = Signal(42);
        final List<int> values = [];

        final _ = signal.stream.listen((value) {
          values.add(value);
        });

        signal.dispose();

        // 已释放的信号不应该再发出事件
        try {
          signal.value = 100;
        } catch (e) {
          expect(e, isA<AssertionError>());
        }

        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([]));
      });

      test('should handle errors in forceUpdate operations', () {
        final signal = Signal(42);
        final List<int> values = [];

        final _ = Effect(() {
          values.add(signal.value);
        });

        signal.dispose();

        expect(() => signal.notify(), throwsA(isA<AssertionError>()));
      });

      test('should handle errors in auto dispose scenarios', () {
        final signal = Signal(42, autoDispose: true);
        final List<int> values = [];

        final _ = Effect(() {
          values.add(signal.value);
        });

        // 当没有引用时，信号应该被自动释放
        // 这里我们手动调用dispose来模拟
        signal.dispose();

        expect(() => signal.value, throwsA(isA<AssertionError>()));
      });
    });
  });
}
