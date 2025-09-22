import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/multiple_computed_scene.dart';

void main() {
  group('Multiple Computed Tests', () {
    testWidgets('Multiple Independent Computed - Independent Calculation',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);
      final doubleCounter = Computed(() => counter.value * 2);
      final tripleCounter = Computed(() => counter.value * 3);

      final widget = IndependentComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
        doubleCounter: doubleCounter,
        tripleCounter: tripleCounter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter: 0, Double: 0, Triple: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1, Double: 2, Triple: 3'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Multiple Computed - Chain Dependencies', (tester) async {
      int rebuildCount = 0;
      final base = Signal(2);
      final square = Computed(() => base.value * base.value);
      final cube = Computed(() => square.value * base.value);

      final widget = ChainedComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        base: base,
        square: square,
        cube: cube,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Base: 2, Square: 4, Cube: 8'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(find.text('Base: 3, Square: 9, Cube: 27'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Multiple Computed - Complex Computation Logic',
        (tester) async {
      int rebuildCount = 0;
      final width = Signal(10);
      final height = Signal(5);
      final area = Computed(() => width.value * height.value);
      final perimeter = Computed(() => 2 * (width.value + height.value));
      final diagonal = Computed(
          () => sqrt(width.value * width.value + height.value * height.value));

      final widget = ComplexComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        width: width,
        height: height,
        area: area,
        perimeter: perimeter,
        diagonal: diagonal,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text(
              'Width: 10, Height: 5, Area: 50, Perimeter: 30, Diagonal: 11.18'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Width: 8, Height: 6, Area: 48, Perimeter: 28, Diagonal: 10.00'),
          findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Computed - Conditional Calculation', (tester) async {
      int rebuildCount = 0;
      final temperature = Signal(25);
      final isHot = Computed(() => temperature.value > 30);
      final isCold = Computed(() => temperature.value < 10);
      final weather = Computed(() {
        if (isHot.value) return 'Hot';
        if (isCold.value) return 'Cold';
        return 'Moderate';
      });

      final widget = ConditionalComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        temperature: temperature,
        isHot: isHot,
        isCold: isCold,
        weather: weather,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Temp: 25, Hot: false, Cold: false, Weather: Moderate'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('setHot')));
      await tester.pumpAndSettle();

      expect(find.text('Temp: 35, Hot: true, Cold: false, Weather: Hot'),
          findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('setCold')));
      await tester.pumpAndSettle();

      expect(find.text('Temp: 5, Hot: false, Cold: true, Weather: Cold'),
          findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Computed - Array Operations', (tester) async {
      int rebuildCount = 0;
      final numbers = Signal<List<int>>([1, 2, 3, 4, 5]);
      final sum =
          Computed(() => numbers.value.fold<int>(0, (acc, cur) => acc + cur));
      final average = Computed(() => sum.value / numbers.value.length);
      final max = Computed(() => numbers.value
          .fold<int>(numbers.value.first, (max, cur) => cur > max ? cur : max));
      final min = Computed(() => numbers.value
          .fold<int>(numbers.value.first, (min, cur) => cur < min ? cur : min));

      final widget = ArrayComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        numbers: numbers,
        sum: sum,
        average: average,
        max: max,
        min: min,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text(
              'Numbers: [1, 2, 3, 4, 5], Sum: 15, Avg: 3.0, Max: 5, Min: 1'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('add')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Numbers: [1, 2, 3, 4, 5, 6], Sum: 21, Avg: 3.5, Max: 6, Min: 1'),
          findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Multiple Computed - Object Properties', (tester) async {
      int rebuildCount = 0;
      final user = Signal(User(name: 'Alice', age: 25, salary: 50000));
      final isAdult = Computed(() => user.value.age >= 18);
      final taxRate = Computed(() => user.value.salary > 40000 ? 0.2 : 0.1);
      final netSalary = Computed(() => user.value.salary * (1 - taxRate.value));

      final widget = ObjectComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        user: user,
        isAdult: isAdult,
        taxRate: taxRate,
        netSalary: netSalary,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text(
              'User: Alice, 25, 50000.0, Adult: true, Tax: 0.2, Net: 40000.0'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'User: Bob, 16, 30000.0, Adult: false, Tax: 0.1, Net: 27000.0'),
          findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Multiple Computed - Async Calculation', (tester) async {
      int rebuildCount = 0;
      final input = Signal('hello world');
      final upperCase = Computed(() => input.value.toUpperCase());
      final lowerCase = Computed(() => input.value.toLowerCase());
      final wordCount = Computed(() => input.value.split(' ').length);
      final charCount = Computed(() => input.value.length);

      final widget = AsyncComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        input: input,
        upperCase: upperCase,
        lowerCase: lowerCase,
        wordCount: wordCount,
        charCount: charCount,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text(
              'Input: hello world, Upper: HELLO WORLD, Lower: hello world, Words: 2, Chars: 11'),
          findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Input: Hello Flutter, Upper: HELLO FLUTTER, Lower: hello flutter, Words: 2, Chars: 13'),
          findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Multiple Computed - Caching Mechanism', (tester) async {
      int rebuildCount = 0;
      int computeCount1 = 0;
      int computeCount2 = 0;
      final counter = Signal(0);
      final expensive1 = Computed(() {
        computeCount1++;
        return counter.value * counter.value;
      });
      final expensive2 = Computed(() {
        computeCount2++;
        return counter.value * counter.value * counter.value;
      });

      final widget = CachedComputedScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
        expensive1: expensive1,
        expensive2: expensive2,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter: 0, Square: 0, Cube: 0'), findsOneWidget);
      expect(rebuildCount, 1);
      expect(computeCount1, 1);
      expect(computeCount2, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1, Square: 1, Cube: 1'), findsOneWidget);
      expect(rebuildCount, 2);
      expect(computeCount1, 2);
      expect(computeCount2, 2);

      await tester.pumpAndSettle();
      expect(computeCount1, 2);
      expect(computeCount2, 2);
    });
  });
}
