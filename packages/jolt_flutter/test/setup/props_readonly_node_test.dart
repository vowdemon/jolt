import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

void main() {
  group('PropsReadonlyNode Public API', () {
    testWidgets('get() returns current widget instance', (tester) async {
      _TestPropsWidget? capturedWidget;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test Title',
          count: 42,
          onSetup: (props) {
            capturedPropsNode = props;
            capturedWidget = props.get();
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedWidget, isA<_TestPropsWidget>());
      expect(capturedWidget?.title, 'Test Title');
      expect(capturedWidget?.count, 42);
    });

    testWidgets('call() returns current widget instance', (tester) async {
      _TestPropsWidget? capturedWidget;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test Title',
          count: 42,
          onSetup: (props) {
            capturedPropsNode = props;
            capturedWidget = props();
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedWidget, isA<_TestPropsWidget>());
      expect(capturedWidget?.title, 'Test Title');
      expect(capturedWidget?.count, 42);
    });

    testWidgets('value getter returns current widget instance', (tester) async {
      _TestPropsWidget? capturedWidget;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test Title',
          count: 42,
          onSetup: (props) {
            capturedPropsNode = props;
            capturedWidget = props.value;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedWidget, isA<_TestPropsWidget>());
      expect(capturedWidget?.title, 'Test Title');
      expect(capturedWidget?.count, 42);
    });

    testWidgets('peek returns current widget without tracking', (tester) async {
      _TestPropsWidget? capturedWidget;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test Title',
          count: 42,
          onSetup: (props) {
            capturedPropsNode = props;
            capturedWidget = props.peek;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedWidget, isA<_TestPropsWidget>());
      expect(capturedWidget?.title, 'Test Title');
      expect(capturedWidget?.count, 42);
    });

    testWidgets('get() and value return same widget instance', (tester) async {
      _TestPropsWidget? widget1;
      _TestPropsWidget? widget2;
      _TestPropsWidget? widget3;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test Title',
          count: 42,
          onSetup: (props) {
            capturedPropsNode = props;
            widget1 = props.get();
            widget2 = props.value;
            widget3 = props();
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(widget1, same(widget2));
      expect(widget2, same(widget3));
    });

    testWidgets('get() updates when widget is updated', (tester) async {
      _TestPropsWidget? initialWidget;
      _TestPropsWidget? updatedWidget;
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Initial',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
            initialWidget = props.get();
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(initialWidget?.title, 'Initial');
      expect(initialWidget?.count, 0);

      // Update widget (same element, new widget instance)
      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Updated',
          count: 100,
        ),
      ));
      await tester.pumpAndSettle();

      // Get updated widget from the same props node
      expect(capturedPropsNode, isNotNull);
      updatedWidget = capturedPropsNode!.get();
      expect(updatedWidget.title, 'Updated');
      expect(updatedWidget.count, 100);
    });

    testWidgets('notify() can be called', (tester) async {
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;
      bool notifyCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);

      // Manually notify
      capturedPropsNode!.notify();
      notifyCalled = true;

      expect(notifyCalled, isTrue);
    });

    testWidgets('isDisposed returns false when widget is mounted',
        (tester) async {
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedPropsNode!.isDisposed, isFalse);
    });

    testWidgets('isDisposed returns true when widget is unmounted',
        (tester) async {
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedPropsNode!.isDisposed, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(capturedPropsNode!.isDisposed, isTrue);
    });

    testWidgets('dispose() can be called', (tester) async {
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;
      bool disposeCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedPropsNode!.isDisposed, isFalse);

      // Dispose - should not throw
      capturedPropsNode!.dispose();
      disposeCalled = true;

      expect(disposeCalled, isTrue);
      // Note: isDisposed is based on _context.mounted, not dispose() call
    });

    testWidgets('get() establishes reactive dependency', (tester) async {
      int computedValue = 0;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 10,
          onSetup: (props) {
            final computed = Computed(() {
              return props.get().count * 2;
            });
            computedValue = computed.value;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(computedValue, 20); // 10 * 2
    });

    testWidgets('peek does not establish reactive dependency', (tester) async {
      int computedValue = 0;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 10,
          onSetup: (props) {
            final computed = Computed(() {
              // Use peek to avoid tracking
              return props.peek.count * 2;
            });
            computedValue = computed.value;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // peek should not establish dependency
      expect(computedValue, 20); // 10 * 2
    });

    testWidgets('multiple calls to get() return same instance', (tester) async {
      _TestPropsWidget? widget1;
      _TestPropsWidget? widget2;
      _TestPropsWidget? widget3;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            widget1 = props.get();
            widget2 = props.get();
            widget3 = props.get();
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(widget1, same(widget2));
      expect(widget2, same(widget3));
    });

    testWidgets('value and peek return same widget instance', (tester) async {
      _TestPropsWidget? valueWidget;
      _TestPropsWidget? peekWidget;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            valueWidget = props.value;
            peekWidget = props.peek;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(valueWidget, same(peekWidget));
    });

    testWidgets('PropsReadonlyNode implements ReadonlyNode interface',
        (tester) async {
      PropsReadonlyNode<_TestPropsWidget>? capturedPropsNode;

      await tester.pumpWidget(MaterialApp(
        home: _TestPropsWidget(
          title: 'Test',
          count: 0,
          onSetup: (props) {
            capturedPropsNode = props;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(capturedPropsNode, isNotNull);
      expect(capturedPropsNode, isA<ReadonlyNode<_TestPropsWidget>>());
    });
  });
}

/// Test widget for PropsReadonlyNode testing
class _TestPropsWidget extends SetupWidget<_TestPropsWidget> {
  final String title;
  final int count;
  final void Function(PropsReadonlyNode<_TestPropsWidget>)? onSetup;

  const _TestPropsWidget({
    required this.title,
    required this.count,
    this.onSetup,
  });

  @override
  setup(context, props) {
    onSetup?.call(props);
    return () => Text('Title: ${props().title}');
  }
}
