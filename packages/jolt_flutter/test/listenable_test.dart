import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/extension.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltValueListenable', () {
    test('Signal.listenable - basic functionality', () {
      final signal = Signal(0);
      final listenable = signal.listenable;

      expect(listenable.value, 0);
      expect(listenable.node, signal);

      signal.value = 1;
      expect(listenable.value, 1);
    });

    test('Computed.listenable - basic functionality', () {
      final signal = Signal(0);
      final computed = Computed(() => signal.value * 2);
      final listenable = computed.listenable;

      expect(listenable.value, 0);
      expect(listenable.node, computed);

      signal.value = 1;
      expect(listenable.value, 2);
    });

    test('listenable - caching mechanism', () {
      final signal = Signal(0);
      final listenable1 = signal.listenable;
      final listenable2 = signal.listenable;

      expect(identical(listenable1, listenable2), true);
    });

    test('listenable - listener functionality', () {
      final signal = Signal(0);
      final listenable = signal.listenable;
      int callCount = 0;

      void listener() {
        callCount++;
      }

      listenable.addListener(listener);

      expect(listenable.hasListeners, true);

      signal.value = 1;
      expect(callCount, 1);

      signal.value = 2;
      expect(callCount, 2);

      // Removing non-existent listener should not affect
      listenable.removeListener(() {});
      expect(listenable.hasListeners, true);

      // Remove the actual listener
      listenable.removeListener(listener);
      expect(listenable.hasListeners, false);
    });

    test('listenable - read-only property', () {
      final signal = Signal(0);
      final listenable = signal.listenable;

      // ignore: unnecessary_type_check
      expect(listenable is ValueListenable<int>, true);
      expect(listenable is ValueNotifier<int>, false);
    });

    test('listenable - no updates after dispose', () {
      final signal = Signal(0);
      final listenable = signal.listenable;
      int callCount = 0;

      listenable.addListener(() {
        callCount++;
      });

      expect(listenable.value, 0);

      signal.value = 1;
      expect(listenable.value, 1);
      expect(callCount, 1);

      listenable.dispose();

      signal.value = 2;
      // After dispose, value can still be read (using peek), but listeners no longer trigger
      expect(listenable.value, 2);
      expect(callCount, 1); // Listener no longer triggers
    });

    test('listenable - independent caching for multiple signals', () {
      final signal1 = Signal(0);
      final signal2 = Signal(10);

      final listenable1a = signal1.listenable;
      final listenable1b = signal1.listenable;
      final listenable2a = signal2.listenable;
      final listenable2b = signal2.listenable;

      expect(identical(listenable1a, listenable1b), true);
      expect(identical(listenable2a, listenable2b), true);
      expect(identical(listenable1a, listenable2a), false);
    });

    testWidgets('listenable - usage in Widget', (tester) async {
      final signal = Signal(0);
      final listenable = signal.listenable;
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: listenable,
              builder: (context, value, child) {
                rebuildCount++;
                return Text('Value: $value');
              },
            ),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      signal.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    test('ValueListenable.toListenableSignal - unidirectional sync', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toListenableSignal();

      expect(signal.value, 0);

      notifier.value = 1;
      expect(signal.value, 1);

      // ReadonlySignal cannot set value directly
      expect(() {
        (signal as dynamic).value = 2;
      }, throwsA(isA<NoSuchMethodError>()));
    });

    test('ValueListenable.toListenableSignal - listener sync', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toListenableSignal();
      int callCount = 0;

      final effect = Effect(() {
        signal.value; // Read value to establish dependency
        callCount++;
      });

      notifier.value = 1;
      expect(callCount, 2); // Initial execution + update
      expect(signal.value, 1);

      notifier.value = 2;
      expect(callCount, 3);
      expect(signal.value, 2);

      effect.dispose();
    });

    test('ValueListenable.toListenableSignal - dispose cleanup', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toListenableSignal();
      int callCount = 0;

      final effect = Effect(() {
        signal.value; // Read value to establish dependency
        callCount++;
      });

      expect(signal.value, 0);
      expect(callCount, 1); // Initial execution

      signal.dispose();

      notifier.value = 1;
      // Accessing value after dispose throws exception
      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(callCount, 1); // Effect no longer triggers

      effect.dispose();
    });

    testWidgets('ValueListenable.toListenableSignal - usage in Widget',
        (tester) async {
      final notifier = ValueNotifier(0);
      final signal = notifier.toListenableSignal();
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: Key('increment'),
                  onPressed: () {
                    notifier.value++;
                  },
                  child: Text('Increment'),
                ),
                JoltBuilder(
                  builder: (context) {
                    rebuildCount++;
                    return Text('Signal: ${signal.value}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Signal: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Signal: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    test(
        'ValueListenable.toListenableSignal - multiple conversions return same instance',
        () {
      // Signal -> listenable -> toListenableSignal should return original Signal
      final signal = Signal(0);
      final listenable = signal.listenable;
      final signal2 = listenable.toListenableSignal();

      // Should return the same Signal instance
      expect(identical(signal, signal2), true);

      // Verify sync
      signal.value = 1;
      expect(signal2.value, 1);
      expect(listenable.value, 1);
    });

    test(
        'ValueListenable.toListenableSignal - Computed conversion returns original instance',
        () {
      // Computed -> listenable -> toListenableSignal should return original Computed
      // because Computed implements ReadonlySignal interface
      final source = Signal(0);
      final computed = Computed(() => source.value * 2);
      final listenable = computed.listenable;
      final signal = listenable.toListenableSignal();

      // Should return original Computed instance because Computed implements ReadonlySignal
      expect(identical(computed, signal), true);
      expect(signal is Computed<int>, true);

      // Verify sync
      expect(signal.value, 0);
      source.value = 1;
      expect(signal.value, 2);
      expect(listenable.value, 2);
    });

    test(
        'ValueListenable.toListenableSignal - multiple calls return same instance',
        () {
      final signal = Signal(0);
      final listenable = signal.listenable;
      final signal1 = listenable.toListenableSignal();
      final signal2 = listenable.toListenableSignal();

      // Multiple calls should return the same instance
      expect(identical(signal1, signal2), true);
      expect(identical(signal, signal1), true);
    });

    test(
        'ValueListenable.toListenableSignal - multiple signals from same notifier share delegated and refcount works correctly',
        () async {
      final notifier = ValueNotifier(0);

      // 创建多个 signal，它们应该共享同一个 delegated
      final signal1 = notifier.toListenableSignal();
      final signal2 = notifier.toListenableSignal();
      final signal3 = notifier.toListenableSignal();

      // 验证所有 signal 都能正常工作
      expect(signal1.value, 0);
      expect(signal2.value, 0);
      expect(signal3.value, 0);

      // 验证同步
      notifier.value = 1;
      expect(signal1.value, 1);
      expect(signal2.value, 1);
      expect(signal3.value, 1);

      // 验证它们共享同一个 delegated（通过检查行为）
      // 如果它们共享同一个 delegated，dispose 一个后，其他应该仍然工作
      // 并且当所有都被 dispose 后，再次创建应该创建新的 delegated

      // 异步 dispose signal1
      signal1.dispose();

      // 等待异步清理完成（JFinalizer 可能异步执行）
      await Future.delayed(Duration(milliseconds: 10));

      // signal1 应该已经被标记为 disposed
      expect(signal1.isDisposed, true);

      // signal2 和 signal3 应该仍然可以正常工作（因为 delegated 还有引用）
      notifier.value = 2;
      expect(signal2.value, 2);
      expect(signal3.value, 2);

      // signal1 的 value 可能仍然可以访问（因为 delegated.source 仍然有效）
      // 但 isDisposed 应该为 true
      expect(signal1.isDisposed, true);

      // 异步 dispose signal2
      signal2.dispose();
      await Future.delayed(Duration(milliseconds: 10));
      expect(signal2.isDisposed, true);

      // signal3 应该仍然可以正常工作
      notifier.value = 3;
      expect(signal3.value, 3);
      expect(signal3.isDisposed, false);

      // 异步 dispose signal3（最后一个）
      signal3.dispose();
      await Future.delayed(Duration(milliseconds: 10));
      expect(signal3.isDisposed, true);

      // 现在所有 signal 都被 dispose 了，delegated 应该也被清理
      // 再次创建新的 signal 应该会创建新的 delegated
      final signal4 = notifier.toListenableSignal();
      expect(signal4.isDisposed, false);
      expect(signal4.value, 3); // 应该能读取当前值

      // 验证新的 signal 可以正常工作
      notifier.value = 4;
      expect(signal4.value, 4);

      // 验证 signal4 是新的实例（不是之前的任何一个）
      expect(identical(signal1, signal4), false);
      expect(identical(signal2, signal4), false);
      expect(identical(signal3, signal4), false);

      // 清理
      signal4.dispose();
      notifier.dispose();
    });

    test(
        'ValueListenable.toListenableSignal - dispose one signal should not dispose delegated when others still exist',
        () async {
      final notifier = ValueNotifier(0);

      // 创建多个 signal，它们应该共享同一个 delegated
      final signal1 = notifier.toListenableSignal();
      final signal2 = notifier.toListenableSignal();
      final signal3 = notifier.toListenableSignal();

      // 验证所有 signal 都能正常工作
      expect(signal1.value, 0);
      expect(signal2.value, 0);
      expect(signal3.value, 0);

      // 验证同步
      notifier.value = 1;
      expect(signal1.value, 1);
      expect(signal2.value, 1);
      expect(signal3.value, 1);

      // Dispose signal1
      signal1.dispose();
      expect(signal1.isDisposed, true);

      // 等待可能的异步清理
      await Future.delayed(Duration(milliseconds: 10));

      // signal2 和 signal3 应该仍然可以正常工作
      // 如果 delegated 被过早 dispose，这里会失败
      notifier.value = 2;
      expect(signal2.value, 2,
          reason: 'signal2 should still work after signal1 is disposed');
      expect(signal3.value, 2,
          reason: 'signal3 should still work after signal1 is disposed');

      // 再次更新，确保 delegated 仍然有效
      notifier.value = 3;
      expect(signal2.value, 3, reason: 'signal2 should still work');
      expect(signal3.value, 3, reason: 'signal3 should still work');

      // 清理
      signal2.dispose();
      signal3.dispose();
      notifier.dispose();
    });

    test(
        'ValueListenable.toListenableSignal - multiple dispose calls should not cause double release',
        () async {
      final notifier = ValueNotifier(0);

      // 创建多个 signal
      final signal1 = notifier.toListenableSignal();
      final signal2 = notifier.toListenableSignal();

      // 验证初始状态
      expect(signal1.value, 0);
      expect(signal2.value, 0);

      // 多次调用 dispose（虽然不应该这样做，但应该安全处理）
      signal1.dispose();
      expect(signal1.isDisposed, true);

      // 再次调用 dispose 应该被忽略
      signal1.dispose();
      expect(signal1.isDisposed, true);

      // 等待可能的异步清理
      await Future.delayed(Duration(milliseconds: 10));

      // signal2 应该仍然可以正常工作
      // 如果 release 被多次调用导致 refCount 错误，这里会失败
      notifier.value = 1;
      expect(signal2.value, 1,
          reason:
              'signal2 should still work after signal1 is disposed multiple times');

      // 清理
      signal2.dispose();
      notifier.dispose();
    });
  });

  group('JoltValueNotifier', () {
    test('Signal.notifier - basic functionality', () {
      final signal = Signal(0);
      final notifier = signal.notifier;

      expect(notifier.value, 0);

      signal.value = 1;
      expect(notifier.value, 1);
    });

    test('Signal.notifier - bidirectional sync', () {
      final signal = Signal(0);
      final notifier = signal.notifier;

      expect(signal.value, 0);
      expect(notifier.value, 0);

      signal.value = 1;
      expect(signal.value, 1);
      expect(notifier.value, 1);

      notifier.value = 2;
      expect(signal.value, 2);
      expect(notifier.value, 2);
    });

    test('Signal.notifier - caching mechanism', () {
      final signal = Signal(0);
      final notifier1 = signal.notifier;
      final notifier2 = signal.notifier;

      expect(identical(notifier1, notifier2), true);
    });

    test('Signal.notifier - listener functionality', () {
      final signal = Signal(0);
      final notifier = signal.notifier;
      int callCount = 0;

      notifier.addListener(() {
        callCount++;
      });

      expect(notifier.hasListeners, true);

      signal.value = 1;
      expect(callCount, 1);
      expect(notifier.value, 1);

      notifier.value = 2;
      expect(callCount, 2);
      expect(signal.value, 2);
    });

    test('Signal.notifier - no sync after dispose', () {
      final signal = Signal(0);
      final notifier = signal.notifier;
      int callCount = 0;

      notifier.addListener(() {
        callCount++;
      });

      expect(notifier.value, 0);

      signal.value = 1;
      expect(notifier.value, 1);
      expect(callCount, 1);

      notifier.dispose();

      signal.value = 2;
      // After dispose, value can still be read (using peek), but listeners no longer trigger
      expect(notifier.value, 2);
      expect(callCount, 1); // Listener no longer triggers
    });

    test('Signal.notifier - independent caching for multiple signals', () {
      final signal1 = Signal(0);
      final signal2 = Signal(10);

      final notifier1a = signal1.notifier;
      final notifier1b = signal1.notifier;
      final notifier2a = signal2.notifier;
      final notifier2b = signal2.notifier;

      expect(identical(notifier1a, notifier1b), true);
      expect(identical(notifier2a, notifier2b), true);
      expect(identical(notifier1a, notifier2a), false);
    });

    testWidgets('Signal.notifier - usage in Widget', (tester) async {
      final signal = Signal(0);
      final notifier = signal.notifier;
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: Key('incrementSignal'),
                  onPressed: () {
                    signal.value++;
                  },
                  child: Text('Increment Signal'),
                ),
                ElevatedButton(
                  key: Key('incrementNotifier'),
                  onPressed: () {
                    notifier.value++;
                  },
                  child: Text('Increment Notifier'),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: notifier,
                  builder: (context, value, child) {
                    rebuildCount++;
                    return Text('Value: $value');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementSignal')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('incrementNotifier')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 2'), findsOneWidget);
      expect(rebuildCount, 3);
      expect(signal.value, 2);
    });

    test('ValueNotifier.toNotifierSignal - bidirectional sync', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();

      expect(notifier.value, 0);
      expect(signal.value, 0);

      notifier.value = 1;
      expect(notifier.value, 1);
      expect(signal.value, 1);

      signal.value = 2;
      expect(notifier.value, 2);
      expect(signal.value, 2);
    });

    test('ValueNotifier.toNotifierSignal - listener sync', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();
      int signalCallCount = 0;
      int notifierCallCount = 0;

      final effect = Effect(() {
        signal.value; // Read value to establish dependency
        signalCallCount++;
      });

      notifier.addListener(() {
        notifierCallCount++;
      });

      notifier.value = 1;
      expect(signalCallCount, 2); // Initial execution + update
      expect(notifierCallCount, 1);
      expect(signal.value, 1);
      expect(notifier.value, 1);

      signal.value = 2;
      expect(signalCallCount, 3);
      expect(notifierCallCount, 2);
      expect(signal.value, 2);
      expect(notifier.value, 2);

      effect.dispose();
    });

    test('ValueNotifier.toNotifierSignal - dispose cleanup', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();
      int callCount = 0;

      final effect = Effect(() {
        signal.value; // Read value to establish dependency
        callCount++;
      });

      expect(signal.value, 0);
      expect(callCount, 1); // Initial execution

      signal.dispose();

      notifier.value = 1;
      // Accessing value after dispose throws exception
      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(callCount, 1); // Effect no longer triggers

      effect.dispose();
    });

    test('ValueNotifier.toNotifierSignal - avoid circular updates', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();

      // Setting the same value should not trigger updates
      var count = 0;
      final effect = Effect(() {
        signal.value;
        count++;
      });
      expect(count, 1);
      notifier.value = 0;
      expect(count, 1);
      effect.dispose();

      void listener() {
        count++;
      }

      count = 0;
      notifier.addListener(listener);
      signal.value = 0;

      expect(count, 0);
      notifier.removeListener(listener);
    });

    testWidgets('ValueNotifier.toNotifierSignal - usage in Widget',
        (tester) async {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: Key('incrementNotifier'),
                  onPressed: () {
                    notifier.value++;
                  },
                  child: Text('Increment Notifier'),
                ),
                ElevatedButton(
                  key: Key('incrementSignal'),
                  onPressed: () {
                    signal.value++;
                  },
                  child: Text('Increment Signal'),
                ),
                JoltBuilder(
                  builder: (context) {
                    rebuildCount++;
                    return Text(
                        'Notifier: ${notifier.value}, Signal: ${signal.value}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Notifier: 0, Signal: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementNotifier')));
      await tester.pumpAndSettle();

      expect(find.text('Notifier: 1, Signal: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('incrementSignal')));
      await tester.pumpAndSettle();

      expect(find.text('Notifier: 2, Signal: 2'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    test(
        'ValueNotifier.toNotifierSignal - multiple conversions return same instance',
        () {
      // Signal -> notifier -> toNotifierSignal should return original Signal
      final signal = Signal(0);
      final notifier = signal.notifier;
      final signal2 = notifier.toNotifierSignal();

      // Should return the same Signal instance
      expect(identical(signal, signal2), true);

      // Verify bidirectional sync
      signal.value = 1;
      expect(signal2.value, 1);
      expect(notifier.value, 1);

      signal2.value = 2;
      expect(signal.value, 2);
      expect(notifier.value, 2);
    });

    test('ValueNotifier.toNotifierSignal - multiple calls return same instance',
        () {
      final signal = Signal(0);
      final notifier = signal.notifier;
      final signal1 = notifier.toNotifierSignal();
      final signal2 = notifier.toNotifierSignal();

      // Multiple calls should return the same instance
      expect(identical(signal1, signal2), true);
      expect(identical(signal, signal1), true);
    });

    test('complex conversion chain', () {
      final n1 = ValueNotifier(0);
      final rs1 = n1.toListenableSignal();
      final s1 = n1.toNotifierSignal();
      final n2 = s1.notifier;
      final rs2 = n2.toListenableSignal();
      final s3 = n2.toNotifierSignal();

      // Initial state
      expect(n1.value, 0);
      expect(rs1.value, 0);
      expect(s1.value, 0);
      expect(n2.value, 0);
      expect(rs2.value, 0);
      expect(s3.value, 0);

      // Update from original ValueNotifier
      n1.value = 1;
      expect(n1.value, 1);
      expect(rs1.value, 1);
      expect(s1.value, 1);
      expect(n2.value, 1);
      expect(rs2.value, 1);
      expect(s3.value, 1);

      // Update from Signal s1
      s1.value = 2;
      expect(n1.value, 2);
      expect(rs1.value, 2);
      expect(s1.value, 2);
      expect(n2.value, 2);
      expect(rs2.value, 2);
      expect(s3.value, 2);

      // Update from ValueNotifier n2
      n2.value = 3;
      expect(n1.value, 3);
      expect(rs1.value, 3);
      expect(s1.value, 3);
      expect(n2.value, 3);
      expect(rs2.value, 3);
      expect(s3.value, 3);

      // Update from Signal s3
      s3.value = 4;
      expect(n1.value, 4);
      expect(rs1.value, 4);
      expect(s1.value, 4);
      expect(n2.value, 4);
      expect(rs2.value, 4);
      expect(s3.value, 4);

      // Cleanup
      n1.dispose();
      s1.dispose();
      s3.dispose();
    });

    test('multiple conversions dispose test', () {
      final n1 = ValueNotifier(0);
      final rs1 = n1.toListenableSignal();
      final rs2 = n1.toListenableSignal();
      final s1 = n1.toNotifierSignal();
      final s2 = n1.toNotifierSignal();

      // All should sync
      n1.value = 1;
      expect(n1.value, 1);
      expect(rs1.value, 1);
      expect(rs2.value, 1);
      expect(s1.value, 1);
      expect(s2.value, 1);

      // Dispose a read-only signal
      rs1.dispose();

      // Others should still work
      n1.value = 2;
      expect(n1.value, 2);
      expect(rs2.value, 2);
      expect(s1.value, 2);
      expect(s2.value, 2);

      // Dispose a writable signal
      s1.dispose();

      // Others should still work
      n1.value = 3;
      expect(n1.value, 3);
      expect(rs2.value, 3);
      expect(s2.value, 3);

      // Test bidirectional sync of remaining signal
      s2.value = 4;
      expect(n1.value, 4);
      expect(rs2.value, 4);
      expect(s2.value, 4);

      // Cleanup
      n1.dispose();
      rs2.dispose();
      s2.dispose();
    });
  });
}
