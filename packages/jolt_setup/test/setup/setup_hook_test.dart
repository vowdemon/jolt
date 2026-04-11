import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/jolt_setup.dart';
import '../shared/helper.dart';

/// A test hook that tracks all lifecycle method calls
class _TestLifecycleHook extends SetupHook<String> {
  _TestLifecycleHook(this.tracker);

  final _LifecycleTracker tracker;

  @override
  String build() => 'initial';

  @override
  void mount() {
    tracker.mountCount++;
    tracker.mountOrder.add('mount');
  }

  @override
  void unmount() {
    tracker.unmountCount++;
    tracker.unmountOrder.add('unmount');
  }

  @override
  void didUpdateWidget(dynamic oldWidget, dynamic newWidget) {
    tracker.updateCount++;
    tracker.updateOrder.add('update');
  }

  @override
  void reassemble(SetupHook newHook) {
    tracker.reassembleCount++;
    tracker.reassembleOrder.add('reassemble');
  }

  @override
  void didChangeDependencies() {
    tracker.dependenciesChangeCount++;
    tracker.dependenciesChangeOrder.add('dependenciesChange');
  }

  @override
  void activate() {
    tracker.activatedCount++;
    tracker.activatedOrder.add('activated');
  }

  @override
  void deactivate() {
    tracker.deactivatedCount++;
    tracker.deactivatedOrder.add('deactivated');
  }
}

/// Tracks lifecycle method calls for testing
class _LifecycleTracker {
  int mountCount = 0;
  int unmountCount = 0;
  int updateCount = 0;
  int reassembleCount = 0;
  int dependenciesChangeCount = 0;
  int activatedCount = 0;
  int deactivatedCount = 0;

  final List<String> mountOrder = [];
  final List<String> unmountOrder = [];
  final List<String> updateOrder = [];
  final List<String> reassembleOrder = [];
  final List<String> dependenciesChangeOrder = [];
  final List<String> activatedOrder = [];
  final List<String> deactivatedOrder = [];

  void reset() {
    mountCount = 0;
    unmountCount = 0;
    updateCount = 0;
    reassembleCount = 0;
    dependenciesChangeCount = 0;
    activatedCount = 0;
    deactivatedCount = 0;
    mountOrder.clear();
    unmountOrder.clear();
    updateOrder.clear();
    reassembleOrder.clear();
    dependenciesChangeOrder.clear();
    activatedOrder.clear();
    deactivatedOrder.clear();
  }
}

class _TrackedTokenHook extends SetupHook<Object> {
  _TrackedTokenHook(this.label, this.events);

  final String label;
  final List<String> events;

  @override
  Object build() => Object();

  @override
  void mount() {
    events.add('$label:mount');
  }

  @override
  void unmount() {
    events.add('$label:unmount');
  }

  @override
  void reassemble(covariant _TrackedTokenHook newHook) {
    events.add('$label:reassemble:${newHook.label}');
  }
}

class _NoopSetupHook extends SetupHook<int> {
  @override
  int build() => 1;
}

class _ReplacementTrackedTokenHook extends SetupHook<Object> {
  _ReplacementTrackedTokenHook(this.label, this.events);

  final String label;
  final List<String> events;

  @override
  Object build() => Object();

  @override
  void mount() {
    events.add('$label:mount');
  }

  @override
  void unmount() {
    events.add('$label:unmount');
  }

  @override
  void reassemble(covariant _ReplacementTrackedTokenHook newHook) {
    events.add('$label:reassemble:${newHook.label}');
  }
}

void main() {
  group('SetupHook Lifecycle', () {
    testWidgets('mount is called on first build', (tester) async {
      final tracker = _LifecycleTracker();

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestLifecycleHook(tracker));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.mountOrder, ['mount']);
      expect(tracker.unmountCount, 0);
      expect(tracker.updateCount, 0);
      expect(tracker.activatedCount, 0);
      expect(tracker.deactivatedCount, 0);
    });

    testWidgets('unmount is called when widget is removed', (tester) async {
      final tracker = _LifecycleTracker();

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestLifecycleHook(tracker));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.unmountCount, 0);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.unmountCount, 1);
      expect(tracker.unmountOrder, ['unmount']);
    });

    testWidgets('update is called when widget is updated', (tester) async {
      final tracker = _LifecycleTracker();

      Widget buildWidget(String title) => MaterialApp(
            home: SetupBuilder(setup: (context) {
              useHook(_TestLifecycleHook(tracker));
              return () => Text(title);
            }),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.updateCount, 0);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.updateCount, 1);
      expect(tracker.updateOrder, ['update']);
    });

    testWidgets('dependenciesChange is called when dependencies change',
        (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        _TestInherited.of(context);
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 1,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.dependenciesChangeCount, 0);

      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 2,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.dependenciesChangeCount, 1);
      expect(tracker.dependenciesChangeOrder, ['dependenciesChange']);
    });

    testWidgets('activated is called when widget is activated', (tester) async {
      final tracker = _LifecycleTracker();
      final key = GlobalKey();
      var placeInFirstSlot = true;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                useHook(_TestLifecycleHook(tracker));
                return () => const Text('Test');
              },
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.activatedCount, 0);

      placeInFirstSlot = false;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker.activatedCount, 1);
      expect(tracker.activatedOrder, ['activated']);
    });

    testWidgets('deactivated is called when widget is deactivated',
        (tester) async {
      final tracker = _LifecycleTracker();
      final key = GlobalKey();
      var placeInFirstSlot = true;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                useHook(_TestLifecycleHook(tracker));
                return () => const Text('Test');
              },
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.deactivatedCount, 0);

      placeInFirstSlot = false;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker.deactivatedCount, 1);
      expect(tracker.deactivatedOrder, ['deactivated']);
    });

    testWidgets('activated and deactivated can be called multiple times',
        (tester) async {
      final tracker = _LifecycleTracker();
      final key = GlobalKey();
      var placeInFirstSlot = true;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                useHook(_TestLifecycleHook(tracker));
                return () => const Text('Test');
              },
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      for (final nextPosition in [false, true]) {
        placeInFirstSlot = nextPosition;
        await tester.pumpWidget(buildHost());
        await tester.pumpAndSettle();
      }

      for (final nextPosition in [false, true]) {
        placeInFirstSlot = nextPosition;
        await tester.pumpWidget(buildHost());
        await tester.pumpAndSettle();
      }

      expect(tracker.activatedCount, 4);
      expect(tracker.deactivatedCount, 4);
      expect(
        tracker.activatedOrder,
        ['activated', 'activated', 'activated', 'activated'],
      );
      expect(
        tracker.deactivatedOrder,
        ['deactivated', 'deactivated', 'deactivated', 'deactivated'],
      );
    });

    testWidgets('all lifecycle methods are called in correct order',
        (tester) async {
      final tracker = _LifecycleTracker();
      final key = GlobalKey();
      var placeInFirstSlot = true;
      var inheritedValue = 1;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                _TestInherited.of(context);
                useHook(_TestLifecycleHook(tracker));
                return () => const Text('Test');
              },
            ),
            wrapHome: (child) => _TestInherited(
              value: inheritedValue,
              child: child,
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      inheritedValue = 2;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      placeInFirstSlot = false;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tracker.mountOrder, ['mount']);
      expect(
        tracker.dependenciesChangeOrder,
        ['dependenciesChange', 'dependenciesChange'],
      );
      expect(tracker.deactivatedOrder, ['deactivated', 'deactivated']);
      expect(tracker.activatedOrder, ['activated']);
      expect(tracker.unmountOrder, ['unmount']);
    });

    testWidgets('multiple hooks are called in order', (tester) async {
      final tracker1 = _LifecycleTracker();
      final tracker2 = _LifecycleTracker();
      final tracker3 = _LifecycleTracker();
      final key = GlobalKey();
      var placeInFirstSlot = true;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                useHook(_TestLifecycleHook(tracker1));
                useHook(_TestLifecycleHook(tracker2));
                useHook(_TestLifecycleHook(tracker3));
                return () => const Text('Test');
              },
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker1.mountCount, 1);
      expect(tracker2.mountCount, 1);
      expect(tracker3.mountCount, 1);

      placeInFirstSlot = false;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(tracker1.activatedCount, 1);
      expect(tracker2.activatedCount, 1);
      expect(tracker3.activatedCount, 1);
      expect(tracker1.deactivatedCount, 1);
      expect(tracker2.deactivatedCount, 1);
      expect(tracker3.deactivatedCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tracker1.unmountCount, 1);
      expect(tracker2.unmountCount, 1);
      expect(tracker3.unmountCount, 1);
    });

    testWidgets('hook state persists across rebuilds', (tester) async {
      final tracker = _LifecycleTracker();
      String? capturedState;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final hook = useHook(_TestLifecycleHook(tracker));
          capturedState = hook;
          return () => Text('State: $hook');
        }),
      ));
      await tester.pumpAndSettle();

      final firstState = capturedState;

      // Rebuild
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final hook = useHook(_TestLifecycleHook(tracker));
          capturedState = hook;
          return () => Text('State: $hook');
        }),
      ));
      await tester.pumpAndSettle();

      // State should be the same (hook is reused)
      expect(capturedState, firstState);
      expect(tracker.mountCount, 1); // Only mounted once
      expect(tracker.updateCount, 1); // Updated once
    });

    testWidgets('hook context is available', (tester) async {
      BuildContext? capturedContext;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestContextHook((ctx) {
            capturedContext = ctx;
          }));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(capturedContext, isNotNull);
      expect(capturedContext, isA<BuildContext>());
    });

    testWidgets('default lifecycle methods are safe no-ops', (tester) async {
      final key = GlobalKey();
      var placeInFirstSlot = true;
      var inheritedValue = 1;

      Widget buildHost() => buildReparentableHost(
            key: key,
            placeInFirstSlot: placeInFirstSlot,
            buildTarget: (key) => SetupBuilder(
              key: key,
              setup: (context) {
                _TestInherited.of(context);
                useHook(_NoopSetupHook());
                return () => const Text('Test');
              },
            ),
            wrapHome: (child) => _TestInherited(
              value: inheritedValue,
              child: child,
            ),
          );

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      inheritedValue = 2;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      placeInFirstSlot = false;
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      tester.binding.reassembleApplication();
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

  });

  group('SetupHook Hot Reload with SetupWidget', () {
    testWidgets(
        'matching hook type is reused and receives new configuration in reassemble',
        (tester) async {
      final events = <String>[];
      Object? stableTokenBefore;
      Object? stableTokenAfter;
      var stableLabel = 'stable-v1';

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final stableToken = useHook(_TrackedTokenHook(stableLabel, events));
          stableTokenBefore ??= stableToken;
          stableTokenAfter = stableToken;

          final capturedLabel = stableLabel;
          return () => Text('Label: $capturedLabel');
        }),
      ));
      await tester.pumpAndSettle();

      expect(events, equals(['stable-v1:mount']));
      expect(find.text('Label: stable-v1'), findsOneWidget);

      stableLabel = 'stable-v2';

      tester.binding.reassembleApplication();
      await tester.pump();

      expect(
        events,
        equals([
          'stable-v1:mount',
          'stable-v1:reassemble:stable-v2',
        ]),
      );
      expect(identical(stableTokenBefore, stableTokenAfter), isTrue);
      expect(find.text('Label: stable-v2'), findsOneWidget);
    });

    testWidgets(
        'branch change unmounts replaced hook, reassembles reused hook, and mounts new hook',
        (tester) async {
      final events = <String>[];
      Object? headTokenBefore;
      Object? headTokenAfter;
      var headLabel = 'head-v1';
      var useReplacementTail = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final headToken = useHook(_TrackedTokenHook(headLabel, events));
          headTokenBefore ??= headToken;
          headTokenAfter = headToken;

          if (useReplacementTail) {
            useHook(_ReplacementTrackedTokenHook('tail-v2', events));
          } else {
            useHook(_TrackedTokenHook('tail-v1', events));
          }

          final capturedHeadLabel = headLabel;
          final capturedUseReplacementTail = useReplacementTail;
          return () => Text(
                'Head: $capturedHeadLabel, Replacement: $capturedUseReplacementTail',
              );
        }),
      ));
      await tester.pumpAndSettle();

      expect(events, equals(['head-v1:mount', 'tail-v1:mount']));
      expect(find.text('Head: head-v1, Replacement: false'), findsOneWidget);

      headLabel = 'head-v2';
      useReplacementTail = true;

      tester.binding.reassembleApplication();
      await tester.pump();

      expect(
        events,
        equals([
          'head-v1:mount',
          'tail-v1:mount',
          'tail-v1:unmount',
          'head-v1:reassemble:head-v2',
          'tail-v2:mount',
        ]),
      );
      expect(identical(headTokenBefore, headTokenAfter), isTrue);
      expect(find.text('Head: head-v2, Replacement: true'), findsOneWidget);
    });

    testWidgets(
        'removing trailing hooks during hot reload unmounts the old tail after prefix reuse',
        (tester) async {
      final events = <String>[];
      var headLabel = 'head-v1';
      var keepTail = true;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TrackedTokenHook(headLabel, events));
          if (keepTail) {
            useHook(_TrackedTokenHook('tail-v1', events));
          }

          final capturedHeadLabel = headLabel;
          final capturedKeepTail = keepTail;
          return () =>
              Text('Head: $capturedHeadLabel, Tail: $capturedKeepTail');
        }),
      ));
      await tester.pumpAndSettle();

      expect(events, equals(['head-v1:mount', 'tail-v1:mount']));

      headLabel = 'head-v2';
      keepTail = false;

      tester.binding.reassembleApplication();
      await tester.pump();

      expect(
        events,
        equals([
          'head-v1:mount',
          'tail-v1:mount',
          'tail-v1:unmount',
          'head-v1:reassemble:head-v2',
        ]),
      );
      expect(find.text('Head: head-v2, Tail: false'), findsOneWidget);
    });
  });

  group('SetupHook Hot Reload with SetupMixin', () {
    testWidgets(
        'matching hook type is reused and receives new configuration in reassemble',
        (tester) async {
      final events = <String>[];
      Object? stableTokenBefore;
      Object? stableTokenAfter;
      var stableLabel = 'stable-v1';

      await tester.pumpWidget(MaterialApp(
        home: _HookTestStatefulWidget(setup: (context, props) {
          final stableToken = useHook(_TrackedTokenHook(stableLabel, events));
          stableTokenBefore ??= stableToken;
          stableTokenAfter = stableToken;

          final capturedLabel = stableLabel;
          return () => Text('Label: $capturedLabel');
        }),
      ));
      await tester.pumpAndSettle();

      expect(events, equals(['stable-v1:mount']));
      expect(find.text('Label: stable-v1'), findsOneWidget);

      stableLabel = 'stable-v2';

      tester.binding.reassembleApplication();
      await tester.pump();

      expect(
        events,
        equals([
          'stable-v1:mount',
          'stable-v1:reassemble:stable-v2',
        ]),
      );
      expect(identical(stableTokenBefore, stableTokenAfter), isTrue);
      expect(find.text('Label: stable-v2'), findsOneWidget);
    });

    testWidgets(
        'branch change unmounts replaced hook, reassembles reused hook, and mounts new hook',
        (tester) async {
      final events = <String>[];
      Object? headTokenBefore;
      Object? headTokenAfter;
      var headLabel = 'head-v1';
      var useReplacementTail = false;

      await tester.pumpWidget(MaterialApp(
        home: _HookTestStatefulWidget(setup: (context, props) {
          final headToken = useHook(_TrackedTokenHook(headLabel, events));
          headTokenBefore ??= headToken;
          headTokenAfter = headToken;

          if (useReplacementTail) {
            useHook(_ReplacementTrackedTokenHook('tail-v2', events));
          } else {
            useHook(_TrackedTokenHook('tail-v1', events));
          }

          final capturedHeadLabel = headLabel;
          final capturedUseReplacementTail = useReplacementTail;
          return () => Text(
                'Head: $capturedHeadLabel, Replacement: $capturedUseReplacementTail',
              );
        }),
      ));
      await tester.pumpAndSettle();

      expect(events, equals(['head-v1:mount', 'tail-v1:mount']));
      expect(find.text('Head: head-v1, Replacement: false'), findsOneWidget);

      headLabel = 'head-v2';
      useReplacementTail = true;

      tester.binding.reassembleApplication();
      await tester.pump();

      expect(
        events,
        equals([
          'head-v1:mount',
          'tail-v1:mount',
          'tail-v1:unmount',
          'head-v1:reassemble:head-v2',
          'tail-v2:mount',
        ]),
      );
      expect(identical(headTokenBefore, headTokenAfter), isTrue);
      expect(find.text('Head: head-v2, Replacement: true'), findsOneWidget);
    });
  });

  group('Extension onDidUpdateWidget', () {
    testWidgets('JoltSetupOnDidUpdateWidget extension works on SetupWidget',
        (tester) async {
      int updateCount = 0;
      _TestSetupWidget? oldWidget;
      _TestSetupWidget? newWidget;

      Widget buildWidget(String title) => MaterialApp(
            home: _TestSetupWidget(
              title: title,
              onUpdate: (old, new_) {
                updateCount++;
                oldWidget = old;
                newWidget = new_;
              },
            ),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();
      expect(updateCount, 0);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();
      expect(updateCount, 1);
      expect(oldWidget, isNotNull);
      expect(newWidget, isNotNull);
      expect(oldWidget?.title, 'Initial');
      expect(newWidget?.title, 'Updated');
    });

    testWidgets('JoltSetupMixinOnDidUpdateWidget extension works on SetupMixin',
        (tester) async {
      int updateCount = 0;
      _TestStatefulWidgetForExtension? oldWidget;
      _TestStatefulWidgetForExtension? newWidget;

      Widget buildWidget(String title) => MaterialApp(
            home: _TestStatefulWidgetForExtension(
              title: title,
              onUpdate: (old, new_) {
                updateCount++;
                oldWidget = old;
                newWidget = new_;
              },
            ),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();
      expect(updateCount, 0);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();
      expect(updateCount, 1);
      expect(oldWidget, isNotNull);
      expect(newWidget, isNotNull);
      expect(oldWidget?.title, 'Initial');
      expect(newWidget?.title, 'Updated');
    });
  });
}

/// Test widget for SetupWidget extension test
class _TestSetupWidget extends SetupWidget<_TestSetupWidget> {
  final String title;
  final void Function(_TestSetupWidget, _TestSetupWidget) onUpdate;

  const _TestSetupWidget({
    required this.title,
    required this.onUpdate,
  });

  @override
  setup(context, props) {
    // Use extension method on SetupWidget
    onDidUpdateWidget(onUpdate);
    return () => Text(props().title);
  }
}

/// Test widget for SetupMixin extension test
class _TestStatefulWidgetForExtension extends StatefulWidget {
  final String title;
  final void Function(
          _TestStatefulWidgetForExtension, _TestStatefulWidgetForExtension)
      onUpdate;

  const _TestStatefulWidgetForExtension({
    required this.title,
    required this.onUpdate,
  });

  @override
  State<_TestStatefulWidgetForExtension> createState() =>
      _TestStatefulWidgetForExtensionState();
}

class _HookTestStatefulWidget extends StatefulWidget {
  final WidgetFunction<_HookTestStatefulWidget> Function(
      BuildContext, _HookTestStatefulWidget) setup;

  const _HookTestStatefulWidget({required this.setup});

  @override
  State<_HookTestStatefulWidget> createState() => _HookTestStatefulWidgetState();
}

class _HookTestStatefulWidgetState extends State<_HookTestStatefulWidget>
    with SetupMixin<_HookTestStatefulWidget> {
  @override
  setup(context) => widget.setup(context, props);
}

class _TestStatefulWidgetForExtensionState
    extends State<_TestStatefulWidgetForExtension>
    with SetupMixin<_TestStatefulWidgetForExtension> {
  @override
  setup(context) {
    // Use extension method on SetupMixin
    onDidUpdateWidget(widget.onUpdate);
    return () => Text(props.title);
  }
}

/// A test hook that captures context
class _TestContextHook extends SetupHook<String> {
  _TestContextHook(this.onContext);

  final void Function(BuildContext) onContext;

  @override
  String build() {
    onContext(context);
    return 'test';
  }
}

/// Helper InheritedWidget for testing dependencies change
class _TestInherited extends InheritedWidget {
  final int value;

  const _TestInherited({
    required this.value,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _TestInherited oldWidget) {
    return oldWidget.value != value;
  }

  static _TestInherited of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TestInherited>()!;
  }
}
