import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/single_computed_scene.dart';

void main() {
  group('Single Computed Tests', () {
    testWidgets('Computed Basic Feature - Simple Calculation', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);
      final doubleCounter = Computed(() => counter.value * 2);

      final widget = BasicComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
        computed: doubleCounter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter: 0, Double: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1, Double: 2'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 2, Double: 4'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Computed Basic Feature - String Operations', (tester) async {
      int rebuildCount = 0;
      final name = Signal('Alice');
      final greeting = Computed(() => 'Hello, ${name.value}!');

      final widget = StringComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        name: name,
        computed: greeting,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Name: Alice, Greeting: Hello, Alice!'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(find.text('Name: Bob, Greeting: Hello, Bob!'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Computed Basic Feature - Boolean Logic', (tester) async {
      int rebuildCount = 0;
      final isLoggedIn = Signal(false);
      final canAccess = Computed(() => isLoggedIn.value);

      final widget = BoolComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        isLoggedIn: isLoggedIn,
        computed: canAccess,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Logged In: false, Can Access: false'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('login')));
      await tester.pumpAndSettle();

      expect(find.text('Logged In: true, Can Access: true'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('logout')));
      await tester.pumpAndSettle();

      expect(find.text('Logged In: false, Can Access: false'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Computed Basic Feature - List Operations', (tester) async {
      int rebuildCount = 0;
      final numbers = Signal<List<int>>([1, 2, 3, 4, 5]);
      final sum =
          Computed(() => numbers.value.fold<int>(0, (sum, cur) => sum + cur));

      final widget = ListComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        numbers: numbers,
        computed: sum,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Numbers: [1, 2, 3, 4, 5], Sum: 15'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('add')));
      await tester.pumpAndSettle();

      expect(find.text('Numbers: [1, 2, 3, 4, 5, 6], Sum: 21'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('remove')));
      await tester.pumpAndSettle();

      expect(find.text('Numbers: [1, 2, 3, 4, 5], Sum: 15'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Computed Basic Feature - Object Properties', (tester) async {
      int rebuildCount = 0;
      final user = Signal(User(name: 'Alice', age: 25));
      final userInfo =
          Computed(() => '${user.value.name} is ${user.value.age} years old');

      final widget = ObjectComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        user: user,
        computed: userInfo,
      );

      await tester.pumpWidget(widget);

      expect(find.text('User: Alice, 25, Info: Alice is 25 years old'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(find.text('User: Bob, 30, Info: Bob is 30 years old'),
          findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Computed Basic Feature - Conditional Calculation',
        (tester) async {
      int rebuildCount = 0;
      final score = Signal(75);
      final grade = Computed(() {
        if (score.value >= 90) return 'A';
        if (score.value >= 80) return 'B';
        if (score.value >= 70) return 'C';
        if (score.value >= 60) return 'D';
        return 'F';
      });

      final widget = ConditionalComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        score: score,
        computed: grade,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Score: 75, Grade: C'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increase')));
      await tester.pumpAndSettle();

      expect(find.text('Score: 85, Grade: B'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increase')));
      await tester.pumpAndSettle();

      expect(find.text('Score: 95, Grade: A'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Computed Basic Feature - Caching Mechanism', (tester) async {
      int rebuildCount = 0;
      int computeCount = 0;
      final counter = Signal(0);
      final expensiveComputed = Computed(() {
        computeCount++;
        return counter.value * counter.value;
      });

      final widget = CachedComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
        computed: expensiveComputed,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter: 0, Square: 0'), findsOneWidget);
      expect(rebuildCount, 1);
      expect(computeCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1, Square: 1'), findsOneWidget);
      expect(rebuildCount, 2);
      expect(computeCount, 2);

      await tester.pumpAndSettle();
      expect(computeCount, 2);
    });

    testWidgets('Computed Basic Feature - Async Calculation', (tester) async {
      int rebuildCount = 0;
      final input = Signal('hello');
      final processed = Computed(() => input.value.toUpperCase());

      final widget = AsyncComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        input: input,
        computed: processed,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Input: hello, Processed: HELLO'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(find.text('Input: world, Processed: WORLD'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('WritableComputed Basic Feature', (tester) async {
      int rebuildCount = 0;
      final firstName = Signal('John');
      final lastName = Signal('Doe');
      final fullName = WritableComputed(
        () => '${firstName.value} ${lastName.value}',
        (value) {
          final parts = value.split(' ');
          if (parts.length >= 2) {
            batch(() {
              firstName.value = parts[0];
              lastName.value = parts.sublist(1).join(' ');
            });
          }
        },
      );

      final widget = WritableComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        firstName: firstName,
        lastName: lastName,
        computed: fullName,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text('First: John, Last: Doe, Full: John Doe'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('setFull')));
      await tester.pumpAndSettle();

      expect(find.text('First: Jane, Last: Smith, Full: Jane Smith'),
          findsOneWidget);
      expect(rebuildCount, 2);
    });
  });
}
