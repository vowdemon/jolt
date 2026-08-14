import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  testWidgets('binds and restores an ordinary RestorableProperty',
      (tester) async {
    RestorableString? title;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('form');
              title = restoration.bindProperty(
                RestorableString('draft'),
                id: 'title',
              );
              return () => restoration(() => Text(title!.value));
            },
          ),
        ),
      ),
    );

    expect(find.text('draft'), findsOneWidget);

    title!.value = 'saved';
    await tester.pump();
    expect(find.text('saved'), findsOneWidget);

    final first = title;
    await tester.restartAndRestore();

    expect(title, isNot(same(first)));
    expect(title!.value, 'saved');
    expect(find.text('saved'), findsOneWidget);
  });

  testWidgets('bindProperty reports a missing restoration host',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('form');
            restoration.bindProperty(RestorableInt(0), id: 'count');
            return () => const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(
      error.toString(),
      contains('built through restoration(() => ...)'),
    );
  });

  testWidgets('runtime property binding validates a missing host',
      (tester) async {
    late SetupRestoration restoration;

    await tester.pumpWidget(
      MaterialApp(
        home: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('form');
            return () => const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    restoration.bindProperty(RestorableInt(0), id: 'count');
    await tester.pump();

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('has no restoration host'));
  });

  testWidgets('onRestore runs after signals and properties are initialized',
      (tester) async {
    Signal<int>? signal;
    RestorableInt? property;
    final restores =
        <({bool initial, bool hasOld, int signal, int property})>[];

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('values');
              signal = useSignal(1);
              restoration.bind(signal!, id: 'signal');
              property = restoration.bindProperty(
                RestorableInt(2),
                id: 'property',
              );
              restoration.onRestore((oldBucket, initialRestore) {
                restores.add((
                  initial: initialRestore,
                  hasOld: oldBucket != null,
                  signal: signal!.value,
                  property: property!.value,
                ));
              });
              return () => restoration(
                    () => Text('${signal!.value}:${property!.value}'),
                  );
            },
          ),
        ),
      ),
    );

    expect(restores, [
      (initial: true, hasOld: false, signal: 1, property: 2),
    ]);

    signal!.value = 7;
    property!.value = 8;
    await tester.pump();
    await tester.restartAndRestore();

    expect(restores.last, (
      initial: true,
      hasOld: false,
      signal: 7,
      property: 8,
    ));
  });

  testWidgets('onRestore receives the old bucket on replacement',
      (tester) async {
    Signal<int>? signal;
    RestorableInt? property;
    final restores =
        <({bool initial, Object? oldSignal, int signal, int property})>[];

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('values');
              signal = useSignal(0);
              restoration.bind(signal!, id: 'signal');
              property = restoration.bindProperty(
                RestorableInt(0),
                id: 'property',
              );
              restoration.onRestore((oldBucket, initialRestore) {
                restores.add((
                  initial: initialRestore,
                  oldSignal: oldBucket?.read<Object?>('signal'),
                  signal: signal!.value,
                  property: property!.value,
                ));
              });
              return () => restoration(
                    () => Text('${signal!.value}:${property!.value}'),
                  );
            },
          ),
        ),
      ),
    );

    restores.clear();
    signal!.value = 10;
    property!.value = 11;
    await tester.pump();
    final data = await tester.getRestorationData();

    signal!.value = 20;
    property!.value = 21;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(restores, [
      (initial: false, oldSignal: 20, signal: 10, property: 11),
    ]);
  });

  testWidgets('bindProperty restores a RestorableTextEditingController',
      (tester) async {
    RestorableTextEditingController? input;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: Material(
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('form');
              input = restoration.bindProperty(
                RestorableTextEditingController(text: 'draft'),
                id: 'input',
              );
              return () => restoration(
                    () => TextField(controller: input!.value),
                  );
            },
          ),
        ),
      ),
    );

    input!.value.value = const TextEditingValue(
      text: 'saved',
      selection: TextSelection.collapsed(offset: 5),
    );
    await tester.pump();
    await tester.restartAndRestore();

    expect(input!.value.text, 'saved');
  });

  testWidgets('bindProperty restores a Listenable without owning it',
      (tester) async {
    _RestorableCounterListenable? counter;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('counter');
              counter = restoration.bindProperty(
                _RestorableCounterListenable(),
                id: 'value',
              );
              return () => restoration(
                    () => ListenableBuilder(
                      listenable: counter!.value,
                      builder: (context, child) {
                        return Text('${counter!.value.count}');
                      },
                    ),
                  );
            },
          ),
        ),
      ),
    );

    final firstProperty = counter!;
    final firstListenable = firstProperty.value;
    firstListenable.setCount(7);
    await tester.pump();
    expect(find.text('7'), findsOneWidget);

    await tester.restartAndRestore();

    expect(counter, isNot(same(firstProperty)));
    expect(counter!.value.count, 7);
    expect(firstListenable.isDisposed, isFalse);

    final restoredListenable = counter!.value;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(restoredListenable.isDisposed, isFalse);
    firstListenable.dispose();
    restoredListenable.dispose();
  });

  testWidgets(
      'restoration builder tracks signals and preserves the ancestor scope',
      (tester) async {
    Signal<int>? count;
    String? visibleScopeId;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('form');
              restoration.bindProperty(
                RestorableString('draft'),
                id: 'title',
              );
              count = useSignal(0);
              restoration.bind(count!, id: 'count');
              return () => restoration(() {
                    final value = count!.value;
                    return Builder(
                      builder: (context) {
                        visibleScopeId =
                            RestorationScope.maybeOf(context)?.restorationId;
                        return Text('$value');
                      },
                    );
                  });
            },
          ),
        ),
      ),
    );

    expect(visibleScopeId, 'app');
    expect(find.text('0'), findsOneWidget);

    count!.value = 7;
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('ordinary property restores when Flutter replaces its bucket',
      (tester) async {
    RestorableInt? count;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('counter');
              count = restoration.bindProperty(
                RestorableInt(0),
                id: 'count',
              );
              return () => restoration(() => Text('${count!.value}'));
            },
          ),
        ),
      ),
    );

    count!.value = 10;
    await tester.pump();
    final data = await tester.getRestorationData();
    final property = count;

    count!.value = 20;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(count, same(property));
    expect(count!.value, 10);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('hot reload retains declared restoration bindings',
      (tester) async {
    Signal<int>? count;
    RestorableInt? property;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            count = useSignal(0);
            restoration.bind(count!, id: 'signal');
            property = restoration.bindProperty(
              RestorableInt(0),
              id: 'property',
            );
            return () => restoration(
                  () => Text('${count!.value}:${property!.value}'),
                );
          },
        ),
      ),
    );

    count!.value = 7;
    property!.value = 8;
    await tester.pump();
    final firstSignal = count;
    final firstProperty = property;

    tester.binding.reassembleApplication();
    await tester.pump();

    expect(count, same(firstSignal));
    expect(property, same(firstProperty));
    expect(find.text('7:8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hot reload moves a writable between restoration IDs',
      (tester) async {
    Signal<int>? count;
    var id = 'old';

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            count = useSignal(0);
            restoration.bind(count!, id: id);
            return () => Text('${count!.value}');
          },
        ),
      ),
    );

    count!.value = 7;
    await tester.pump();
    final signal = count;

    id = 'new';
    tester.binding.reassembleApplication();
    await tester.pump();
    count!.value = 8;
    await tester.pump();

    id = 'old';
    tester.binding.reassembleApplication();
    await tester.pump();

    expect(count, same(signal));
    expect(count!.value, 8);
    await tester.restartAndRestore();
    expect(count!.value, 8);
  });

  testWidgets('hot reload removes omitted restoration bindings',
      (tester) async {
    Signal<int>? count;
    var bindCount = true;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            count = useSignal(0);
            if (bindCount) restoration.bind(count!, id: 'count');
            return () => Text('${count!.value}');
          },
        ),
      ),
    );

    count!.value = 9;
    await tester.pump();

    bindCount = false;
    tester.binding.reassembleApplication();
    await tester.pump();
    count!.value = 0;

    bindCount = true;
    tester.binding.reassembleApplication();
    await tester.pump();

    expect(count!.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hot reload disposes omitted RestorableProperties',
      (tester) async {
    _TrackingRestorableInt? property;
    var bindProperty = true;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            if (bindProperty) {
              property = restoration.bindProperty(
                _TrackingRestorableInt(0),
                id: 'count',
              );
            }
            return () => restoration(() => const SizedBox());
          },
        ),
      ),
    );

    final omitted = property!;
    bindProperty = false;
    tester.binding.reassembleApplication();
    await tester.pump();

    expect(omitted.isDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hot reload switches between property and writable',
      (tester) async {
    Signal<int>? count;
    _TrackingRestorableInt? property;
    var bindWritable = false;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            if (bindWritable) {
              count = useSignal(0);
              restoration.bind(count!, id: 'value');
            } else {
              property = restoration.bindProperty(
                _TrackingRestorableInt(0),
                id: 'value',
              );
            }
            return () => restoration(() => const SizedBox());
          },
        ),
      ),
    );
    final firstProperty = property!;

    bindWritable = true;
    tester.binding.reassembleApplication();
    await tester.pump();

    expect(count, isNotNull);
    expect(firstProperty.isDisposed, isTrue);
    expect(tester.takeException(), isNull);

    bindWritable = false;
    tester.binding.reassembleApplication();
    await tester.pump();

    expect(property, isNot(same(firstProperty)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary properties initialize without an ancestor bucket',
      (tester) async {
    RestorableString? title;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('form');
            title = restoration.bindProperty(
              RestorableString('draft'),
              id: 'title',
            );
            return () => restoration(() => Text(title!.value));
          },
        ),
      ),
    );

    expect(title!.value, 'draft');
    expect(find.text('draft'), findsOneWidget);
  });

  testWidgets('bindProperty supports runtime conditional registration',
      (tester) async {
    late SetupRestoration restoration;
    RestorableInt? count;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('counter');
            return () => restoration(
                  () => Text('${count?.value ?? -1}'),
                );
          },
        ),
      ),
    );

    count = restoration.bindProperty(RestorableInt(3), id: 'count');
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    count.value = 4;
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('runtime writable binding flushes without another frame',
      (tester) async {
    late SetupRestoration restoration;
    late Signal<int> count;
    var bindDuringSetup = false;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('counter');
            count = useSignal(bindDuringSetup ? 0 : 5);
            if (bindDuringSetup) restoration.bind(count, id: 'count');
            return () => Text('${count.value}');
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    restoration.bind(count, id: 'count');
    bindDuringSetup = true;
    await tester.restartAndRestore();

    expect(count.value, 5);
  });

  testWidgets('post-frame writable changes flush without another frame',
      (tester) async {
    late Signal<int> count;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            count = useSignal(0);
            restoration.bind(count, id: 'count');
            return () => const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.addPostFrameCallback((_) => count.value = 7);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.restartAndRestore();

    expect(count.value, 7);
  });

  testWidgets('property bindings support reactive build conditions',
      (tester) async {
    late Signal<bool> enabled;
    RestorableInt? count;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('counter');
            enabled = useSignal(false);
            restoration.bind(enabled, id: 'enabled');
            count = null;
            return () => restoration(() {
                  if (enabled.value) {
                    count ??= restoration.bindProperty(
                      RestorableInt(3),
                      id: 'count',
                    );
                  } else if (count != null) {
                    restoration.unbindProperty(count!);
                    count = null;
                  }
                  return Text('${count?.value ?? -1}');
                });
          },
        ),
      ),
    );

    expect(find.text('-1'), findsOneWidget);
    enabled.value = true;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);

    count!.value = 7;
    await tester.pump();
    await tester.restartAndRestore();

    expect(tester.takeException(), isNull);
    expect(enabled.value, isTrue);
    expect(count!.value, 7);
    expect(find.text('7'), findsOneWidget);

    enabled.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-1'), findsOneWidget);
  });

  testWidgets('rebinding an active writable does not reinitialize it',
      (tester) async {
    late SetupRestoration restoration;
    late Signal<int> count;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('counter');
            count = useSignal(0);
            restoration.bind(count, id: 'count');
            return () => Text('${count.value}');
          },
        ),
      ),
    );

    count.value = 5;
    restoration.bind(count, id: 'count');

    expect(count.value, 5);
  });

  testWidgets('signals and properties reject a shared restoration ID',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('form');
            restoration.bindProperty(RestorableInt(0), id: 'value');
            restoration.bind(useSignal(0), id: 'value');
            return () => restoration(() => const SizedBox());
          },
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('share one ID namespace'));
  });

  testWidgets('properties reject an ID already used by a signal',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupBuilder(
          setup: (context) {
            final restoration = useRestorationScope('form');
            restoration.bind(useSignal(0), id: 'value');
            restoration.bindProperty(RestorableInt(0), id: 'value');
            return () => const SizedBox();
          },
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('share one ID namespace'));
  });

  testWidgets('a setup rejects a second restoration scope', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupBuilder(
          setup: (context) {
            useRestorationScope('first');
            useRestorationScope('second');
            return () => const SizedBox();
          },
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('only one restoration scope'));
  });

  testWidgets('SetupBuilder restores a bound signal', (tester) async {
    Signal<int>? count;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('counter');
              count = useSignal(0);
              restoration.bind(count!, id: 'count');
              return () => Text('${count!.value}');
            },
          ),
        ),
      ),
    );

    count!.value = 12;
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);

    final first = count;
    await tester.restartAndRestore();

    expect(count, isNot(same(first)));
    expect(count!.value, 12);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('SetupBuilder restores a bound writable computed',
      (tester) async {
    Signal<int>? source;
    WritableComputed<int>? value;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('computed');
              source = useSignal(0);
              value = useComputed.writable(
                () => source!.value,
                (restored) => source!.value = restored,
              );
              restoration.bind(value!, id: 'value');
              return () => Text('${value!.value}');
            },
          ),
        ),
      ),
    );

    value!.value = 12;
    await tester.pumpAndSettle();

    await tester.restartAndRestore();

    expect(source!.value, 12);
    expect(value!.value, 12);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('restores before later immediate effects are created',
      (tester) async {
    Signal<int>? count;
    final effectValues = <int>[];

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('counter');
              count = useSignal(0);
              restoration.bind(count!, id: 'count');
              useEffect(() => effectValues.add(count!.value));
              return () => Text('${count!.value}');
            },
          ),
        ),
      ),
    );

    count!.value = 9;
    await tester.pump();
    effectValues.clear();

    await tester.restartAndRestore();

    expect(effectValues, [9]);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('SetupBuilder re-registers when Flutter replaces the bucket',
      (tester) async {
    Signal<int>? count;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('counter');
              count = useSignal(0);
              restoration.bind(count!, id: 'count');
              return () => Text('${count!.value}');
            },
          ),
        ),
      ),
    );

    count!.value = 10;
    await tester.pump();
    final data = await tester.getRestorationData();
    final signal = count;

    count!.value = 20;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(count, same(signal));
    expect(count!.value, 10);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('bucket replacement restores signals atomically', (tester) async {
    Signal<int>? first;
    Signal<int>? second;
    final observed = <(int, int)>[];

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              final restoration = useRestorationScope('values');
              first = useSignal(0);
              second = useSignal(0);
              restoration
                ..bind(first!, id: 'first')
                ..bind(second!, id: 'second');
              useEffect(() => observed.add((first!.value, second!.value)));
              return () => const SizedBox();
            },
          ),
        ),
      ),
    );

    batch(() {
      first!.value = 10;
      second!.value = 20;
    });
    await tester.pump();
    final data = await tester.getRestorationData();

    batch(() {
      first!.value = 30;
      second!.value = 40;
    });
    await tester.pump();
    observed.clear();
    await tester.restoreFrom(data);

    expect(observed, [(10, 20)]);
  });

  testWidgets('enabling an ancestor scope preserves the current signal value',
      (tester) async {
    Signal<int>? count;
    final child = SetupBuilder(
      setup: (context) {
        final restoration = useRestorationScope('counter');
        count = useSignal(0);
        restoration.bind(count!, id: 'count');
        return () => Text('${count!.value}');
      },
    );

    Widget app(String? parentId) => RootRestorationScope(
          restorationId: 'app',
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RestorationScope(
              restorationId: parentId,
              child: child,
            ),
          ),
        );

    await tester.pumpWidget(app(null));
    count!.value = 5;
    await tester.pump();
    final signal = count;

    await tester.pumpWidget(app('parent'));

    expect(count, same(signal));
    expect(count!.value, 5);
    await tester.restartAndRestore();
    expect(count!.value, 5);
  });

  testWidgets('disabling and re-enabling an ancestor scope preserves state',
      (tester) async {
    Signal<int>? count;
    final child = SetupBuilder(
      setup: (context) {
        final restoration = useRestorationScope('counter');
        count = useSignal(0);
        restoration.bind(count!, id: 'count');
        return () => Text('${count!.value}');
      },
    );

    Widget app(String? parentId) => RootRestorationScope(
          restorationId: 'app',
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RestorationScope(
              restorationId: parentId,
              child: child,
            ),
          ),
        );

    await tester.pumpWidget(app('parent'));
    count!.value = 5;
    await tester.pump();
    final signal = count;

    await tester.pumpWidget(app(null));
    count!.value = 7;
    await tester.pump();
    await tester.pumpWidget(app('parent'));

    expect(count, same(signal));
    expect(count!.value, 7);
    await tester.restartAndRestore();
    expect(count!.value, 7);
  });

  testWidgets('moving between ancestor scopes adopts the existing bucket',
      (tester) async {
    Signal<int>? count;
    final child = SetupBuilder(
      key: GlobalKey(),
      setup: (context) {
        final restoration = useRestorationScope('counter');
        count = useSignal(0);
        restoration.bind(count!, id: 'count');
        return () => Text('${count!.value}');
      },
    );
    var moveRight = false;

    Widget app() => RootRestorationScope(
          restorationId: 'app',
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                RestorationScope(
                  restorationId: 'left',
                  child: moveRight ? const SizedBox() : child,
                ),
                RestorationScope(
                  restorationId: 'right',
                  child: moveRight ? child : const SizedBox(),
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(app());
    count!.value = 9;
    await tester.pump();
    final signal = count;

    moveRight = true;
    await tester.pumpWidget(app());

    expect(count, same(signal));
    expect(count!.value, 9);
    await tester.restartAndRestore();
    expect(count!.value, 9);
  });

  testWidgets('restoration scope may follow unrelated hooks', (tester) async {
    Signal<int>? count;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SetupBuilder(
            setup: (context) {
              useSignal(0);
              final restoration = useRestorationScope('counter');
              count = useSignal(0);
              restoration.bind(count!, id: 'count');
              return () => Text('${count!.value}');
            },
          ),
        ),
      ),
    );

    count!.value = 6;
    await tester.pump();
    await tester.restartAndRestore();

    expect(count!.value, 6);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('explicit unbindProperty unregisters and disposes the property',
      (tester) async {
    _TrackingRestorableInt? count;
    SetupRestoration? restoration;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('counter');
            count = restoration!.bindProperty(
              _TrackingRestorableInt(0),
              id: 'count',
            );
            return () => restoration!(() => const SizedBox());
          },
        ),
      ),
    );

    count!.value = 9;
    await tester.pump();
    final removed = count!;

    restoration!.unbindProperty(removed);
    await tester.pump();

    expect(removed.isDisposed, isTrue);
    await tester.restartAndRestore();
    expect(count!.value, 0);
  });

  testWidgets('explicit unbind removes a signal restoration binding',
      (tester) async {
    Signal<int>? count;
    SetupRestoration? restoration;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: SetupBuilder(
          setup: (context) {
            restoration = useRestorationScope('counter');
            count = useSignal(0);
            restoration!.bind(count!, id: 'count');
            return () => const SizedBox();
          },
        ),
      ),
    );

    count!.value = 9;
    await tester.pump();
    restoration!.unbind(count!);
    await tester.pump();
    await tester.restartAndRestore();

    expect(count!.value, 0);
  });

  testWidgets('unmount releases the bucket for a new setup owner',
      (tester) async {
    Signal<int>? count;
    late StateSetter updateHost;
    var showSetup = true;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            if (!showSetup) return const SizedBox();
            return SetupBuilder(
              setup: (context) {
                final restoration = useRestorationScope('counter');
                count = useSignal(0);
                restoration.bind(count!, id: 'count');
                return () => Text('${count!.value}');
              },
            );
          },
        ),
      ),
    );

    count!.value = 4;
    await tester.pump();
    final first = count;

    updateHost(() => showSetup = false);
    await tester.pump();
    updateHost(() => showSetup = true);
    await tester.pump();

    expect(count, isNot(same(first)));
    expect(count!.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount disposes properties before a new setup owner',
      (tester) async {
    _TrackingRestorableInt? count;
    late StateSetter updateHost;
    var showSetup = true;

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            if (!showSetup) return const SizedBox();
            return SetupBuilder(
              setup: (context) {
                final restoration = useRestorationScope('counter');
                count = restoration.bindProperty(
                  _TrackingRestorableInt(0),
                  id: 'count',
                );
                return () => restoration(() => Text('${count!.value}'));
              },
            );
          },
        ),
      ),
    );

    count!.value = 4;
    await tester.pump();
    final first = count!;

    updateHost(() => showSetup = false);
    await tester.pump();
    expect(first.isDisposed, isTrue);

    updateHost(() => showSetup = true);
    await tester.pump();

    expect(count, isNot(same(first)));
    expect(count!.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount releases the writable node for a new setup owner',
      (tester) async {
    final count = Signal(0);
    SetupRestoration? restoration;
    late StateSetter updateHost;
    var showSetup = true;
    addTearDown(count.dispose);

    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            if (!showSetup) return const SizedBox();
            return SetupBuilder(
              setup: (context) {
                restoration = useRestorationScope('counter');
                restoration!.bind(count, id: 'count');
                return () => Text('${count.value}');
              },
            );
          },
        ),
      ),
    );

    count.value = 4;
    await tester.pump();
    final firstOwner = restoration;

    updateHost(() => showSetup = false);
    await tester.pump();
    updateHost(() => showSetup = true);
    await tester.pump();

    expect(restoration, isNot(same(firstOwner)));
    expect(tester.takeException(), isNull);
    restoration!.unbind(count);
    restoration!.bind(count, id: 'count');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hands an external writable to the replacement setup owner',
      (tester) async {
    final count = Signal(0);
    addTearDown(count.dispose);

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _BucketKeyedSetupRestorationOwner(count),
        ),
      ),
    );

    count.value = 7;
    await tester.pump();
    final data = await tester.getRestorationData();

    count.value = 9;
    await tester.pump();
    await tester.restoreFrom(data);

    expect(count.value, 7);
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SetupMixin uses the same restoration scope hook',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'app',
        home: _SetupMixinRestoration(),
      ),
    );

    final first = tester.state<_SetupMixinRestorationState>(
      find.byType(_SetupMixinRestoration),
    );
    first.count!.value = 21;
    await tester.pumpAndSettle();

    await tester.restartAndRestore();

    final restored = tester.state<_SetupMixinRestorationState>(
      find.byType(_SetupMixinRestoration),
    );
    expect(restored, isNot(same(first)));
    expect(restored.count!.value, 21);
    expect(find.text('21'), findsOneWidget);
  });

  testWidgets('SetupWidget uses the same restoration scope hook',
      (tester) async {
    Signal<int>? count;

    await tester.pumpWidget(
      RootRestorationScope(
        restorationId: 'app',
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _SetupWidgetRestoration(onSignal: (value) => count = value),
        ),
      ),
    );

    count!.value = 34;
    await tester.pump();
    await tester.restartAndRestore();

    expect(count!.value, 34);
    expect(find.text('34'), findsOneWidget);
  });
}

class _SetupWidgetRestoration extends SetupWidget<_SetupWidgetRestoration> {
  const _SetupWidgetRestoration({required this.onSignal});

  final ValueChanged<Signal<int>> onSignal;

  @override
  WidgetFunction<_SetupWidgetRestoration> setup(
    BuildContext context,
    Props<_SetupWidgetRestoration> props,
  ) {
    final restoration = useRestorationScope('setup_widget');
    final count = useSignal(0);
    restoration.bind(count, id: 'count');
    onSignal(count);
    return () => Text('${count.value}');
  }
}

class _BucketKeyedSetupRestorationOwner extends StatefulWidget {
  const _BucketKeyedSetupRestorationOwner(this.count);

  final Signal<int> count;

  @override
  State<_BucketKeyedSetupRestorationOwner> createState() =>
      _BucketKeyedSetupRestorationOwnerState();
}

class _BucketKeyedSetupRestorationOwnerState
    extends State<_BucketKeyedSetupRestorationOwner>
    with RestorationMixin<_BucketKeyedSetupRestorationOwner> {
  @override
  String? get restorationId => 'bucket_keyed_setup_owner';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {}

  @override
  Widget build(BuildContext context) {
    return SetupBuilder(
      key: ObjectKey(bucket),
      setup: (context) {
        final restoration = useRestorationScope('counter');
        restoration.bind(widget.count, id: 'count');
        return () => Text('${widget.count.value}');
      },
    );
  }
}

class _SetupMixinRestoration extends StatefulWidget {
  const _SetupMixinRestoration();

  @override
  State<_SetupMixinRestoration> createState() => _SetupMixinRestorationState();
}

class _SetupMixinRestorationState extends State<_SetupMixinRestoration>
    with SetupMixin<_SetupMixinRestoration> {
  Signal<int>? count;

  @override
  WidgetFunction<_SetupMixinRestoration> setup(BuildContext context) {
    final restoration = useRestorationScope('setup_mixin');
    count = useSignal(0);
    restoration.bind(count!, id: 'count');
    return () => Text('${count!.value}');
  }
}

final class _TrackingRestorableInt extends RestorableInt {
  _TrackingRestorableInt(super.defaultValue);

  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

final class _CounterListenable extends ChangeNotifier {
  _CounterListenable(this.count);

  int count;
  bool isDisposed = false;

  void setCount(int value) {
    count = value;
    notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

final class _RestorableCounterListenable
    extends RestorableListenable<_CounterListenable> {
  @override
  _CounterListenable createDefaultValue() => _CounterListenable(0);

  @override
  _CounterListenable fromPrimitives(Object? data) {
    return _CounterListenable(data! as int);
  }

  @override
  Object? toPrimitives() => value.count;
}
