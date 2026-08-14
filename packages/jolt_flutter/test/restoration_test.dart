import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/core.dart' show RawNodeProvider, SignalNode;
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  testWidgets('restores a bound signal after state restart', (tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _RestorableCounter(),
        ),
      ),
    );

    final firstState = tester.state<_RestorableCounterState>(
      find.byType(_RestorableCounter),
    );
    firstState.count.value = 42;
    firstState.text.value = 'hello';
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);

    await tester.restartAndRestore();

    final restoredState = tester.state<_RestorableCounterState>(
      find.byType(_RestorableCounter),
    );
    expect(restoredState, isNot(same(firstState)));
    expect(restoredState.count.value, 42);
    expect(restoredState.text.value, 'hello');
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('restores a writable computed after state restart',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'app',
        home: _RestorableWritableComputed(),
      ),
    );

    final first = tester.state<_RestorableWritableComputedState>(
      find.byType(_RestorableWritableComputed),
    );
    first.value.value = 42;
    await tester.pumpAndSettle();

    await tester.restartAndRestore();

    final restored = tester.state<_RestorableWritableComputedState>(
      find.byType(_RestorableWritableComputed),
    );
    expect(restored, isNot(same(first)));
    expect(restored.source.value, 42);
    expect(restored.value.value, 42);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('restores a ValueNotifier signal bridge', (tester) async {
    final notifier = ValueNotifier(0);
    final signal = notifier.toNotifierSignal();
    addTearDown(() {
      signal.dispose();
      notifier.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: _ExternallyOwnedRestorableSignal(signal),
      ),
    );

    signal.value = 42;
    await tester.pump();
    final data = await tester.getRestorationData();

    signal.value = 7;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(notifier.value, 42);
    expect(signal.value, 42);
  });

  testWidgets('re-registers a signal when Flutter replaces the bucket',
      (tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _RestorableCounter(),
        ),
      ),
    );

    final state = tester.state<_RestorableCounterState>(
      find.byType(_RestorableCounter),
    );
    state.count.value = 10;
    await tester.pump();
    final data = await tester.getRestorationData();

    state.count.value = 20;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(
      tester.state<_RestorableCounterState>(find.byType(_RestorableCounter)),
      same(state),
    );
    expect(state.count.value, 10);
  });

  testWidgets('saves in-place ListSignal mutations', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'app',
        home: _RestorableList(),
      ),
    );

    tester
        .state<_RestorableListState>(find.byType(_RestorableList))
        .items
        .add(2);
    await tester.pumpAndSettle();

    await tester.restartAndRestore();

    final restored = tester.state<_RestorableListState>(
      find.byType(_RestorableList),
    );
    expect(restored.items, [1, 2]);
    expect(find.text('1,2'), findsOneWidget);
  });

  testWidgets('uses custom codecs for non-primitive values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'app',
        home: _RestorableDate(),
      ),
    );

    final first = tester.state<_RestorableDateState>(
      find.byType(_RestorableDate),
    );
    first.date.value = DateTime.utc(2030, 5, 6);
    await tester.pump();

    await tester.restartAndRestore();

    final restored = tester.state<_RestorableDateState>(
      find.byType(_RestorableDate),
    );
    expect(restored.date.value, DateTime.utc(2030, 5, 6));
  });

  test('rejects a second restoration property for the same node', () {
    final value = Signal(0);
    final alias = _SignalAlias(
      (value as RawNodeProvider).raw as SignalNode<int>,
    );
    final property = value.toRestorationProperty();
    addTearDown(() {
      property.dispose();
      value.dispose();
    });

    expect(
      alias.toRestorationProperty,
      throwsA(
        isA<FlutterError>().having(
          (error) => error.toString(),
          'message',
          contains('only one active restoration property'),
        ),
      ),
    );
  });

  test('disposing a restoration property releases the signal node', () {
    final value = Signal(0);
    final first = value.toRestorationProperty();
    first.dispose();

    final second = value.toRestorationProperty();
    second.dispose();
    value.dispose();
  });

  testWidgets('disposing State releases its writable node for rebinding',
      (tester) async {
    final value = Signal(0);
    late StateSetter updateHost;
    var showState = true;
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return showState
                ? _ExternallyOwnedRestorableSignal(value)
                : const SizedBox();
          },
        ),
      ),
    );

    final first = tester.state<_ExternallyOwnedRestorableSignalState>(
      find.byType(_ExternallyOwnedRestorableSignal),
    );
    updateHost(() => showState = false);
    await tester.pump();
    updateHost(() => showState = true);
    await tester.pump();

    final second = tester.state<_ExternallyOwnedRestorableSignalState>(
      find.byType(_ExternallyOwnedRestorableSignal),
    );
    expect(second, isNot(same(first)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hands an external writable to the replacement restoration owner',
      (tester) async {
    final value = Signal(0);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _BucketKeyedRestorationOwner(value),
        ),
      ),
    );

    value.value = 7;
    await tester.pump();
    final firstOwner = tester.state<_ExternallyOwnedRestorableSignalState>(
      find.byType(_ExternallyOwnedRestorableSignal),
    );
    final data = await tester.getRestorationData();

    value.value = 9;
    await tester.pump();
    await tester.restoreFrom(data);

    final secondOwner = tester.state<_ExternallyOwnedRestorableSignalState>(
      find.byType(_ExternallyOwnedRestorableSignal),
    );
    expect(secondOwner, isNot(same(firstOwner)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports a replacement handoff whose old owner survives',
      (tester) async {
    final value = Signal(0);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _PersistentRestorationOwners(value),
        ),
      ),
    );
    final data = await tester.getRestorationData();

    await tester.restoreFrom(data);

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(
      error.toString(),
      contains('previous writable restoration owner was not disposed'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _RestorableCounter extends StatefulWidget {
  const _RestorableCounter();

  @override
  State<_RestorableCounter> createState() => _RestorableCounterState();
}

class _RestorableCounterState extends State<_RestorableCounter>
    with RestorationMixin<_RestorableCounter> {
  final count = Signal(0);
  final text = RestorableString('');
  late final countRestoration = count.toRestorationProperty();

  @override
  String? get restorationId => 'counter';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(countRestoration, 'count');
    registerForRestoration(text, 'text');
  }

  @override
  Widget build(BuildContext context) => JoltBuilder(
        builder: (context) => Text('${count.value}'),
      );

  @override
  void dispose() {
    countRestoration.dispose();
    text.dispose();
    count.dispose();
    super.dispose();
  }
}

class _ExternallyOwnedRestorableSignal extends StatefulWidget {
  const _ExternallyOwnedRestorableSignal(
    this.value, {
    super.key,
    this.scopeId = 'external',
  });

  final Signal<int> value;
  final String scopeId;

  @override
  State<_ExternallyOwnedRestorableSignal> createState() =>
      _ExternallyOwnedRestorableSignalState();
}

class _BucketKeyedRestorationOwner extends StatefulWidget {
  const _BucketKeyedRestorationOwner(this.value);

  final Signal<int> value;

  @override
  State<_BucketKeyedRestorationOwner> createState() =>
      _BucketKeyedRestorationOwnerState();
}

class _BucketKeyedRestorationOwnerState
    extends State<_BucketKeyedRestorationOwner>
    with RestorationMixin<_BucketKeyedRestorationOwner> {
  @override
  String? get restorationId => 'bucket_keyed_owner';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {}

  @override
  Widget build(BuildContext context) {
    return UnmanagedRestorationScope(
      bucket: bucket,
      child: _ExternallyOwnedRestorableSignal(
        widget.value,
        key: ObjectKey(bucket),
      ),
    );
  }
}

class _PersistentRestorationOwners extends StatefulWidget {
  const _PersistentRestorationOwners(this.value);

  final Signal<int> value;

  @override
  State<_PersistentRestorationOwners> createState() =>
      _PersistentRestorationOwnersState();
}

class _PersistentRestorationOwnersState
    extends State<_PersistentRestorationOwners>
    with RestorationMixin<_PersistentRestorationOwners> {
  RestorationBucket? _firstBucket;

  @override
  String? get restorationId => 'persistent_owners';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {}

  @override
  Widget build(BuildContext context) {
    _firstBucket ??= bucket;
    final wasReplaced = !identical(_firstBucket, bucket);
    return UnmanagedRestorationScope(
      bucket: bucket,
      child: Column(
        children: [
          _ExternallyOwnedRestorableSignal(
            widget.value,
            key: const ValueKey('first'),
            scopeId: 'first',
          ),
          if (wasReplaced)
            _ExternallyOwnedRestorableSignal(
              widget.value,
              key: const ValueKey('second'),
              scopeId: 'second',
            ),
        ],
      ),
    );
  }
}

class _ExternallyOwnedRestorableSignalState
    extends State<_ExternallyOwnedRestorableSignal>
    with RestorationMixin<_ExternallyOwnedRestorableSignal> {
  late final WritableRestorationProperty<int> restoration;

  @override
  void initState() {
    super.initState();
    restoration = widget.value.toRestorationProperty();
  }

  @override
  String? get restorationId => widget.scopeId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(restoration, 'value');
  }

  @override
  Widget build(BuildContext context) => Text('${widget.value.value}');

  @override
  void dispose() {
    restoration.dispose();
    super.dispose();
  }
}

class _RestorableList extends StatefulWidget {
  const _RestorableList();

  @override
  State<_RestorableList> createState() => _RestorableListState();
}

class _RestorableWritableComputed extends StatefulWidget {
  const _RestorableWritableComputed();

  @override
  State<_RestorableWritableComputed> createState() =>
      _RestorableWritableComputedState();
}

class _RestorableWritableComputedState
    extends State<_RestorableWritableComputed>
    with RestorationMixin<_RestorableWritableComputed> {
  final source = Signal(0);
  late final value = WritableComputed<int>(
    () => source.value,
    (value) => source.value = value,
  );
  late final valueRestoration = value.toRestorationProperty();

  @override
  String? get restorationId => 'writable_computed';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(valueRestoration, 'value');
  }

  @override
  Widget build(BuildContext context) => JoltBuilder(
        builder: (context) => Text('${value.value}'),
      );

  @override
  void dispose() {
    valueRestoration.dispose();
    value.dispose();
    source.dispose();
    super.dispose();
  }
}

class _RestorableListState extends State<_RestorableList>
    with RestorationMixin<_RestorableList> {
  final items = ListSignal<int>([1]);
  late final itemsRestoration = items.toRestorationProperty(
    encode: (value) => value,
    decode: (data) => List<int>.from(data! as List),
  );

  @override
  String? get restorationId => 'list';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(itemsRestoration, 'items');
  }

  @override
  Widget build(BuildContext context) => JoltBuilder(
        builder: (context) => Text(items.join(',')),
      );

  @override
  void dispose() {
    itemsRestoration.dispose();
    items.dispose();
    super.dispose();
  }
}

class _RestorableDate extends StatefulWidget {
  const _RestorableDate();

  @override
  State<_RestorableDate> createState() => _RestorableDateState();
}

class _RestorableDateState extends State<_RestorableDate>
    with RestorationMixin<_RestorableDate> {
  final date = Signal(DateTime.utc(2020));
  late final dateRestoration = date.toRestorationProperty(
    encode: (value) => value.millisecondsSinceEpoch,
    decode: (data) => DateTime.fromMillisecondsSinceEpoch(
      data! as int,
      isUtc: true,
    ),
  );

  @override
  String? get restorationId => 'date';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(dateRestoration, 'value');
  }

  @override
  Widget build(BuildContext context) => Text(date.value.toIso8601String());

  @override
  void dispose() {
    dateRestoration.dispose();
    date.dispose();
    super.dispose();
  }
}

final class _SignalAlias<T> implements Signal<T>, RawNodeProvider {
  const _SignalAlias(this.raw);

  @override
  final SignalNode<T> raw;

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  T get peek => raw.peek();

  @override
  T get value => raw.get();

  @override
  set value(T value) => raw.set(value);

  @override
  void notify() => raw.notify();

  @override
  void dispose() => raw.dispose();
}
