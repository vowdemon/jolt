import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Collection Signal Tests", () {
    group("ListSignal", () {
      group("read-only operations", () {
        test("read-only operations - length 5", () {
          final signal = ListSignal<int>([1, 2, 3, 4, 5]);
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.first, equals(peek.first));
          expect(signal.last, equals(peek.last));
          expect(() => signal.single, throwsA(isA<StateError>()));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(signal[0], equals(peek[0]));
          expect(signal[2], equals(peek[2]));
          expect(signal[4], equals(peek[4]));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues, equals(peekValues));

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.contains(10), equals(peek.contains(10)));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 3),
              equals(peek.firstWhere((e) => e > 3)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));
          expect(signal.lastWhere((e) => e < 5),
              equals(peek.lastWhere((e) => e < 5)));
          expect(signal.singleWhere((e) => e == 3),
              equals(peek.singleWhere((e) => e == 3)));
          expect(signal.indexOf(3), equals(peek.indexOf(3)));
          expect(signal.indexOf(3, 3), equals(peek.indexOf(3, 3)));
          expect(signal.lastIndexOf(3), equals(peek.lastIndexOf(3)));
          expect(signal.indexWhere((e) => e > 3),
              equals(peek.indexWhere((e) => e > 3)));
          expect(signal.lastIndexWhere((e) => e < 5),
              equals(peek.lastIndexWhere((e) => e < 5)));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toList(),
              equals(peek.where((e) => e % 2 == 0).toList()));
          expect(signal.whereType<int>().toList(),
              equals(peek.whereType<int>().toList()));
          expect(signal.map((e) => e * 2).toList(),
              equals(peek.map((e) => e * 2).toList()));
          expect(signal.expand((e) => [e, e]).toList(),
              equals(peek.expand((e) => [e, e]).toList()));
          expect(signal.followedBy([6, 7]).toList(),
              equals(peek.followedBy([6, 7]).toList()));
          expect(signal.getRange(1, 4).toList(),
              equals(peek.getRange(1, 4).toList()));
          expect(signal.asMap(), equals(peek.asMap()));
          expect(signal.reversed.toList(), equals(peek.reversed.toList()));
          expect(signal.sublist(1, 4), equals(peek.sublist(1, 4)));
          expect(signal.elementAt(2), equals(peek.elementAt(2)));
          expect(signal.skip(2).toList(), equals(peek.skip(2).toList()));
          expect(signal.skipWhile((e) => e < 3).toList(),
              equals(peek.skipWhile((e) => e < 3).toList()));
          expect(signal.take(3).toList(), equals(peek.take(3).toList()));
          expect(signal.takeWhile((e) => e < 4).toList(),
              equals(peek.takeWhile((e) => e < 4).toList()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));
          expect(signal.join(","), equals(peek.join(",")));
          expect(
              signal.cast<num>().toList(), equals(peek.cast<num>().toList()));
          expect(signal.reduce((a, b) => a + b),
              equals(peek.reduce((a, b) => a + b)));
          expect(signal.fold<int>(0, (sum, e) => sum + e),
              equals(peek.fold<int>(0, (sum, e) => sum + e)));

          // forEach
          final signalForEach = <int>[];
          final peekForEach = <int>[];
          signal.forEach(signalForEach.add);
          peek.forEach(peekForEach.add);
          expect(signalForEach, equals(peekForEach));

          // Operator +
          expect((signal + [6, 7]).toList(), equals((peek + [6, 7]).toList()));
        });

        test("read-only operations - length 0", () {
          final signal = ListSignal<int>([]);
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(() => signal.first, throwsA(isA<StateError>()));
          expect(() => peek.first, throwsA(isA<StateError>()));
          expect(() => signal.last, throwsA(isA<StateError>()));
          expect(() => peek.last, throwsA(isA<StateError>()));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues, equals(peekValues));
          expect(signalValues, isEmpty);

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toList(),
              equals(peek.where((e) => e % 2 == 0).toList()));
          expect(signal.map((e) => e * 2).toList(),
              equals(peek.map((e) => e * 2).toList()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));
          expect(signal.join(","), equals(peek.join(",")));
        });
      });

      group("write operations", () {
        test("write operations - change triggers notify", () {
          final signal = ListSignal<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // add
          signal.add(6);
          expect(notifyCount, equals(2));
          expect(signal.value, equals([1, 2, 3, 4, 5, 6]));

          // addAll
          signal.addAll([7, 8]);
          expect(notifyCount, equals(3));
          expect(signal.value.length, equals(8));

          // insert
          signal.insert(0, 0);
          expect(notifyCount, equals(4));
          expect(signal.value[0], equals(0));

          // insertAll
          signal.insertAll(1, [10, 11]);
          expect(notifyCount, equals(5));
          expect(signal.value.length, greaterThan(8));

          // remove
          signal.remove(10);
          expect(notifyCount, equals(6));

          // removeAt
          signal.removeAt(0);
          expect(notifyCount, equals(7));

          // removeLast
          signal.removeLast();
          expect(notifyCount, equals(8));

          // removeRange
          signal.addAll([20, 21, 22]);
          final lengthBefore = signal.value.length;
          signal.removeRange(0, 2);
          expect(notifyCount, equals(10)); // addAll + removeRange
          expect(signal.value.length, equals(lengthBefore - 2));

          // removeWhere
          signal.addAll([30, 31]);
          signal.removeWhere((e) => e == 30);
          expect(notifyCount, equals(12)); // addAll + removeWhere

          // retainWhere
          signal.addAll([40, 41, 42]);
          signal.retainWhere((e) => e < 40);
          expect(notifyCount, equals(14)); // addAll + retainWhere

          // clear
          signal.clear();
          expect(notifyCount, equals(15));
          expect(signal.value, isEmpty);

          // fillRange
          signal.addAll([1, 2, 3, 4, 5]);
          signal.fillRange(1, 3, 10);
          expect(notifyCount, equals(17)); // addAll + fillRange
          expect(signal.value[1], equals(10));
          expect(signal.value[2], equals(10));

          // replaceRange
          signal.replaceRange(1, 3, [2, 3]);
          expect(notifyCount, equals(18));
          expect(signal.value[1], equals(2));

          // setAll
          signal.setAll(2, [30, 40]);
          expect(notifyCount, equals(19));
          expect(signal.value[2], equals(30));

          // setRange
          signal.setRange(0, 2, [10, 20]);
          expect(notifyCount, equals(20));
          expect(signal.value[0], equals(10));

          // setRange with skipCount
          signal.setRange(0, 2, [100, 200, 300, 400], 2);
          expect(notifyCount, equals(21));
          expect(signal.value[0], equals(300));
          expect(signal.value[1], equals(400));

          // shuffle
          final originalOrder = List.from(signal.value);
          signal.shuffle();
          expect(notifyCount, equals(22));
          expect(signal.value.length, equals(originalOrder.length));

          // sort
          signal.sort();
          expect(notifyCount, equals(23));

          // first setter
          signal.first = 100;
          expect(notifyCount, equals(24));
          expect(signal.value[0], equals(100));

          // last setter
          signal.last = 200;
          expect(notifyCount, equals(25));
          expect(signal.value.last, equals(200));

          // length setter
          signal.length = 3;
          expect(notifyCount, equals(26));
          expect(signal.value.length, equals(3));

          // index assignment
          signal[0] = 300;
          expect(notifyCount, equals(27));
          expect(signal.value[0], equals(300));
        });

        test("write operations - no change does not trigger notify", () {
          final signal = ListSignal<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // index assignment with same value
          signal[0] = 1;
          expect(notifyCount, equals(1)); // Should not trigger

          // first setter with same value
          signal.first = 1;
          expect(notifyCount, equals(1)); // Should not trigger

          // last setter with same value
          signal.last = 5;
          expect(notifyCount, equals(1)); // Should not trigger

          // length setter with same value
          signal.length = 5;
          expect(notifyCount, equals(1)); // Should not trigger

          // clear empty list
          final emptySignal = ListSignal<int>([]);
          var emptyNotifyCount = 0;
          Effect(() {
            emptySignal.value;
            emptyNotifyCount++;
          });
          expect(emptyNotifyCount, equals(1));
          emptySignal.clear();
          expect(emptyNotifyCount, equals(1)); // Should not trigger

          // fillRange with same values
          signal.fillRange(1, 2, 2);
          expect(
              notifyCount, equals(1)); // Should not trigger if values unchanged

          // replaceRange with same values
          signal.replaceRange(1, 3, [2, 3]);
          expect(
              notifyCount, equals(1)); // Should not trigger if values unchanged

          // setAll with same values
          signal.setAll(0, [1, 2]);
          expect(
              notifyCount, equals(1)); // Should not trigger if values unchanged

          // setRange with skipCount and same values
          signal.setRange(0, 2, [100, 200, 1, 2], 2);
          expect(
              notifyCount, equals(1)); // Should not trigger if values unchanged

          // setRange with same values
          signal.setRange(0, 2, [1, 2]);
          expect(
              notifyCount, equals(1)); // Should not trigger if values unchanged

          // shuffle empty list
          final emptyList = ListSignal<int>([]);
          var emptyListNotifyCount = 0;
          Effect(() {
            emptyList.value;
            emptyListNotifyCount++;
          });
          expect(emptyListNotifyCount, equals(1));
          emptyList.shuffle();
          expect(emptyListNotifyCount, equals(1)); // Should not trigger

          // sort empty list
          emptyList.sort();
          expect(emptyListNotifyCount, equals(1)); // Should not trigger
        });
      });
    });

    group("SetSignal", () {
      group("read-only operations", () {
        test("read-only operations - length 5", () {
          final signal = SetSignal<int>({1, 2, 3, 4, 5});
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.first, equals(peek.first));
          expect(signal.last, equals(peek.last));
          expect(() => signal.single, throwsA(isA<StateError>()));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues.toSet(), equals(peekValues.toSet()));
          expect(signalValues.length, equals(5));

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.contains(10), equals(peek.contains(10)));
          expect(signal.containsAll({1, 2, 3}),
              equals(peek.containsAll({1, 2, 3})));
          expect(signal.containsAll({1, 2, 10}),
              equals(peek.containsAll({1, 2, 10})));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 3),
              equals(peek.firstWhere((e) => e > 3)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));
          expect(signal.lastWhere((e) => e < 5),
              equals(peek.lastWhere((e) => e < 5)));
          expect(signal.singleWhere((e) => e == 3),
              equals(peek.singleWhere((e) => e == 3)));
          expect(signal.lookup(3), equals(peek.lookup(3)));
          expect(signal.lookup(10), equals(peek.lookup(10)));
          expect(signal.elementAt(2), equals(peek.elementAt(2)));

          // Set operations
          expect(signal.union({6, 7}), equals(peek.union({6, 7})));
          expect(signal.intersection({3, 4, 5, 6}),
              equals(peek.intersection({3, 4, 5, 6})));
          expect(signal.difference({3, 4}), equals(peek.difference({3, 4})));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toSet(),
              equals(peek.where((e) => e % 2 == 0).toSet()));
          expect(signal.whereType<int>().toSet(),
              equals(peek.whereType<int>().toSet()));
          expect(signal.map((e) => e * 2).toSet(),
              equals(peek.map((e) => e * 2).toSet()));
          expect(signal.expand((e) => [e, e]).toSet(),
              equals(peek.expand((e) => [e, e]).toSet()));
          expect(signal.followedBy({6, 7}).toList(),
              equals(peek.followedBy({6, 7}).toList()));
          expect(signal.skip(2).toSet(), equals(peek.skip(2).toSet()));
          expect(signal.skipWhile((e) => e < 3).toSet(),
              equals(peek.skipWhile((e) => e < 3).toSet()));
          expect(signal.take(3).toSet(), equals(peek.take(3).toSet()));
          expect(signal.takeWhile((e) => e < 4).toSet(),
              equals(peek.takeWhile((e) => e < 4).toSet()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));
          final signalJoin = signal.join(",");
          final peekJoin = peek.join(",");
          expect(signalJoin.split(",").toSet(),
              equals(peekJoin.split(",").toSet()));
          expect(signal.cast<num>().toSet(), equals(peek.cast<num>().toSet()));
          expect(signal.reduce((a, b) => a + b),
              equals(peek.reduce((a, b) => a + b)));
          expect(signal.fold<int>(0, (sum, e) => sum + e),
              equals(peek.fold<int>(0, (sum, e) => sum + e)));

          // forEach
          final signalForEach = <int>[];
          final peekForEach = <int>[];
          signal.forEach(signalForEach.add);
          peek.forEach(peekForEach.add);
          expect(signalForEach.toSet(), equals(peekForEach.toSet()));
        });

        test("read-only operations - length 0", () {
          final signal = SetSignal<int>({});
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(() => signal.first, throwsA(isA<StateError>()));
          expect(() => peek.first, throwsA(isA<StateError>()));
          expect(() => signal.last, throwsA(isA<StateError>()));
          expect(() => peek.last, throwsA(isA<StateError>()));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues, equals(peekValues));
          expect(signalValues, isEmpty);

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.containsAll({1, 2}), equals(peek.containsAll({1, 2})));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toSet(),
              equals(peek.where((e) => e % 2 == 0).toSet()));
          expect(signal.map((e) => e * 2).toSet(),
              equals(peek.map((e) => e * 2).toSet()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));
        });
      });

      group("write operations", () {
        test("write operations - change triggers notify", () {
          final signal = SetSignal<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // add new element
          signal.add(6);
          expect(notifyCount, equals(2));
          expect(signal.value.contains(6), isTrue);

          // addAll with new elements
          signal.addAll([7, 8]);
          expect(notifyCount, equals(3));
          expect(signal.value.containsAll({7, 8}), isTrue);

          // remove existing element
          signal.remove(1);
          expect(notifyCount, equals(4));
          expect(signal.value.contains(1), isFalse);

          // removeAll
          signal.addAll([9, 10]);
          signal.removeAll({9, 10});
          expect(notifyCount, equals(6)); // addAll + removeAll

          // removeWhere
          signal.addAll([11, 12]);
          signal.removeWhere((e) => e == 11);
          expect(notifyCount, equals(8)); // addAll + removeWhere

          // retainAll
          signal.addAll([13, 14, 15]);
          signal.retainAll({2, 3, 4, 5, 6, 7, 8, 12});
          expect(notifyCount, equals(10)); // addAll + retainAll

          // retainWhere
          signal.addAll([16, 17]);
          signal.retainWhere((e) => e < 10);
          expect(notifyCount, equals(12)); // addAll + retainWhere

          // clear
          signal.clear();
          expect(notifyCount, equals(13));
          expect(signal.value, isEmpty);
        });

        test("write operations - no change does not trigger notify", () {
          final signal = SetSignal<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // add existing element
          signal.add(1);
          expect(notifyCount, equals(1)); // Should not trigger

          // add existing element again
          signal.add(2);
          expect(notifyCount, equals(1)); // Should not trigger

          // remove non-existent element
          signal.remove(10);
          expect(notifyCount, equals(1)); // Should not trigger

          // addAll with all existing elements
          signal.addAll([1, 2, 3]);
          expect(notifyCount, equals(1)); // Should not trigger

          // removeAll with all non-existent elements
          signal.removeAll({10, 11, 12});
          expect(notifyCount, equals(1)); // Should not trigger

          // removeWhere with no matches
          signal.removeWhere((e) => e > 100);
          expect(notifyCount, equals(1)); // Should not trigger

          // retainAll with all elements
          signal.retainAll({1, 2, 3, 4, 5});
          expect(notifyCount, equals(1)); // Should not trigger

          // retainWhere keeping all elements
          signal.retainWhere((e) => e > 0);
          expect(notifyCount, equals(1)); // Should not trigger

          // clear empty set
          final emptySignal = SetSignal<int>({});
          var emptyNotifyCount = 0;
          Effect(() {
            emptySignal.value;
            emptyNotifyCount++;
          });
          expect(emptyNotifyCount, equals(1));
          emptySignal.clear();
          expect(emptyNotifyCount, equals(1)); // Should not trigger
        });
      });
    });

    group("MapSignal", () {
      group("read-only operations", () {
        test("read-only operations - length 5", () {
          final signal =
              MapSignal<String, int>({"a": 1, "b": 2, "c": 3, "d": 4, "e": 5});
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(signal["a"], equals(peek["a"]));
          expect(signal["x"], equals(peek["x"]));
          expect(signal.keys, equals(peek.keys));
          expect(signal.values, equals(peek.values));
          expect(signal.entries.length, equals(peek.entries.length));

          // Iterator
          final signalKeys = <String>[];
          final peekKeys = <String>[];
          signal.forEach((key, value) {
            signalKeys.add(key);
          });
          peek.forEach((key, value) {
            peekKeys.add(key);
          });
          expect(signalKeys.toSet(), equals(peekKeys.toSet()));

          // Query methods
          expect(signal.containsKey("a"), equals(peek.containsKey("a")));
          expect(signal.containsKey("x"), equals(peek.containsKey("x")));
          expect(signal.containsValue(2), equals(peek.containsValue(2)));
          expect(signal.containsValue(10), equals(peek.containsValue(10)));

          // Transformation methods
          final signalMapped = signal.map<String, String>(
              (key, value) => MapEntry(key, value.toString()));
          final peekMapped = peek.map<String, String>(
              (key, value) => MapEntry(key, value.toString()));
          expect(signalMapped["a"], equals(peekMapped["a"]));
          expect(signal.cast<String, num>()["a"],
              equals(peek.cast<String, num>()["a"]));

          // Error cases - update without ifAbsent for non-existent key
          expect(() => signal.update("x", (value) => value),
              throwsA(isA<ArgumentError>()));
          expect(() => peek.update("x", (value) => value),
              throwsA(isA<ArgumentError>()));
        });

        test("read-only operations - length 0", () {
          final signal = MapSignal<String, int>({});
          final peek = signal.peek;

          // Properties
          expect(signal.length, equals(peek.length));
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(signal["a"], equals(peek["a"]));
          expect(signal.keys, equals(peek.keys));
          expect(signal.values, equals(peek.values));
          expect(signal.entries.length, equals(peek.entries.length));

          // Query methods
          expect(signal.containsKey("a"), equals(peek.containsKey("a")));
          expect(signal.containsValue(2), equals(peek.containsValue(2)));

          // Transformation methods
          final signalMapped = signal.map<String, String>(
              (key, value) => MapEntry(key, value.toString()));
          final peekMapped = peek.map<String, String>(
              (key, value) => MapEntry(key, value.toString()));
          expect(signalMapped.length, equals(peekMapped.length));

          // Error cases - update without ifAbsent for non-existent key
          expect(() => signal.update("x", (value) => value),
              throwsA(isA<ArgumentError>()));
          expect(() => peek.update("x", (value) => value),
              throwsA(isA<ArgumentError>()));
        });
      });

      group("write operations", () {
        test("write operations - change triggers notify", () {
          final signal = MapSignal<String, int>({"a": 1, "b": 2, "c": 3});
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // index assignment with new key
          signal["d"] = 4;
          expect(notifyCount, equals(2));
          expect(signal.value["d"], equals(4));

          // index assignment with different value
          signal["a"] = 10;
          expect(notifyCount, equals(3));
          expect(signal.value["a"], equals(10));

          // addAll with new keys
          signal.addAll({"e": 5, "f": 6});
          expect(notifyCount, equals(4));
          expect(signal.value["e"], equals(5));

          // addAll with different values
          signal.addAll({"a": 20});
          expect(notifyCount, equals(5));
          expect(signal.value["a"], equals(20));

          // addEntries with new keys
          signal.addEntries([const MapEntry("g", 7), const MapEntry("h", 8)]);
          expect(notifyCount, equals(6));
          expect(signal.value["g"], equals(7));

          // addEntries with different values
          signal.addEntries([const MapEntry("a", 30)]);
          expect(notifyCount, equals(7));
          expect(signal.value["a"], equals(30));

          // putIfAbsent with new key
          signal.putIfAbsent("i", () => 9);
          expect(notifyCount, equals(8));
          expect(signal.value["i"], equals(9));

          // update with different value
          signal.update("a", (value) => value * 2);
          expect(notifyCount, equals(9));
          expect(signal.value["a"], equals(60));

          // update with ifAbsent (new key)
          signal.update("j", (value) => value, ifAbsent: () => 10);
          expect(notifyCount, equals(10));
          expect(signal.value["j"], equals(10));

          // updateAll with different values
          signal.updateAll((key, value) => value + 1);
          expect(notifyCount, equals(11));
          expect(signal.value["a"], equals(61));

          // remove existing key
          signal.remove("a");
          expect(notifyCount, equals(12));
          expect(signal.value["a"], isNull);

          // removeWhere
          signal.addAll({"k": 11, "l": 12});
          signal.removeWhere((key, value) => value < 10);
          expect(notifyCount, equals(14)); // addAll + removeWhere

          // clear
          signal.clear();
          expect(notifyCount, equals(15));
          expect(signal.value, isEmpty);
        });

        test("write operations - no change does not trigger notify", () {
          final signal = MapSignal<String, int>({"a": 1, "b": 2, "c": 3});
          var notifyCount = 0;
          Effect(() {
            signal.value;
            notifyCount++;
          });
          expect(notifyCount, equals(1));

          // index assignment with same value
          signal["a"] = 1;
          expect(notifyCount, equals(1)); // Should not trigger

          // addAll with all same values
          signal.addAll({"a": 1, "b": 2});
          expect(notifyCount, equals(1)); // Should not trigger

          // addEntries with all same values
          signal.addEntries([const MapEntry("a", 1), const MapEntry("b", 2)]);
          expect(notifyCount, equals(1)); // Should not trigger

          // putIfAbsent with existing key
          signal.putIfAbsent("a", () => 100);
          expect(notifyCount, equals(1)); // Should not trigger
          expect(signal.value["a"], equals(1)); // Value unchanged

          // update with same value
          signal.update("a", (value) => value);
          expect(notifyCount, equals(1)); // Should not trigger

          // updateAll with all same values
          signal.updateAll((key, value) => value);
          expect(notifyCount, equals(1)); // Should not trigger

          // remove non-existent key
          signal.remove("x");
          expect(notifyCount, equals(1)); // Should not trigger

          // removeWhere with no matches
          signal.removeWhere((key, value) => value > 100);
          expect(notifyCount, equals(1)); // Should not trigger

          // clear empty map
          final emptySignal = MapSignal<String, int>({});
          var emptyNotifyCount = 0;
          Effect(() {
            emptySignal.value;
            emptyNotifyCount++;
          });
          expect(emptyNotifyCount, equals(1));
          emptySignal.clear();
          expect(emptyNotifyCount, equals(1)); // Should not trigger
        });
      });
    });

    group("IterableSignal", () {
      group("read-only operations", () {
        test("read-only operations - length 5", () {
          final source = Signal<List<int>>([1, 2, 3, 4, 5]);
          final signal = IterableSignal(() => source.value);
          final peek = signal.peek;

          // Properties
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(signal.first, equals(peek.first));
          expect(signal.last, equals(peek.last));
          expect(() => signal.single, throwsA(isA<StateError>()));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues, equals(peekValues));

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.contains(10), equals(peek.contains(10)));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 3),
              equals(peek.firstWhere((e) => e > 3)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));
          expect(signal.lastWhere((e) => e < 5),
              equals(peek.lastWhere((e) => e < 5)));
          expect(signal.singleWhere((e) => e == 3),
              equals(peek.singleWhere((e) => e == 3)));
          expect(signal.elementAt(2), equals(peek.elementAt(2)));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toList(),
              equals(peek.where((e) => e % 2 == 0).toList()));
          expect(signal.whereType<int>().toList(),
              equals(peek.whereType<int>().toList()));
          expect(signal.map((e) => e * 2).toList(),
              equals(peek.map((e) => e * 2).toList()));
          expect(signal.expand((e) => [e, e]).toList(),
              equals(peek.expand((e) => [e, e]).toList()));
          expect(signal.followedBy([6, 7]).toList(),
              equals(peek.followedBy([6, 7]).toList()));
          expect(signal.skip(2).toList(), equals(peek.skip(2).toList()));
          expect(signal.skipWhile((e) => e < 3).toList(),
              equals(peek.skipWhile((e) => e < 3).toList()));
          expect(signal.take(3).toList(), equals(peek.take(3).toList()));
          expect(signal.takeWhile((e) => e < 4).toList(),
              equals(peek.takeWhile((e) => e < 4).toList()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));
          expect(signal.join(","), equals(peek.join(",")));

          // Reduction methods
          expect(signal.reduce((a, b) => a + b),
              equals(peek.reduce((a, b) => a + b)));
          expect(signal.fold<int>(0, (sum, e) => sum + e),
              equals(peek.fold<int>(0, (sum, e) => sum + e)));

          // forEach
          final signalForEach = <int>[];
          final peekForEach = <int>[];
          for (final e in signal) {
            signalForEach.add(e);
          }
          for (final e in peek) {
            peekForEach.add(e);
          }
          expect(signalForEach, equals(peekForEach));

          // toString
          expect(signal.toString(), equals(peek.toString()));
        });

        test("read-only operations - length 0", () {
          final source = Signal<List<int>>([]);
          final signal = IterableSignal(() => source.value);
          final peek = signal.peek;

          // Properties
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));
          expect(() => signal.first, throwsA(isA<StateError>()));
          expect(() => peek.first, throwsA(isA<StateError>()));
          expect(() => signal.last, throwsA(isA<StateError>()));
          expect(() => peek.last, throwsA(isA<StateError>()));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues, equals(peekValues));
          expect(signalValues, isEmpty);

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));
          expect(signal.every((e) => e > 0), equals(peek.every((e) => e > 0)));
          expect(signal.firstWhere((e) => e > 10, orElse: () => -1),
              equals(peek.firstWhere((e) => e > 10, orElse: () => -1)));

          // Transformation methods
          expect(signal.where((e) => e % 2 == 0).toList(),
              equals(peek.where((e) => e % 2 == 0).toList()));
          expect(signal.map((e) => e * 2).toList(),
              equals(peek.map((e) => e * 2).toList()));
          expect(signal.toList(), equals(peek.toList()));
          expect(signal.toSet(), equals(peek.toSet()));

          // toString
          expect(signal.toString(), equals(peek.toString()));
        });

        test("read-only operations - with Set source", () {
          final source = Signal<Set<int>>({1, 2, 3, 4, 5});
          final signal = IterableSignal(() => source.value);
          final peek = signal.peek;

          // Properties
          expect(signal.isEmpty, equals(peek.isEmpty));
          expect(signal.isNotEmpty, equals(peek.isNotEmpty));

          // Iterator
          final signalValues = <int>[];
          final peekValues = <int>[];
          for (final value in signal) {
            signalValues.add(value);
          }
          for (final value in peek) {
            peekValues.add(value);
          }
          expect(signalValues.toSet(), equals(peekValues.toSet()));

          // Query methods
          expect(signal.contains(3), equals(peek.contains(3)));
          expect(signal.any((e) => e > 4), equals(peek.any((e) => e > 4)));

          // toString
          expect(signal.toString(), equals(peek.toString()));
        });

        test("IterableSignal.value factory", () {
          // Test with List
          final listIterable = IterableSignal.value([1, 2, 3, 4, 5]);
          expect(listIterable.toList(), equals([1, 2, 3, 4, 5]));
          expect(listIterable.toString(), equals([1, 2, 3, 4, 5].toString()));

          // Test with Set
          final setIterable = IterableSignal.value({1, 2, 3, 4, 5});
          expect(setIterable.toSet(), equals({1, 2, 3, 4, 5}));
          expect(setIterable.toString(), equals({1, 2, 3, 4, 5}.toString()));

          // Test with empty iterable
          final emptyIterable = IterableSignal.value(<int>[]);
          expect(emptyIterable.toList(), isEmpty);
          expect(emptyIterable.toString(), equals(<int>[].toString()));

          // Test that value factory returns same iterable
          final staticList = [10, 20, 30];
          final valueIterable = IterableSignal.value(staticList);
          expect(valueIterable.toList(), equals(staticList));
          expect(valueIterable.toString(), equals(staticList.toString()));

          // Test with peek
          final peek = valueIterable.peek;
          expect(valueIterable.toString(), equals(peek.toString()));
        });
      });
    });
  });
}
