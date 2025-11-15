import "dart:async";
import "dart:convert";
import "dart:io";

import "package:jolt/jolt.dart";
import "package:jolt/tricks.dart";
import "package:test/test.dart";

void main() {
  group("Tricks Tests", () {
    group("ConvertComputed", () {
      test("Basic type conversion", () {
        final source = Signal("42");
        final converted = ConvertComputed<int, String>(
          source,
          decode: int.parse,
          encode: (value) => value.toString(),
        );

        expect(converted.value, equals(42));
        expect(source.value, equals("42"));

        // Change through converted signal
        converted.value = 100;
        expect(converted.value, equals(100));
        expect(source.value, equals("100"));
      });

      test("Reactive updates through conversion", () {
        final source = Signal("10");
        final converted = ConvertComputed<int, String>(
          source,
          decode: int.parse,
          encode: (value) => value.toString(),
        );

        final changes = <int>[];
        Effect(() {
          changes.add(converted.value);
        });

        // Initial value
        expect(changes, equals([10]));

        // Change source
        source.value = "20";
        expect(changes, equals([10, 20]));
        expect(converted.value, equals(20));

        // Change through converted
        converted.value = 30;
        expect(changes, equals([10, 20, 30]));
        expect(source.value, equals("30"));
      });

      test("Complex type conversion", () {
        final source = Signal({"name": "Alice", "age": "25"});
        final converted =
            ConvertComputed<Map<String, dynamic>, Map<String, String>>(
          source,
          decode: (value) => {
            "name": value["name"],
            "age": int.parse(value["age"]!),
          },
          encode: (value) => {
            "name": value["name"]!,
            "age": value["age"].toString(),
          },
        );

        expect(converted.value, equals({"name": "Alice", "age": 25}));

        // Change through converted
        converted.value = {"name": "Bob", "age": 30};
        expect(source.value, equals({"name": "Bob", "age": "30"}));
      });

      test("Error handling in conversion", () {
        final source = Signal("invalid");
        final converted = ConvertComputed<int, String>(
          source,
          decode: int.parse,
          encode: (value) => value.toString(),
        );

        // Should throw on invalid input
        expect(() => converted.value, throwsA(isA<FormatException>()));
      });
    });

    group("PersistSignal", () {
      test("Basic persistence with immediate write", () async {
        final storage = <String, String>{};

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) async => storage["key"] = value,
        );

        // Should have initial value
        expect(persistSignal.value, equals("initial"));

        // Change value should persist
        persistSignal.value = "updated";
        await Future.delayed(const Duration(milliseconds: 10));
        expect(storage["key"], equals("updated"));
      });

      test("Lazy loading", () async {
        final storage = <String, String>{};
        storage["key"] = "persisted_value";

        final persistSignal = PersistSignal.lazy(
          read: () async => storage["key"]!,
          write: (value) async => storage["key"] = value,
        );

        // Should not be initialized yet
        expect(persistSignal.hasInitialized, isFalse);

        // Accessing value should trigger load
        final value = await persistSignal.getEnsured();
        expect(value, equals("persisted_value"));
        expect(persistSignal.hasInitialized, isTrue);
      });

      test("Lazy initial value factory", () {
        var factoryCallCount = 0;

        final persistSignal = PersistSignal<String>(
          initialValue: () {
            factoryCallCount++;
            return "factory_value_$factoryCallCount";
          },
          read: () async => "stored_value",
          write: (value) async {},
        );

        // Factory should be called once during construction
        expect(factoryCallCount, equals(1));
        expect(persistSignal.value, equals("factory_value_1"));
      });

      test("Lazy initial value factory with lazy loading", () async {
        var factoryCallCount = 0;

        final persistSignal = PersistSignal.lazy(
          initialValue: () {
            factoryCallCount++;
            return "factory_value_$factoryCallCount";
          },
          read: () async => "stored_value",
          write: (value) async {},
        );

        // Factory should be called during construction even in lazy mode
        expect(factoryCallCount, equals(1));
        expect(persistSignal.hasInitialized, isFalse);

        // Accessing value should load from read function, not initialValue
        final value = await persistSignal.getEnsured();
        expect(factoryCallCount, equals(1));
        expect(value, equals("stored_value"));
        expect(persistSignal.hasInitialized, isTrue);
      });

      test("Initial value factory with complex objects", () {
        var factoryCallCount = 0;

        final persistSignal = PersistSignal<Map<String, dynamic>>(
          initialValue: () {
            factoryCallCount++;
            return {
              "id": factoryCallCount,
              "name": "User_$factoryCallCount",
              "created": DateTime.now().toIso8601String(),
            };
          },
          read: () => {"id": 0, "name": "Default"},
          write: (value) async {},
        );

        // Factory should be called once
        expect(factoryCallCount, equals(1));
        expect(persistSignal.value["id"], equals(1));
        expect(persistSignal.value["name"], equals("User_1"));
        expect(persistSignal.value["created"], isNotNull);
      });

      test("Version control for concurrent loads with variable delays",
          () async {
        final storage = <String, String>{};
        storage["key"] = "final_value";
        var readCallCount = 0;

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            // Simulate variable delay - some calls are faster, some slower
            final delay = readCallCount == 1 ? 100 : 50;
            await Future.delayed(Duration(milliseconds: delay));
            return storage["key"]!;
          },
          write: (value) => storage["key"] = value,
        );

        // Start multiple concurrent loads
        final futures = <Future<String>>[];
        for (var i = 0; i < 5; i++) {
          futures.add(persistSignal.getEnsured());
        }

        // All should return the same value regardless of completion order
        final results = await Future.wait(futures);
        expect(results, everyElement(equals("final_value")));
        expect(
            readCallCount, equals(1)); // Only one read should actually execute
      });

      test("Version control with rapid successive loads", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        final readTimes = <DateTime>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            readTimes.add(DateTime.now());
            // Simulate slow read
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async => storage["key"] = value,
        );

        // Start first load
        final future1 = persistSignal.getEnsured();

        // Start second load immediately (before first completes)
        await Future.delayed(const Duration(milliseconds: 10));
        final future2 = persistSignal.getEnsured();

        // Start third load after a short delay
        await Future.delayed(const Duration(milliseconds: 20));
        final future3 = persistSignal.getEnsured();

        // All should return the same value
        final results = await Future.wait([future1, future2, future3]);
        expect(results, everyElement(equals("initial_value")));
        expect(readCallCount, equals(1)); // Only one read should execute
      });

      test("Version control with changing values during load", () async {
        final storage = <String, String>{};
        storage["key"] = "value_1";
        var readCallCount = 0;

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            // Simulate slow read that takes time
            await Future.delayed(const Duration(milliseconds: 50));
            return storage["key"]!;
          },
          write: (value) async => storage["key"] = value,
        );

        // Start load
        final future1 = persistSignal.getEnsured();

        // Change value while loading
        await Future.delayed(const Duration(milliseconds: 25));
        storage["key"] = "value_2";

        // Start another load after value change
        final future2 = persistSignal.getEnsured();

        // Both should return the same value (from the shared load)
        final results = await Future.wait([future1, future2]);
        expect(results,
            everyElement(equals("value_2"))); // Should get the latest value
        expect(readCallCount, equals(1)); // Only one read should execute
      });

      test("Version control with multiple rapid changes", () async {
        final storage = <String, String>{};
        storage["key"] = "initial";
        var readCallCount = 0;
        final readResults = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 30));
            final result = storage["key"]!;
            readResults.add(result);
            return result;
          },
          write: (value) async => storage["key"] = value,
        );

        // Start multiple loads rapidly
        final futures = <Future<String>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(persistSignal.getEnsured());
        }

        storage["key"] = "changed";

        final results = await Future.wait(futures);

        expect(results, everyElement(equals("changed")));
        expect(readCallCount, equals(1));
        expect(readResults, equals(["changed"]));
      });

      test("Version control with error handling", () async {
        final storage = <String, String>{};
        storage["key"] = "success_value";
        var readCallCount = 0;

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 30));
            throw Exception("Read failed");
          },
          write: (value) async => storage["key"] = value! as String,
        );

        // Start multiple loads that will all fail
        final futures = <Future<String>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(persistSignal.getEnsured());
        }

        // All should fail because they share the same load
        for (final future in futures) {
          expect(() async => future, throwsA(isA<Exception>()));
        }
        // Wait a bit to ensure the read function has been called
        await Future.delayed(const Duration(milliseconds: 50));
        expect(readCallCount, equals(1)); // Only one read should execute
      });

      test("Version control with cancellation simulation", () async {
        final storage = <String, String>{};
        storage["key"] = "final_value";
        var readCallCount = 0;
        final readVersions = <int>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            final version = readCallCount;
            readVersions.add(version);

            // Simulate different delays for different versions
            await Future.delayed(Duration(milliseconds: version * 20));
            return '${storage['key']}_v$version';
          },
          write: (value) => storage["key"] = value,
        );

        // Start multiple loads with different timing
        final futures = <Future<String>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(persistSignal.getEnsured());
          await Future.delayed(const Duration(milliseconds: 5));
        }

        final results = await Future.wait(futures);

        // All should return the same result (from the first successful load)
        expect(results, everyElement(equals("final_value_v1")));
        expect(readCallCount, equals(1)); // Only first version should complete
        expect(readVersions, equals([1]));
      });

      test("Write during load - version control", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            // Simulate slow read
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            storage["key"] = value;
          },
        );

        // Start load
        final loadFuture = persistSignal.getEnsured();

        // Write new value while loading
        await Future.delayed(const Duration(milliseconds: 50));
        persistSignal.value = "written_during_load";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Should get the value that was written during load (write affects storage)
        expect(loadedValue, equals("written_during_load"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(1));
        expect(writeValues, equals(["written_during_load"]));
      });

      test("Multiple writes during load - latest write wins", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            storage["key"] = value;
          },
        );

        // Start load
        final loadFuture = persistSignal.getEnsured();

        // Multiple writes during load
        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "write_1";

        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "write_2";

        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "write_3";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Should get the latest value that was written during load
        expect(loadedValue, equals("write_3"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(3));
        expect(writeValues, equals(["write_1", "write_2", "write_3"]));
      });

      test("Write with delay during load - latest write preserved", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            // Simulate slow write
            await Future.delayed(const Duration(milliseconds: 30));
            storage["key"] = value;
          },
        );

        // Start load
        final loadFuture = persistSignal.getEnsured();

        // Write with delay during load
        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "delayed_write_1";

        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "delayed_write_2";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Wait for all writes to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Should get the latest value that was written during load
        expect(loadedValue, equals("delayed_write_2"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(2));
        expect(writeValues, equals(["delayed_write_1", "delayed_write_2"]));

        // Final value should be the latest write
        expect(storage["key"], equals("delayed_write_2"));
      });

      test("Write cancellation during load - timer management", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            storage["key"] = value;
          },
          writeDelay: const Duration(milliseconds: 50),
        );

        // Start load
        final loadFuture = persistSignal.getEnsured();

        // Multiple writes with delay during load
        await Future.delayed(const Duration(milliseconds: 10));
        persistSignal.value = "write_1";

        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "write_2";

        await Future.delayed(const Duration(milliseconds: 20));
        persistSignal.value = "write_3";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Wait for delayed write to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Should get the latest value that was written during load
        expect(loadedValue, equals("write_3"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(1)); // Only the last write should execute
        expect(writeValues, equals(["write_3"]));
        expect(storage["key"], equals("write_3"));
      });

      test("Load completion after write - value consistency", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            storage["key"] = value;
          },
        );

        // Start load
        final loadFuture = persistSignal.getEnsured();

        // Write during load
        await Future.delayed(const Duration(milliseconds: 50));
        persistSignal.value = "written_during_load";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Write after load completion
        persistSignal.value = "written_after_load";

        // Wait for all operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        // Should get the value that was written during load
        expect(loadedValue, equals("written_during_load"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(2));
        expect(
            writeValues, equals(["written_during_load", "written_after_load"]));
        expect(storage["key"], equals("written_after_load"));
      });

      test("Concurrent load and write - race condition handling", () async {
        final storage = <String, String>{};
        storage["key"] = "initial_value";
        var readCallCount = 0;
        var writeCallCount = 0;
        final writeValues = <String>[];

        final persistSignal = PersistSignal.lazy(
          read: () async {
            readCallCount++;
            await Future.delayed(const Duration(milliseconds: 50));
            return storage["key"]!;
          },
          write: (value) async {
            writeCallCount++;
            writeValues.add(value);
            storage["key"] = value;
          },
        );

        // Start multiple operations concurrently
        final loadFuture = persistSignal.getEnsured();
        persistSignal.value = "concurrent_write";

        // Wait for load to complete
        final loadedValue = await loadFuture;

        // Wait for write to complete
        await Future.delayed(const Duration(milliseconds: 10));

        // Should get the value that was written concurrently
        expect(loadedValue, equals("concurrent_write"));
        expect(readCallCount, equals(1));
        expect(writeCallCount, equals(1));
        expect(writeValues, equals(["concurrent_write"]));
        expect(storage["key"], equals("concurrent_write"));
      });

      test("Delayed write with writeDelay", () async {
        final storage = <String, String>{};
        final writeTimes = <String>[];

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) async {
            writeTimes.add(value);
            storage["key"] = value;
          },
          writeDelay: const Duration(milliseconds: 100),
        );

        // Change value multiple times quickly
        persistSignal.value = "first";
        persistSignal.value = "second";
        persistSignal.value = "third";

        // Should not have written yet
        expect(writeTimes, isEmpty);

        // Wait for delay
        await Future.delayed(const Duration(milliseconds: 150));
        expect(
            writeTimes, equals(["third"])); // Only last value should be written
      });

      test("Reactive updates with persistence", () async {
        final storage = <String, int>{};

        final persistSignal = PersistSignal<int>(
          initialValue: () => 0,
          read: () async => storage["counter"] ?? 0,
          write: (value) async => storage["counter"] = value,
        );

        final changes = <int>[];
        Effect(() {
          changes.add(persistSignal.value);
        });

        // Initial value
        expect(changes, equals([0]));

        // Change value
        persistSignal.value = 5;
        expect(changes, equals([0, 5]));

        // Wait for persistence
        await Future.delayed(const Duration(milliseconds: 10));
        expect(storage["counter"], equals(5));
      });

      test("Ensure initialized callback", () async {
        final storage = <String, String>{};
        storage["key"] = "loaded_value";

        final persistSignal = PersistSignal.lazy(
          read: () async => storage["key"]!,
          write: (value) async => storage["key"] = value,
        );

        final callbacks = <String>[];

        await persistSignal.ensure(() {
          callbacks.add("callback_executed");
        });

        expect(callbacks, equals(["callback_executed"]));
        expect(persistSignal.hasInitialized, isTrue);
      });

      test("JSON persistence example", () async {
        final storage = <String, String>{};

        final persistSignal = PersistSignal<Map<String, dynamic>>(
          initialValue: () => {"count": 0},
          read: () async {
            final json = storage["data"];
            return json != null ? jsonDecode(json) : {"count": 0};
          },
          write: (value) async => storage["data"] = jsonEncode(value),
        );

        // Initial value
        expect(persistSignal.value, equals({"count": 0}));

        // Update value
        persistSignal.value = {"count": 5, "name": "test"};
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify persistence
        expect(storage["data"], equals('{"count":5,"name":"test"}'));
      });

      test("File persistence example", () async {
        final tempFile = File("test_persist.json");

        try {
          final persistSignal = PersistSignal<String>(
            initialValue: () => "Hello World",
            read: () async {
              if (await tempFile.exists()) {
                return tempFile.readAsString();
              }
              return "Hello World";
            },
            write: (value) async => tempFile.writeAsString(value),
          );

          // Initial value
          expect(persistSignal.value, equals("Hello World"));

          // Update value
          persistSignal.value = "Updated Content";
          await Future.delayed(const Duration(milliseconds: 10));

          // Verify file was written
          expect(await tempFile.exists(), isTrue);
          expect(await tempFile.readAsString(), equals("Updated Content"));
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });

      test("write error does not affect signal value - synchronous error", () {
        final storage = <String, String>{};
        var writeThrew = false;

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) {
            writeThrew = true;
            throw Exception("Write failed");
          },
        );

        // Value should be set even if write throws
        // Note: synchronous write errors will throw, but super.set() is called first
        try {
          persistSignal.value = "updated";
        } catch (e) {
          // Exception is expected, but value should still be set
        }
        expect(persistSignal.value, equals("updated"));
        expect(writeThrew, isTrue);

        // Storage should not be updated due to error
        expect(storage["key"], isNull);
      });

      test("write error does not affect signal value - async error", () async {
        final storage = <String, String>{};
        var writeThrew = false;

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) async {
            writeThrew = true;
            await Future.delayed(const Duration(milliseconds: 10));
            throw Exception("Async write failed");
          },
        );

        persistSignal.value = "updated";

        expect(persistSignal.peek, equals("updated"));
        expect(persistSignal.value, equals("updated"));

        await Future.delayed(const Duration(milliseconds: 20));
        expect(writeThrew, isTrue);

        expect(persistSignal.peek, equals("updated"));
        expect(persistSignal.value, equals("updated"));

        expect(storage["key"], isNull);
      });

      test("write error does not affect signal value - with writeDelay",
          () async {
        final storage = <String, String>{};
        var writeThrew = false;

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) async {
            writeThrew = true;
            throw Exception("Delayed write failed");
          },
          writeDelay: const Duration(milliseconds: 50),
        );

        // Value should be set immediately (before delayed write executes)
        persistSignal.value = "updated";
        // Use peek to verify internal value directly
        expect(persistSignal.peek, equals("updated"));
        expect(persistSignal.value, equals("updated"));
        expect(writeThrew, isFalse);

        // Wait for delayed write to execute and fail
        await Future.delayed(const Duration(milliseconds: 100));
        expect(writeThrew, isTrue);

        // Signal value should still be correct (not affected by delayed write error)
        expect(persistSignal.peek, equals("updated"));
        expect(persistSignal.value, equals("updated"));
        // Storage should not be updated due to error
        expect(storage["key"], isNull);
      });

      test("write error does not affect signal value - multiple writes",
          () async {
        final storage = <String, String>{};
        var writeCallCount = 0;
        var shouldThrow = false;

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) async {
            writeCallCount++;
            if (shouldThrow) {
              throw Exception("Write failed for $value");
            }
            storage["key"] = value;
          },
        );

        // First write succeeds
        persistSignal.value = "first";
        await Future.delayed(const Duration(milliseconds: 10));
        expect(persistSignal.value, equals("first"));
        expect(storage["key"], equals("first"));
        expect(writeCallCount, equals(1));

        // Second write fails, but signal value should still be set
        shouldThrow = true;
        try {
          persistSignal.value = "second";
        } catch (e) {
          // Exception is expected for sync errors
        }
        expect(persistSignal.value, equals("second"));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(persistSignal.value, equals("second"));
        // Storage should still have old value
        expect(storage["key"], equals("first"));
        expect(writeCallCount, equals(2));

        // Third write succeeds again
        shouldThrow = false;
        persistSignal.value = "third";
        await Future.delayed(const Duration(milliseconds: 10));
        expect(persistSignal.value, equals("third"));
        expect(storage["key"], equals("third"));
        expect(writeCallCount, equals(3));
      });

      test("write error does not affect reactive updates", () {
        final storage = <String, String>{};
        final changes = <String>[];

        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) {
            throw Exception("Write failed");
          },
        );

        Effect(() {
          changes.add(persistSignal.value);
        });

        expect(changes, equals(["initial"]));

        // Value should update and trigger reactive updates even if write fails
        try {
          persistSignal.value = "updated";
        } catch (e) {
          // Exception is expected for sync errors
        }
        expect(changes, equals(["initial", "updated"]));
        expect(persistSignal.value, equals("updated"));
      });
    });

    group("setEnsured", () {
      test("should rollback on write failure in optimistic mode", () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) {
            if (value == "fail") throw Exception("Write failed");
            storage["key"] = value;
          },
        );

        expect(persistSignal.value, equals("initial"));

        // Successful write
        final success =
            await persistSignal.setEnsured("success", optimistic: true);
        expect(success, isTrue);
        expect(persistSignal.value, equals("success"));
        expect(storage["key"], equals("success"));

        // Failed write should rollback
        final failed = await persistSignal.setEnsured("fail", optimistic: true);
        expect(failed, isFalse);
        expect(persistSignal.value, equals("success")); // Rolled back
        expect(storage["key"], equals("success")); // Not updated
      });

      test("should not set value on write failure in non-optimistic mode",
          () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) {
            if (value == "fail") throw Exception("Write failed");
            storage["key"] = value;
          },
        );

        expect(persistSignal.value, equals("initial"));

        // Failed write should not update signal
        final failed =
            await persistSignal.setEnsured("fail", optimistic: false);
        expect(failed, isFalse);
        expect(persistSignal.value, equals("initial")); // Not updated
        expect(storage["key"], isNull); // Not written

        // Successful write should update signal
        final success =
            await persistSignal.setEnsured("success", optimistic: false);
        expect(success, isTrue);
        expect(persistSignal.value, equals("success"));
        expect(storage["key"], equals("success"));
      });

      test("should wait for regular set writes before setEnsured", () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 50));
            storage["key"] = value;
          },
        );

        // Start a regular set (async write)
        persistSignal.value = "regular";
        expect(persistSignal.value, equals("regular"));

        // setEnsured should wait for regular set to complete
        final result =
            await persistSignal.setEnsured("ensured", optimistic: false);
        expect(result, isTrue);
        expect(
            storage["key"], equals("ensured")); // Ensured write should be last
        expect(persistSignal.value, equals("ensured"));
      });

      test("should handle rollback correctly when regular set intervenes",
          () async {
        final storage = <String, String>{};
        var shouldFail = false;
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 30));
            if (shouldFail) throw Exception("Write failed");
            storage["key"] = value;
          },
        );

        expect(persistSignal.value, equals("initial"));

        // Start optimistic setEnsured that will fail
        shouldFail = true;
        final setEnsuredFuture =
            persistSignal.setEnsured("fail", optimistic: true);

        // In optimistic mode, value should be set immediately after await _waitForWrites
        // But since it's async, we need to wait a bit for the value to be set
        await Future.delayed(const Duration(milliseconds: 5));
        expect(persistSignal.value, equals("fail")); // Optimistically set

        // Regular set intervenes during write
        persistSignal.value = "regular";
        expect(persistSignal.value, equals("regular"));

        // Wait for setEnsured to fail
        final failed = await setEnsuredFuture;
        expect(failed, isFalse);

        // Should not rollback because regular set intervened (version changed)
        expect(persistSignal.value, equals("regular")); // Kept regular value
        expect(storage["key"], isNull); // Nothing written yet
      });

      test("should handle load correctly when writes are in progress",
          () async {
        final storage = <String, String>{};
        storage["key"] = "stored_value";

        final persistSignal = PersistSignal<String>.lazy(
          read: () async {
            await Future.delayed(const Duration(milliseconds: 50));
            return storage["key"] ?? "default";
          },
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 50));
            storage["key"] = value;
          },
        );

        // Start a regular set (async write)
        persistSignal.value = "written";
        expect(persistSignal.value, equals("written"));

        // Load should wait for write to complete
        final loaded = await persistSignal.getEnsured();
        expect(loaded, equals("written")); // Should get the value after write
      });

      test("should handle multiple setEnsured operations correctly", () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 20));
            storage["key"] = value;
          },
        );

        // Start multiple setEnsured operations
        final future1 = persistSignal.setEnsured("value1", optimistic: false);
        final future2 = persistSignal.setEnsured("value2", optimistic: false);

        final results = await Future.wait([future1, future2]);
        expect(results[0], isTrue);
        expect(results[1], isTrue);

        // Last write should win
        expect(storage["key"], equals("value2"));
        expect(persistSignal.value, equals("value2"));
      });

      test("should handle optimistic rollback with concurrent regular set",
          () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () => storage["key"] ?? "default",
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 30));
            if (value == "fail") throw Exception("Write failed");
            storage["key"] = value;
          },
        );

        // Start optimistic setEnsured that will fail
        final setEnsuredFuture =
            persistSignal.setEnsured("fail", optimistic: true);

        // Wait a bit for optimistic value to be set
        await Future.delayed(const Duration(milliseconds: 5));
        expect(persistSignal.value, equals("fail")); // Optimistically set

        // Regular set intervenes
        persistSignal.value = "regular";
        expect(persistSignal.value, equals("regular"));

        // Wait for setEnsured to complete
        final failed = await setEnsuredFuture;
        expect(failed, isFalse);

        // Should not rollback because regular set changed version
        expect(persistSignal.value, equals("regular"));
      });

      test("should handle rollback correctly when load intervenes", () async {
        final storage = <String, String>{};
        storage["key"] = "loaded_value";

        final persistSignal = PersistSignal<String>.lazy(
          read: () async {
            await Future.delayed(const Duration(milliseconds: 40));
            return storage["key"] ?? "default";
          },
          write: (value) async {
            await Future.delayed(const Duration(milliseconds: 40));
            if (value == "fail") throw Exception("Write failed");
            storage["key"] = value;
          },
        );

        // Wait for initial load
        await persistSignal.getEnsured();
        expect(persistSignal.value, equals("loaded_value"));

        // Start optimistic setEnsured that will fail
        final setEnsuredFuture =
            persistSignal.setEnsured("fail", optimistic: true);

        // Wait a bit for optimistic value to be set
        await Future.delayed(const Duration(milliseconds: 5));
        expect(persistSignal.value, equals("fail")); // Optimistically set

        // Load intervenes during write - it will wait for write to complete
        // But since hasInitialized is true, getEnsured won't reload from storage
        // It will just return the current value after waiting for writes
        final loadFuture = persistSignal.getEnsured();

        // Wait for both operations
        final results = await Future.wait([setEnsuredFuture, loadFuture]);
        expect(results[0], isFalse); // setEnsured failed

        // Load waited for write to complete, but since hasInitialized is true,
        // it won't reload from storage, so it returns the current optimistic value
        // However, setEnsured failed, so optimistic value should be rolled back
        // But if load happens before rollback, we get the optimistic value
        final loaded = results[1];
        // The actual behavior: load waits for writes, then returns current value
        // Since optimistic value was set, we get 'fail' (but setEnsured will rollback after)
        // Actually, load might complete before setEnsured's rollback
        expect(loaded, anyOf(["fail", "loaded_value"])); // Could be either
        // After both complete, value should be rolled back or loaded value
        await Future.delayed(const Duration(milliseconds: 50));
        expect(persistSignal.value,
            equals("loaded_value")); // Eventually rolled back or loaded
      });

      test("should handle optimistic mode with writeDelay", () async {
        final storage = <String, String>{};
        final persistSignal = PersistSignal<String>(
          initialValue: () => "initial",
          read: () async => storage["key"] ?? "default",
          write: (value) {
            if (value == "fail") throw Exception("Write failed");
            storage["key"] = value;
          },
          writeDelay: const Duration(milliseconds: 50),
        );

        expect(persistSignal.value, equals("initial"));

        // Successful write with delay
        final success =
            await persistSignal.setEnsured("success", optimistic: true);
        expect(success, isTrue);
        expect(persistSignal.value, equals("success"));
        await Future.delayed(const Duration(milliseconds: 60));
        expect(storage["key"], equals("success"));

        // Failed write with delay should rollback
        final failed = await persistSignal.setEnsured("fail", optimistic: true);
        expect(failed, isFalse);
        expect(persistSignal.value, equals("success")); // Rolled back
        await Future.delayed(const Duration(milliseconds: 60));
        expect(storage["key"], equals("success")); // Not updated
      });
    });

    group("Tricks Integration", () {
      test("ConvertComputed with PersistSignal", () async {
        final storage = <String, String>{};

        // PersistSignal for string storage
        final persistSignal = PersistSignal<String>(
          initialValue: () => "0",
          read: () => storage["counter"] ?? "0",
          write: (value) => storage["counter"] = value,
        );

        // ConvertComputed to work with integers
        final counter = ConvertComputed<int, String>(
          persistSignal,
          decode: int.parse,
          encode: (value) => value.toString(),
        );

        // Initial value
        expect(counter.value, equals(0));

        // Update counter
        counter.value = 42;
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify persistence
        expect(storage["counter"], equals("42"));
        expect(counter.value, equals(42));

        // Create new instance to test loading
        final newPersistSignal = PersistSignal.lazy(
          read: () => storage["counter"]!,
          write: (value) => storage["counter"] = value,
        );

        // Should load persisted value
        final loadedValue = await newPersistSignal.getEnsured();
        expect(int.parse(loadedValue), equals(42));
      });

      test("Reactive chain with tricks", () async {
        final source = Signal(10);
        final converted = ConvertComputed<String, int>(
          source,
          decode: (value) => value.toString(),
          encode: int.parse,
        );

        final persistSignal = PersistSignal<String>(
          initialValue: () => converted.value,
          read: () => converted.value,
          write: (value) => converted.value = value,
        );

        final changes = <String>[];
        Effect(() {
          changes.add(persistSignal.value);
        });

        // Initial value
        expect(changes, equals(["10"]));

        // Change source
        source.value = 20;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(changes, equals(["10", "20"]));
        expect(persistSignal.value, equals("20"));

        // Change through persistSignal
        persistSignal.value = "30";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(changes, equals(["10", "20", "30"]));
        expect(source.value, equals(30));
      });
    });
  });
}
