import "dart:async";

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

        expect(changes, equals([10]));

        source.value = "20";
        expect(changes, equals([10, 20]));
        expect(converted.value, equals(20));

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

        expect(() => converted.value, throwsA(isA<FormatException>()));
      });
    });

    group("PersistSignal", () {
      // Mock storage for testing
      Map<String, dynamic> createMockStorage([Map<String, dynamic>? initial]) {
        final storage = <String, dynamic>{...?initial};
        return storage;
      }

      group("SyncPersistSignalImpl", () {
        test("Basic immediate initialization", () {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("value"));
        });

        test("Basic lazy initialization", () {
          final storage = createMockStorage({"key": "lazy"});
          final signal = PersistSignal.lazySync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isFalse);
          expect(signal.value, equals("lazy"));
          expect(signal.isInitialized, isTrue);
        });

        test("Set value before initialization triggers lazy load", () {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.lazySync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isFalse);

          // Set value before reading - should trigger initialization
          signal.value = "new";

          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("new"));
          expect(storage["key"], equals("new"));
        });

        test(
            "Set value before initialization loads from storage then overwrites",
            () {
          final storage = createMockStorage({"key": "loaded"});
          bool readCalled = false;
          final signal = PersistSignal.lazySync(
            read: () {
              readCalled = true;
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isFalse);
          expect(readCalled, isFalse);

          // Set value before reading - should load from storage first, then overwrite
          signal.value = "overwritten";

          expect(readCalled, isTrue,
              reason: "read should be called during initialization");
          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("overwritten"),
              reason: "new value should overwrite loaded value");
          expect(storage["key"], equals("overwritten"),
              reason: "storage should be updated with new value");
        });

        test("Write value saves to storage", () {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          signal.value = "new";
          expect(signal.value, equals("new"));
          expect(storage["key"], equals("new"));
        });

        test("Write with sync write function", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
          );

          signal.value = "sync";
          await Future.delayed(Duration(milliseconds: 10));
          expect(writes, equals(["sync"]));
          expect(storage["key"], equals("sync"));
        });

        test("Write with async write function", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 10));
              writes.add(value);
              storage["key"] = value;
            },
          );

          signal.value = "async";
          await Future.delayed(Duration(milliseconds: 50));
          expect(writes, equals(["async"]));
          expect(storage["key"], equals("async"));
        });

        test("Write queue handles rapid writes", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 10));
              writes.add(value);
              storage["key"] = value;
            },
          );

          signal.value = "1";
          signal.value = "2";
          signal.value = "3";
          await Future.delayed(Duration(milliseconds: 100));
          expect(writes.length, greaterThanOrEqualTo(1));
          expect(writes.last, equals("3"));
          expect(storage["key"], equals("3"));
        });

        test("Throttle writes only last value", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
            throttle: Duration(milliseconds: 50),
          );

          signal.value = "1";
          signal.value = "2";
          signal.value = "3";
          await Future.delayed(Duration(milliseconds: 100));
          expect(writes.length, equals(1));
          expect(writes.first, equals("3"));
          expect(storage["key"], equals("3"));
        });

        test("Throttle trailing write", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
            throttle: Duration(milliseconds: 50),
          );

          signal.value = "1";
          await Future.delayed(Duration(milliseconds: 30));
          signal.value = "2";
          await Future.delayed(Duration(milliseconds: 30));
          signal.value = "3";
          await Future.delayed(Duration(milliseconds: 100));
          expect(writes.length, greaterThanOrEqualTo(1));
          expect(writes.last, equals("3"));
        });

        test("No throttle writes immediately", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
          );

          signal.value = "1";
          signal.value = "2";
          await Future.delayed(Duration(milliseconds: 10));
          expect(writes.length, greaterThanOrEqualTo(2));
        });

        test("ensureWrite waits for current write", () async {
          final storage = createMockStorage({"key": "initial"});
          bool writeCompleted = false;
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 50));
              storage["key"] = value;
              writeCompleted = true;
            },
          );

          signal.value = "new";
          await signal.ensureWrite();
          expect(writeCompleted, isTrue);
          expect(storage["key"], equals("new"));
        });

        test("ensureWrite waits for queued writes", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 20));
              writes.add(value);
              storage["key"] = value;
            },
          );

          signal.value = "1";
          signal.value = "2";
          await signal.ensureWrite();
          expect(writes.length, equals(2));
          expect(writes, equals(["1", "2"]));
        });

        test("ensureWrite waits for throttled write", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
            throttle: Duration(milliseconds: 50),
          );

          signal.value = "throttled";
          await signal.ensureWrite();
          expect(writes.length, equals(1));
          expect(writes.first, equals("throttled"));
        });

        test("Write error is silently ignored", () async {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) {
              throw Exception("Write error");
            },
          );

          signal.value = "new";
          expect(signal.value, equals("new")); // Optimistic update
          await Future.delayed(Duration(milliseconds: 10));
          expect(signal.value, equals("new")); // Value remains
        });

        test("getEnsured returns value immediately", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          final value = await signal.getEnsured();
          expect(value, equals("value"));
        });

        test("ensure executes callback", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          await signal.ensure((value) {
            callbackExecuted = true;
            expect(value, equals("value"));
          });
          expect(callbackExecuted, isTrue);
        });

        test("ensure with fn == null completes immediately", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          await signal.ensure();
          expect(signal.value, equals("value"));
        });

        test("ensure with fn returning void (non-Future)", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          await signal.ensure((value) {
            callbackExecuted = true;
            expect(value, equals("value"));
            // No return statement, returns void
          });
          expect(callbackExecuted, isTrue);
        });

        test("ensure with fn returning Future", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.sync(
            read: () => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          bool futureCompleted = false;
          await signal.ensure((value) async {
            callbackExecuted = true;
            expect(value, equals("value"));
            await Future.delayed(Duration(milliseconds: 10));
            futureCompleted = true;
          });
          expect(callbackExecuted, isTrue);
          expect(futureCompleted, isTrue);
        });
      });

      group("AsyncPersistSignalImpl", () {
        test("Basic immediate initialization", () async {
          final storage = createMockStorage({"key": "value"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 10));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isFalse);
          await Future.delayed(Duration(milliseconds: 50));
          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("value"));
        });

        test("Basic lazy initialization", () async {
          final storage = createMockStorage({"key": "lazy"});
          final signal = PersistSignal<String?>.lazyAsync(
            read: () async {
              await Future.delayed(Duration(milliseconds: 10));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          expect(signal.isInitialized, isFalse);

          signal.value; // Triggers lazy load, may be null initially
          await Future.delayed(Duration(milliseconds: 50));
          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("lazy"));
        });

        test("initialValue shown during loading", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
            initialValue: () => "initial",
          );

          expect(signal.value, equals("initial"));
          await Future.delayed(Duration(milliseconds: 100));
          expect(signal.value, equals("loaded"));
        });

        test("No initialValue shows null during loading", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal<String?>.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          expect(signal.value, isNull);
          await Future.delayed(Duration(milliseconds: 100));
          expect(signal.value, equals("loaded"));
        });

        test("Write value saves to storage", () async {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          await signal.ensure();
          signal.value = "new";
          expect(signal.value, equals("new"));
          expect(storage["key"], equals("new"));
        });

        test("Write queue handles rapid writes", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 10));
              writes.add(value);
              storage["key"] = value;
            },
          );

          await signal.ensure();
          signal.value = "1";
          signal.value = "2";
          signal.value = "3";
          await Future.delayed(Duration(milliseconds: 100));
          expect(writes.length, greaterThanOrEqualTo(1));
          expect(writes.last, equals("3"));
        });

        test("Throttle writes only last value", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
            throttle: Duration(milliseconds: 50),
          );

          await signal.ensure();
          signal.value = "1";
          signal.value = "2";
          signal.value = "3";
          await Future.delayed(Duration(milliseconds: 100));
          expect(writes.length, equals(1));
          expect(writes.first, equals("3"));
        });

        test("ensure waits for initialization", () async {
          final storage = createMockStorage({"key": "loaded"});
          bool initialized = false;
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              initialized = true;
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          await signal.ensure();
          expect(initialized, isTrue);
          expect(signal.isInitialized, isTrue);
        });

        test("ensure executes callback after initialization", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          await signal.ensure((value) {
            callbackExecuted = true;
            expect(value, equals("loaded"));
          });
          expect(callbackExecuted, isTrue);
        });

        test("ensure with fn == null waits for initialization", () async {
          final storage = createMockStorage({"key": "loaded"});
          bool initialized = false;
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              initialized = true;
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          expect(initialized, isFalse);
          await signal.ensure();
          expect(initialized, isTrue);
          expect(signal.isInitialized, isTrue);
        });

        test(
            "ensure with fn == null when already initialized completes immediately",
            () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          await signal.ensure(); // Initialize first
          expect(signal.isInitialized, isTrue);

          // Second call should complete immediately
          final startTime = DateTime.now();
          await signal.ensure();
          final duration = DateTime.now().difference(startTime);
          expect(duration.inMilliseconds, lessThan(10));
        });

        test("ensure with fn returning void (non-Future) before initialization",
            () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          await signal.ensure((value) {
            callbackExecuted = true;
            expect(value, equals("loaded"));
            // No return statement, returns void
          });
          expect(callbackExecuted, isTrue);
          expect(signal.isInitialized, isTrue);
        });

        test("ensure with fn returning void (non-Future) after initialization",
            () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          await signal.ensure(); // Initialize first
          expect(signal.isInitialized, isTrue);

          bool callbackExecuted = false;
          await signal.ensure((value) {
            callbackExecuted = true;
            expect(value, equals("loaded"));
            // No return statement, returns void
          });
          expect(callbackExecuted, isTrue);
        });

        test("ensure with fn returning Future before initialization", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          bool callbackExecuted = false;
          bool futureCompleted = false;
          await signal.ensure((value) async {
            callbackExecuted = true;
            expect(value, equals("loaded"));
            await Future.delayed(Duration(milliseconds: 20));
            futureCompleted = true;
          });
          expect(callbackExecuted, isTrue);
          expect(futureCompleted, isTrue);
          expect(signal.isInitialized, isTrue);
        });

        test("ensure with fn returning Future after initialization", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          await signal.ensure(); // Initialize first
          expect(signal.isInitialized, isTrue);

          bool callbackExecuted = false;
          bool futureCompleted = false;
          await signal.ensure((value) async {
            callbackExecuted = true;
            expect(value, equals("loaded"));
            await Future.delayed(Duration(milliseconds: 20));
            futureCompleted = true;
          });
          expect(callbackExecuted, isTrue);
          expect(futureCompleted, isTrue);
        });

        test("getEnsured waits and returns loaded value", () async {
          final storage = createMockStorage({"key": "loaded"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          final value = await signal.getEnsured();
          expect(value, equals("loaded"));
        });

        test("ensureWrite waits for current write", () async {
          final storage = createMockStorage({"key": "initial"});
          bool writeCompleted = false;
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) async {
              await Future.delayed(Duration(milliseconds: 50));
              storage["key"] = value;
              writeCompleted = true;
            },
          );

          await signal.ensure();
          signal.value = "new";
          await signal.ensureWrite();
          expect(writeCompleted, isTrue);
          expect(storage["key"], equals("new"));
        });

        test("ensureWrite waits for throttled write", () async {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) {
              writes.add(value);
              storage["key"] = value;
            },
            throttle: Duration(milliseconds: 50),
          );

          await signal.ensure();
          signal.value = "throttled";
          await signal.ensureWrite();
          expect(writes.length, equals(1));
          expect(writes.first, equals("throttled"));
        });

        test("Write before initialization throws StateError", () {
          final storage = createMockStorage();
          final signal = PersistSignal.lazyAsync(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) => storage["key"] = value,
          );

          expect(
            () => signal.value = "error",
            throwsA(isA<StateError>()),
          );
        });

        test("Load error marks as initialized and keeps initialValue",
            () async {
          final storage = createMockStorage();
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 10));
              throw Exception("Load error");
            },
            write: (value) => storage["key"] = value,
            initialValue: () => "initial",
          );

          expect(signal.value, equals("initial"));
          try {
            await signal.ensure();
          } catch (e) {
            expect(e, isA<Exception>());
          }
          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("initial"));
        });

        test("Write error is silently ignored", () async {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.async(
            read: () async => storage["key"] as String? ?? "default",
            write: (value) {
              throw Exception("Write error");
            },
          );

          await signal.ensure();
          signal.value = "new";
          expect(signal.value, equals("new")); // Optimistic update
          await Future.delayed(Duration(milliseconds: 10));
          expect(signal.value, equals("new")); // Value remains
        });

        test("Multiple _load calls return same future", () async {
          final storage = createMockStorage({"key": "loaded"});
          int loadCount = 0;
          final signal = PersistSignal.async(
            read: () async {
              loadCount++;
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          final future1 = signal.ensure();
          final future2 = signal.ensure();
          expect(future1, same(future2));
          await future1;
          expect(loadCount, equals(1));
        });

        test("Version control ignores stale load", () async {
          final storage = createMockStorage({"key": "initial"});
          final signal = PersistSignal.async(
            read: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return storage["key"] as String? ?? "default";
            },
            write: (value) => storage["key"] = value,
          );

          // Start loading
          unawaited(signal.ensure());
          await Future.delayed(Duration(milliseconds: 10));

          // Change value before load completes
          await signal.ensure();
          signal.value = "changed";
          await Future.delayed(Duration(milliseconds: 100));

          // Value should be "changed", not "initial"
          expect(signal.value, equals("changed"));
        });
      });
    });
  });
}
