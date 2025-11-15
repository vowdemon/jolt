import "package:jolt/jolt.dart";
import "package:test/test.dart";
import "utils.dart";

void main() {
  group("Extension methods", () {
    group("JoltObjectExtension", () {
      test("should convert any object to signal", () {
        const value = 42;
        final signal = value.toSignal();

        expect(signal, isA<Signal<int>>());
        expect(signal.value, equals(42));
      });

      test("should work with different data types", () {
        // String
        const stringValue = "hello";
        final stringSignal = stringValue.toSignal();
        expect(stringSignal.value, equals("hello"));

        // List
        final listValue = [1, 2, 3];
        final listSignal = listValue.toSignal();
        expect(listSignal.value, equals([1, 2, 3]));

        // Map
        final mapValue = {"a": 1, "b": 2};
        final mapSignal = mapValue.toSignal();
        expect(mapSignal.value, equals({"a": 1, "b": 2}));

        // Set
        final setValue = {1, 2, 3};
        final setSignal = setValue.toSignal();
        expect(setSignal.value, equals({1, 2, 3}));

        // Nullable
        const Null nullableValue = null;
        final nullableSignal = nullableValue.toSignal();
        expect(nullableSignal.value, isNull);
      });

      test("should work with custom objects", () {
        final person = TestPerson("Alice", 30);
        final personSignal = person.toSignal();

        expect(personSignal.value, equals(TestPerson("Alice", 30)));
      });
    });

    group("JoltListExtension", () {
      test("should convert list to list signal", () {
        final list = [1, 2, 3];
        final listSignal = list.toListSignal();

        expect(listSignal, isA<ListSignal<int>>());
        expect(listSignal.value, equals([1, 2, 3]));
      });

      test("should work with different list types", () {
        // String list
        final stringList = ["hello", "world"];
        final stringListSignal = stringList.toListSignal();
        expect(stringListSignal.value, equals(["hello", "world"]));

        // Nullable list
        final nullableList = [1, null, 3];
        final nullableListSignal = nullableList.toListSignal();
        expect(nullableListSignal.value, equals([1, null, 3]));

        // Empty list
        final emptyList = <int>[];
        final emptyListSignal = emptyList.toListSignal();
        expect(emptyListSignal.value, equals([]));
      });

      test("should work with custom objects", () {
        final personList = [TestPerson("Alice", 30), TestPerson("Bob", 25)];
        final personListSignal = personList.toListSignal();

        expect(
          personListSignal.value,
          equals([TestPerson("Alice", 30), TestPerson("Bob", 25)]),
        );
      });

      test("should be reactive", () {
        final list = [1, 2, 3];
        final listSignal = list.toListSignal();
        final values = <List<int>>[];

        Effect(() {
          values.add(List.from(listSignal.value));
        });

        expect(
          values,
          equals([
            [1, 2, 3],
          ]),
        );

        listSignal.add(4);
        expect(
          values,
          equals([
            [1, 2, 3],
            [1, 2, 3, 4],
          ]),
        );
      });
    });

    group("JoltMapExtension", () {
      test("should convert map to map signal", () {
        final map = {"a": 1, "b": 2};
        final mapSignal = map.toMapSignal();

        expect(mapSignal, isA<MapSignal<String, int>>());
        expect(mapSignal.value, equals({"a": 1, "b": 2}));
      });

      test("should work with different map types", () {
        // Int key map
        final intMap = {1: "one", 2: "two"};
        final intMapSignal = intMap.toMapSignal();
        expect(intMapSignal.value, equals({1: "one", 2: "two"}));

        // Nullable value map
        final nullableMap = {"a": 1, "b": null};
        final nullableMapSignal = nullableMap.toMapSignal();
        expect(nullableMapSignal.value, equals({"a": 1, "b": null}));

        // Empty map
        final emptyMap = <String, int>{};
        final emptyMapSignal = emptyMap.toMapSignal();
        expect(emptyMapSignal.value, equals({}));
      });

      test("should work with custom objects", () {
        final personMap = {
          "alice": TestPerson("Alice", 30),
          "bob": TestPerson("Bob", 25),
        };
        final personMapSignal = personMap.toMapSignal();

        expect(
          personMapSignal.value,
          equals({
            "alice": TestPerson("Alice", 30),
            "bob": TestPerson("Bob", 25),
          }),
        );
      });

      test("should be reactive", () {
        final map = {"a": 1};
        final mapSignal = map.toMapSignal();
        final values = <Map<String, int>>[];

        Effect(() {
          values.add(Map.from(mapSignal.value));
        });

        expect(
          values,
          equals([
            {"a": 1},
          ]),
        );

        mapSignal["b"] = 2;
        expect(
          values,
          equals([
            {"a": 1},
            {"a": 1, "b": 2},
          ]),
        );
      });
    });

    group("JoltSetExtension", () {
      test("should convert set to set signal", () {
        final set = {1, 2, 3};
        final setSignal = set.toSetSignal();

        expect(setSignal, isA<SetSignal<int>>());
        expect(setSignal.value, equals({1, 2, 3}));
      });

      test("should work with different set types", () {
        // String set
        final stringSet = {"hello", "world"};
        final stringSetSignal = stringSet.toSetSignal();
        expect(stringSetSignal.value, equals({"hello", "world"}));

        // Nullable set
        final nullableSet = {1, null, 3};
        final nullableSetSignal = nullableSet.toSetSignal();
        expect(nullableSetSignal.value, equals({1, null, 3}));

        // Empty set
        final emptySet = <int>{};
        final emptySetSignal = emptySet.toSetSignal();
        expect(emptySetSignal.value, equals(<int>{}));
      });

      test("should work with custom objects", () {
        final personSet = {TestPerson("Alice", 30), TestPerson("Bob", 25)};
        final personSetSignal = personSet.toSetSignal();

        expect(
          personSetSignal.value,
          equals({TestPerson("Alice", 30), TestPerson("Bob", 25)}),
        );
      });

      test("should be reactive", () {
        final set = {1, 2};
        final setSignal = set.toSetSignal();
        final values = <Set<int>>[];

        Effect(() {
          values.add(Set.from(setSignal.value));
        });

        expect(
          values,
          equals([
            {1, 2},
          ]),
        );

        setSignal.add(3);
        expect(
          values,
          equals([
            {1, 2},
            {1, 2, 3},
          ]),
        );
      });
    });

    group("JoltIterableExtension", () {
      test("should convert iterable to iterable signal", () {
        final iterable = [1, 2, 3];
        final iterableSignal = iterable.toIterableSignal();

        expect(iterableSignal, isA<IterableSignal<int>>());
        expect(iterableSignal.value, equals([1, 2, 3]));
      });

      test("should work with different iterable types", () {
        // Set iterable
        final setIterable = {1, 2, 3};
        final setIterableSignal = setIterable.toIterableSignal();
        expect(setIterableSignal.value, equals({1, 2, 3}));

        // Map values iterable
        final map = {"a": 1, "b": 2};
        final mapValuesIterableSignal = map.values.toIterableSignal();
        expect(mapValuesIterableSignal.value, equals([1, 2]));

        // Map keys iterable
        final mapKeysIterableSignal = map.keys.toIterableSignal();
        expect(mapKeysIterableSignal.value, equals(["a", "b"]));

        // Empty iterable
        final emptyIterable = <int>[];
        final emptyIterableSignal = emptyIterable.toIterableSignal();
        expect(emptyIterableSignal.value, equals([]));
      });

      test("should work with custom objects", () {
        final personIterable = [TestPerson("Alice", 30), TestPerson("Bob", 25)];
        final personIterableSignal = personIterable.toIterableSignal();

        expect(
          personIterableSignal.value,
          equals([TestPerson("Alice", 30), TestPerson("Bob", 25)]),
        );
      });

      test("should be reactive", () {
        final iterable = [1, 2, 3];
        final iterableSignal = iterable.toIterableSignal();
        final values = <Iterable<int>>[];

        Effect(() {
          values.add(iterableSignal.value);
        });

        expect(
          values,
          equals([
            [1, 2, 3],
          ]),
        );
      });
    });

    group("JoltFutureExtension", () {
      test("should convert future to async signal", () async {
        final future = Future.value(42);
        final futureSignal = future.toAsyncSignal();

        expect(futureSignal, isA<AsyncSignal<int>>());
        expect(futureSignal.value, isA<AsyncLoading<int>>());

        await Future.delayed(const Duration(milliseconds: 1));

        expect(futureSignal.value, isA<AsyncSuccess<int>>());
        expect(futureSignal.data, equals(42));
      });

      test("should work with different future types", () async {
        // String future
        final stringFuture = Future.value("hello");
        final stringFutureSignal = stringFuture.toAsyncSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(stringFutureSignal.data, equals("hello"));

        // List future
        final listFuture = Future.value([1, 2, 3]);
        final listFutureSignal = listFuture.toAsyncSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(listFutureSignal.data, equals([1, 2, 3]));

        // Nullable future
        final nullableFuture = Future<int?>.value(null);
        final nullableFutureSignal = nullableFuture.toAsyncSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(nullableFutureSignal.data, isNull);
      });

      test("should handle future errors", () async {
        final errorFuture = Future<int>.error(Exception("Test error"));
        final errorFutureSignal = errorFuture.toAsyncSignal();

        expect(errorFutureSignal.value, isA<AsyncLoading<int>>());

        await Future.delayed(const Duration(milliseconds: 1));

        expect(errorFutureSignal.value, isA<AsyncError<int>>());
        expect(errorFutureSignal.data, isNull);
        expect(errorFutureSignal.value.error, isA<Exception>());
      });

      test("should work with custom objects", () async {
        final personFuture = Future.value(TestPerson("Alice", 30));
        final personFutureSignal = personFuture.toAsyncSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(personFutureSignal.data, equals(TestPerson("Alice", 30)));
      });
    });

    group("JoltStreamExtension", () {
      test("should convert stream to async signal", () async {
        final stream = Stream.value(42);
        final streamSignal = stream.toStreamSignal();

        expect(streamSignal, isA<AsyncSignal<int>>());
        expect(streamSignal.value, isA<AsyncLoading<int>>());

        await Future.delayed(const Duration(milliseconds: 1));

        expect(streamSignal.value, isA<AsyncSuccess<int>>());
        expect(streamSignal.data, equals(42));
      });

      test("should work with different stream types", () async {
        // String stream
        final stringStream = Stream.value("hello");
        final stringStreamSignal = stringStream.toStreamSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(stringStreamSignal.data, equals("hello"));

        // List stream
        final listStream = Stream.value([1, 2, 3]);
        final listStreamSignal = listStream.toStreamSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(listStreamSignal.data, equals([1, 2, 3]));

        // Nullable stream
        final nullableStream = Stream<int?>.value(null);
        final nullableStreamSignal = nullableStream.toStreamSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(nullableStreamSignal.data, isNull);
      });

      test("should handle stream errors", () async {
        final errorStream = Stream<int>.error(Exception("Test error"));
        final errorStreamSignal = errorStream.toStreamSignal();

        expect(errorStreamSignal.value, isA<AsyncLoading<int>>());

        await Future.delayed(const Duration(milliseconds: 1));

        expect(errorStreamSignal.value, isA<AsyncError<int>>());
        expect(errorStreamSignal.data, isNull);
        expect(errorStreamSignal.value.error, isA<Exception>());
      });

      test("should handle multiple stream values", () async {
        final stream = Stream.fromIterable(["hello", "world"]);
        final streamSignal = stream.toStreamSignal();
        final values = <String>[];

        streamSignal.listen((state) {
          if (state.isSuccess) {
            values.add(state.data!);
          }
        }, immediately: true);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(values.length, greaterThanOrEqualTo(2));
        expect(values, contains("hello"));
        expect(values, contains("world"));
      });

      test("should work with custom objects", () async {
        final personStream = Stream.value(TestPerson("Alice", 30));
        final personStreamSignal = personStream.toStreamSignal();

        await Future.delayed(const Duration(milliseconds: 1));
        expect(personStreamSignal.data, equals(TestPerson("Alice", 30)));
      });
    });

    group("Extension integration tests", () {
      test("should work with computed", () {
        final list = [1, 2, 3];
        final listSignal = list.toListSignal();
        final computed = Computed<int>(
          () => listSignal.fold(0, (sum, value) => sum + value),
        );

        expect(computed.value, equals(6));

        listSignal.add(4);
        expect(computed.value, equals(10));
      });

      test("should work with effect", () {
        final map = {"a": 1};
        final mapSignal = map.toMapSignal();
        final values = <Map<String, int>>[];

        Effect(() {
          values.add(Map.from(mapSignal.value));
        });

        expect(
          values,
          equals([
            {"a": 1},
          ]),
        );

        mapSignal["b"] = 2;
        expect(
          values,
          equals([
            {"a": 1},
            {"a": 1, "b": 2},
          ]),
        );
      });

      test("should work with batch updates", () {
        final set = {1, 2};
        final setSignal = set.toSetSignal();
        final values = <Set<int>>[];

        Effect(() {
          values.add(Set.from(setSignal.value));
        });

        expect(
          values,
          equals([
            {1, 2},
          ]),
        );

        batch(() {
          setSignal
            ..add(3)
            ..add(4)
            ..remove(1);
        });

        // 批处理中只应该触发一次更新
        expect(
          values,
          equals([
            {1, 2},
            {2, 3, 4},
          ]),
        );
      });

      test("should work with async operations", () async {
        final future = Future.value(42);
        final futureSignal = future.toAsyncSignal();
        final states = <String>[];

        Effect(() {
          final state = futureSignal.value.map(
                loading: () => "loading",
                success: (data) => "success: $data",
                error: (error, stackTrace) => "error: $error",
              ) ??
              "unknown";
          states.add(state);
        });

        expect(states, equals(["loading"]));

        await Future.delayed(const Duration(milliseconds: 1));

        expect(states, equals(["loading", "success: 42"]));
      });

      test("should not work with chained extensions", () {
        final list = [1, 2, 3];
        final listSignal = list.toListSignal();
        final computed = Computed<int>(
          () => listSignal.fold(0, (sum, value) => sum + value),
        );
        final computedSignal = computed.value.toSignal();

        expect(computedSignal.value, equals(6));

        listSignal.add(4);
        expect(computedSignal.value, equals(6));
      });
    });
  });
}
