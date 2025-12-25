import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useFuture', () {
    testWidgets('starts with waiting state for non-null future',
        (tester) async {
      final future = Future.value(42);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.waiting'));
    });

    testWidgets('completes with data successfully', (tester) async {
      final future = Future.value(42);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      await tester.pumpAndSettle();

      final text = find.textContaining('Data: 42');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.done'));
      expect(widget.data, contains('Data: 42'));
    });

    testWidgets('handles future error', (tester) async {
      final error = Exception('Test error');
      final future = Future<int>.delayed(Duration.zero, () => throw error);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future);
          return () => Text('State: ${snapshot.connectionState}, '
              'HasError: ${snapshot.hasError}, '
              'HasData: ${snapshot.hasData}, '
              'Error: ${snapshot.error}, '
              'StackTrace: ${snapshot.stackTrace != null}');
        }),
      ));

      await tester.pumpAndSettle();

      final text = find.textContaining('HasError: true');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.done'));
      expect(widget.data, contains('HasError: true'));
      expect(widget.data, contains('HasData: false'));
      expect(widget.data, contains('StackTrace: true'));
    });

    testWidgets('hasData and requireData work correctly', (tester) async {
      final future = Future.value(42);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future);
          return () {
            final hasData = snapshot.hasData;
            final data = hasData ? snapshot.requireData : null;
            return Text('HasData: $hasData, RequireData: $data');
          };
        }),
      ));

      await tester.pumpAndSettle();

      final text = find.textContaining('HasData: true');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('HasData: true'));
      expect(widget.data, contains('RequireData: 42'));
    });

    testWidgets('uses initialData when provided', (tester) async {
      final future = Future.delayed(
        const Duration(milliseconds: 100),
        () => 100,
      );

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future, initialData: 42);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Should show initialData immediately
      final initialText = find.textContaining('Data: 42');
      expect(initialText, findsOneWidget);

      // Wait for future to complete
      await tester.pumpAndSettle();

      // Should update to new data
      final finalText = find.textContaining('Data: 100');
      expect(finalText, findsOneWidget);
    });

    testWidgets('handles null future', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture<int>(null);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.none'));
    });

    testWidgets('handles null future with initialData', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture<int>(null, initialData: 42);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('Data: 42');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.none'));
    });

    testWidgets('switches future when setFuture is called', (tester) async {
      final future1 = Future.delayed(
        const Duration(milliseconds: 50),
        () => 1,
      );
      final future2 = Future.delayed(
        const Duration(milliseconds: 50),
        () => 2,
      );

      AsyncSnapshotFutureSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useFuture(future1);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      // Wait for first future to complete
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 1'), findsOneWidget);

      // Switch to second future
      snapshot!.setFuture(future2);
      await tester.pump();

      // Should reset to waiting
      final waitingText = find.textContaining('State:');
      expect(waitingText, findsOneWidget);

      // Wait for second future to complete
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 2'), findsOneWidget);
    });

    testWidgets('ignores stale callbacks after future switch', (tester) async {
      final completer1 = Completer<int>();
      final completer2 = Completer<int>();

      AsyncSnapshotFutureSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useFuture(completer1.future);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      // Switch to second future before first completes
      snapshot!.setFuture(completer2.future);
      await tester.pump();

      // Complete first future (should be ignored)
      completer1.complete(1);
      await tester.pumpAndSettle();

      // Should still be waiting for second future
      final text = find.textContaining('State:');
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.waiting'));

      // Complete second future
      completer2.complete(2);
      await tester.pumpAndSettle();

      // Should show data from second future
      expect(find.textContaining('Data: 2'), findsOneWidget);
    });

    testWidgets('ignores stale callbacks after unmount', (tester) async {
      final completer = Completer<int>();
      int? callbackData;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(completer.future);
          return () {
            callbackData = snapshot.data;
            return Text('Data: ${snapshot.data}');
          };
        }),
      ));

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Complete future after unmount
      completer.complete(42);
      await tester.pumpAndSettle();

      // callbackData should not be updated (no setState after unmount)
      expect(callbackData, isNull);
    });

    testWidgets('handles synchronous future', (tester) async {
      final future = SynchronousFuture(42);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useFuture(future);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Synchronous future should complete immediately
      await tester.pump();

      final text = find.textContaining('Data: 42');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.done'));
    });

    testWidgets('preserves previous data when switching to null future',
        (tester) async {
      final future = Future.value(42);

      AsyncSnapshotFutureSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useFuture(future);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 42'), findsOneWidget);

      snapshot!.setFuture(null);
      await tester.pump();

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);

      expect(widget.data, contains('ConnectionState.done'));
      expect(widget.data, contains('Data: 42'));
    });
  });

  group('useStream', () {
    testWidgets('starts with waiting state for non-null stream',
        (tester) async {
      final stream = Stream.value(42);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.waiting'));
    });

    testWidgets('receives data and transitions to active state',
        (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Add data
      controller.add(42);
      await tester.pumpAndSettle();

      final text = find.textContaining('Data: 42');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.active'));
      expect(widget.data, contains('Data: 42'));
    });

    testWidgets('receives multiple data values', (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Add first data
      controller.add(1);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 1'), findsOneWidget);

      // Add second data
      controller.add(2);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 2'), findsOneWidget);

      // Add third data
      controller.add(3);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 3'), findsOneWidget);
    });

    testWidgets('transitions to done state when stream completes',
        (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Add data
      controller.add(42);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 42'), findsOneWidget);

      // Close stream
      await controller.close();
      await tester.pumpAndSettle();

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.done'));
      expect(widget.data, contains('Data: 42'));
    });

    testWidgets('handles stream error', (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;
      final error = Exception('Test error');

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () => Text('State: ${snapshot.connectionState}, '
              'HasError: ${snapshot.hasError}, '
              'Error: ${snapshot.error}');
        }),
      ));

      // Add error
      controller.addError(error);
      await tester.pumpAndSettle();

      final text = find.textContaining('HasError: true');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.active'));
      expect(widget.data, contains('HasError: true'));
    });

    testWidgets('uses initialData when provided', (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream, initialData: 0);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      // Should show initialData immediately
      final initialText = find.textContaining('Data: 0');
      expect(initialText, findsOneWidget);

      // Add data
      controller.add(100);
      await tester.pumpAndSettle();

      // Should update to new data
      final finalText = find.textContaining('Data: 100');
      expect(finalText, findsOneWidget);
    });

    testWidgets('handles null stream', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream<int>(null);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('State:');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.none'));
    });

    testWidgets('handles null stream with initialData', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream<int>(null, initialData: 42);
          return () => Text(
              'State: ${snapshot.connectionState}, Data: ${snapshot.data}');
        }),
      ));

      final text = find.textContaining('Data: 42');
      expect(text, findsOneWidget);

      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.none'));
    });

    testWidgets('switches stream when setStream is called', (tester) async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final stream1 = controller1.stream;
      final stream2 = controller2.stream;

      AsyncSnapshotStreamSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useStream(stream1);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      // Add data to first stream
      controller1.add(1);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 1'), findsOneWidget);

      // Switch to second stream
      snapshot!.setStream(stream2);
      await tester.pump();

      // Should reset to waiting
      final waitingText = find.textContaining('State:');
      expect(waitingText, findsOneWidget);

      // Add data to second stream
      controller2.add(2);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 2'), findsOneWidget);

      controller1.close();
      controller2.close();
    });

    testWidgets('ignores stale events after stream switch', (tester) async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final stream1 = controller1.stream;
      final stream2 = controller2.stream;

      AsyncSnapshotStreamSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useStream(stream1);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      // Switch to second stream before first emits
      snapshot!.setStream(stream2);
      await tester.pump();

      // Emit from first stream (should be ignored)
      controller1.add(1);
      await tester.pumpAndSettle();

      // Should still be waiting for second stream
      final text = find.textContaining('State:');
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.waiting'));

      // Emit from second stream
      controller2.add(2);
      await tester.pumpAndSettle();

      // Should show data from second stream
      expect(find.textContaining('Data: 2'), findsOneWidget);

      controller1.close();
      controller2.close();
    });

    testWidgets('cancels subscription on unmount', (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;
      int? callbackData;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final snapshot = useStream(stream);
          return () {
            callbackData = snapshot.data;
            return Text('Data: ${snapshot.data}');
          };
        }),
      ));

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Add data after unmount
      controller.add(42);
      await tester.pumpAndSettle();

      // callbackData should not be updated (no setState after unmount)
      expect(callbackData, isNull);

      controller.close();
    });

    testWidgets('preserves data when switching to null stream', (tester) async {
      final controller = StreamController<int>();
      final stream = controller.stream;

      AsyncSnapshotStreamSignal<int>? snapshot;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          snapshot = useStream(stream);
          return () => Text(
              'State: ${snapshot!.connectionState}, Data: ${snapshot!.data}');
        }),
      ));

      // Add data
      controller.add(42);
      await tester.pumpAndSettle();
      expect(find.textContaining('Data: 42'), findsOneWidget);

      // Switch to null stream
      snapshot!.setStream(null);
      await tester.pump();

      // Should reset to none state, but data preserved
      final text = find.textContaining('State:');
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('ConnectionState.active'));
      expect(widget.data, contains('Data: 42'));

      controller.close();
    });
  });

  group('useStreamController', () {
    testWidgets('creates and disposes StreamController', (tester) async {
      StreamController<int>? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useStreamController<int>();
          return () => Text('Controller: ${controller!.isClosed}');
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.isClosed, isFalse);

      // Unmount - should close controller
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(controller!.isClosed, isTrue);
    });

    testWidgets('creates broadcast StreamController', (tester) async {
      StreamController<int>? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useStreamController.broadcast<int>();
          // Test that broadcast controller allows multiple listeners
          controller!.stream.listen((_) {});
          return () => Text('Broadcast controller');
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.isClosed, isFalse);

      // Broadcast controller should allow multiple listeners
      expect(() => controller!.stream.listen((_) {}), returnsNormally);

      // Unmount - should close controller
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(controller!.isClosed, isTrue);
    });

    testWidgets('StreamController can emit and listen to events',
        (tester) async {
      StreamController<int>? controller;
      final values = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useStreamController<int>();
          controller!.stream.listen((value) {
            values.add(value);
          });
          return () => Text('Values: ${values.length}');
        }),
      ));

      // Emit values
      controller!.add(1);
      controller!.add(2);
      controller!.add(3);
      await tester.pumpAndSettle();

      expect(values, equals([1, 2, 3]));
    });
  });

  group('useStreamSubscription', () {
    testWidgets('subscribes to stream and calls onData', (tester) async {
      final controller = StreamController<int>();
      final values = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useStreamSubscription(
            controller.stream,
            (value) {
              values.add(value);
            },
          );
          return () => Text('Values: ${values.length}');
        }),
      ));

      // Emit values
      controller.add(1);
      await tester.pumpAndSettle();
      expect(values, contains(1));

      controller.add(2);
      await tester.pumpAndSettle();
      expect(values, contains(2));
    });

    testWidgets('handles stream errors with onError', (tester) async {
      final controller = StreamController<int>();
      final errors = <Object>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useStreamSubscription(
            controller.stream,
            null,
            onError: (error, stackTrace) {
              errors.add(error);
            },
          );
          return () => Text('Errors: ${errors.length}');
        }),
      ));

      // Emit error
      final error = Exception('Test error');
      controller.addError(error);
      await tester.pumpAndSettle();

      expect(errors, contains(error));
    });

    testWidgets('calls onDone when stream completes', (tester) async {
      final controller = StreamController<int>();
      bool doneCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useStreamSubscription(
            controller.stream,
            null,
            onDone: () {
              doneCalled = true;
            },
          );
          return () => Text('Done: $doneCalled');
        }),
      ));

      // Close stream
      await controller.close();
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });

    testWidgets('cancels subscription on unmount', (tester) async {
      final controller = StreamController<int>();
      final values = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useStreamSubscription(
            controller.stream,
            (value) {
              values.add(value);
            },
          );
          return () => Text('Values: ${values.length}');
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Emit after unmount - should not be received
      final countBefore = values.length;
      controller.add(42);
      await tester.pumpAndSettle();

      expect(values.length, countBefore);

      controller.close();
    });

    testWidgets('handles cancelOnError parameter', (tester) async {
      final controller = StreamController<int>();
      final values = <int>[];
      final errors = <Object>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useStreamSubscription(
            controller.stream,
            (value) {
              values.add(value);
            },
            onError: (error, stackTrace) {
              errors.add(error);
            },
            cancelOnError: true,
          );
          return () => Text('Values: ${values.length}');
        }),
      ));

      // Add data
      controller.add(1);
      await tester.pumpAndSettle();
      expect(values, contains(1));

      // Add error - should cancel subscription
      final error = Exception('Test error');
      controller.addError(error);
      await tester.pumpAndSettle();
      expect(errors, contains(error));

      // Try to add more data - should not be received
      final countBefore = values.length;
      controller.add(2);
      await tester.pumpAndSettle();
      expect(values.length, countBefore);

      controller.close();
    });
  });
}
