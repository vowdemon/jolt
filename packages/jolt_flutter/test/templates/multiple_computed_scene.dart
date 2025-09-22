import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class IndependentComputedScene extends StatefulWidget {
  const IndependentComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
    required this.doubleCounter,
    required this.tripleCounter,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;
  final Computed<int> doubleCounter;
  final Computed<int> tripleCounter;

  @override
  State<IndependentComputedScene> createState() =>
      _IndependentComputedSceneState();
}

class _IndependentComputedSceneState extends State<IndependentComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment'),
              onPressed: () {
                widget.counter.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Counter: ${widget.counter.value}, Double: ${widget.doubleCounter.value}, Triple: ${widget.tripleCounter.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChainedComputedScene extends StatefulWidget {
  const ChainedComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.base,
    required this.square,
    required this.cube,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> base;
  final Computed<int> square;
  final Computed<int> cube;

  @override
  State<ChainedComputedScene> createState() => _ChainedComputedSceneState();
}

class _ChainedComputedSceneState extends State<ChainedComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                widget.base.value = 3;
              },
              child: Text('Update Base'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Base: ${widget.base.value}, Square: ${widget.square.value}, Cube: ${widget.cube.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ComplexComputedScene extends StatefulWidget {
  const ComplexComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.width,
    required this.height,
    required this.area,
    required this.perimeter,
    required this.diagonal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> width;
  final Signal<int> height;
  final Computed<int> area;
  final Computed<int> perimeter;
  final Computed<double> diagonal;

  @override
  State<ComplexComputedScene> createState() => _ComplexComputedSceneState();
}

class _ComplexComputedSceneState extends State<ComplexComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                widget.width.value = 8;
                widget.height.value = 6;
              },
              child: Text('Update Dimensions'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Width: ${widget.width.value}, Height: ${widget.height.value}, Area: ${widget.area.value}, Perimeter: ${widget.perimeter.value}, Diagonal: ${widget.diagonal.value.toStringAsFixed(2)}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConditionalComputedScene extends StatefulWidget {
  const ConditionalComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.temperature,
    required this.isHot,
    required this.isCold,
    required this.weather,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> temperature;
  final Computed<bool> isHot;
  final Computed<bool> isCold;
  final Computed<String> weather;

  @override
  State<ConditionalComputedScene> createState() =>
      _ConditionalComputedSceneState();
}

class _ConditionalComputedSceneState extends State<ConditionalComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('setHot'),
              onPressed: () {
                widget.temperature.value = 35;
              },
              child: Text('Set Hot'),
            ),
            ElevatedButton(
              key: Key('setCold'),
              onPressed: () {
                widget.temperature.value = 5;
              },
              child: Text('Set Cold'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Temp: ${widget.temperature.value}, Hot: ${widget.isHot.value}, Cold: ${widget.isCold.value}, Weather: ${widget.weather.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ArrayComputedScene extends StatefulWidget {
  const ArrayComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.numbers,
    required this.sum,
    required this.average,
    required this.max,
    required this.min,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<List<int>> numbers;
  final Computed<int> sum;
  final Computed<double> average;
  final Computed<int> max;
  final Computed<int> min;

  @override
  State<ArrayComputedScene> createState() => _ArrayComputedSceneState();
}

class _ArrayComputedSceneState extends State<ArrayComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('add'),
              onPressed: () {
                final newList = List<int>.from(widget.numbers.value);
                newList.add(6);
                widget.numbers.value = newList;
              },
              child: Text('Add Number'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Numbers: ${widget.numbers.value}, Sum: ${widget.sum.value}, Avg: ${widget.average.value}, Max: ${widget.max.value}, Min: ${widget.min.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectComputedScene extends StatefulWidget {
  const ObjectComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.user,
    required this.isAdult,
    required this.taxRate,
    required this.netSalary,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<User> user;
  final Computed<bool> isAdult;
  final Computed<double> taxRate;
  final Computed<double> netSalary;

  @override
  State<ObjectComputedScene> createState() => _ObjectComputedSceneState();
}

class _ObjectComputedSceneState extends State<ObjectComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                widget.user.value = User(name: 'Bob', age: 16, salary: 30000);
              },
              child: Text('Update User'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);

                return Text(
                    'User: ${widget.user.value}, Adult: ${widget.isAdult.value}, Tax: ${widget.taxRate.value}, Net: ${widget.netSalary.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceComputedScene extends StatefulWidget {
  const PerformanceComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.data,
    required this.sum,
    required this.average,
    required this.evenCount,
    required this.oddCount,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<List<int>> data;
  final Computed<int> sum;
  final Computed<double> average;
  final Computed<int> evenCount;
  final Computed<int> oddCount;

  @override
  State<PerformanceComputedScene> createState() =>
      _PerformanceComputedSceneState();
}

class _PerformanceComputedSceneState extends State<PerformanceComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                final newData = List<int>.from(widget.data.value);
                newData.add(100);
                widget.data.value = newData;
              },
              child: Text('Update Data'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Sum: ${widget.sum.value}, Avg: ${widget.average.value}, Even: ${widget.evenCount.value}, Odd: ${widget.oddCount.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorComputedScene extends StatefulWidget {
  const ErrorComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.dividend,
    required this.divisor,
    required this.quotient,
    required this.remainder,
    required this.isValid,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> dividend;
  final Signal<int> divisor;
  final Computed<double> quotient;
  final Computed<int> remainder;
  final Computed<bool> isValid;

  @override
  State<ErrorComputedScene> createState() => _ErrorComputedSceneState();
}

class _ErrorComputedSceneState extends State<ErrorComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('setZero'),
              onPressed: () {
                widget.divisor.value = 0;
              },
              child: Text('Set Divisor to 0'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                String quotientStr;
                String remainderStr;
                try {
                  quotientStr = widget.quotient.value.toString();
                } catch (e) {
                  quotientStr = 'Error';
                }
                try {
                  remainderStr = widget.remainder.value.toString();
                } catch (e) {
                  remainderStr = 'Error';
                }
                return Text(
                    'Dividend: ${widget.dividend.value}, Divisor: ${widget.divisor.value}, Quotient: $quotientStr, Remainder: $remainderStr, Valid: ${widget.isValid.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncComputedScene extends StatefulWidget {
  const AsyncComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.input,
    required this.upperCase,
    required this.lowerCase,
    required this.wordCount,
    required this.charCount,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<String> input;
  final Computed<String> upperCase;
  final Computed<String> lowerCase;
  final Computed<int> wordCount;
  final Computed<int> charCount;

  @override
  State<AsyncComputedScene> createState() => _AsyncComputedSceneState();
}

class _AsyncComputedSceneState extends State<AsyncComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                widget.input.value = 'Hello Flutter';
              },
              child: Text('Update Input'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Input: ${widget.input.value}, Upper: ${widget.upperCase.value}, Lower: ${widget.lowerCase.value}, Words: ${widget.wordCount.value}, Chars: ${widget.charCount.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CachedComputedScene extends StatefulWidget {
  const CachedComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
    required this.expensive1,
    required this.expensive2,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;
  final Computed<int> expensive1;
  final Computed<int> expensive2;

  @override
  State<CachedComputedScene> createState() => _CachedComputedSceneState();
}

class _CachedComputedSceneState extends State<CachedComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment'),
              onPressed: () {
                widget.counter.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Counter: ${widget.counter.value}, Square: ${widget.expensive1.value}, Cube: ${widget.expensive2.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class User {
  final String name;
  final int age;
  final double salary;

  User({required this.name, required this.age, required this.salary});

  @override
  String toString() => '$name, $age, $salary';
}
