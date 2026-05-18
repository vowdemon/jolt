import "dart:async";

import "package:jolt/tricks.dart";
import "package:test/test.dart";

Map<String, dynamic> createMockStorage([Map<String, dynamic>? initial]) {
  final storage = <String, dynamic>{...?initial};
  return storage;
}

void main() {
  group("PersistSignal.async", () {
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

        signal.value;
        await Future.delayed(Duration(milliseconds: 50));
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("lazy"));
      });

      test(
          "lazy getter-triggered load stays single-flight across repeated reads and ensure",
          () async {
        final storage = createMockStorage({"key": "lazy"});
        var loadCount = 0;
        final signal = PersistSignal<String?>.lazyAsync(
          read: () async {
            loadCount++;
            await Future.delayed(Duration(milliseconds: 50));
            return storage["key"] as String? ?? "default";
          },
          write: (value) => storage["key"] = value,
        );

        expect(signal.isInitialized, isFalse);
        expect(signal.value, isNull);
        expect(signal.value, isNull);

        await signal.ensure();

        expect(loadCount, equals(1));
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("lazy"));
      });

      test(
          "getter-started lazy load still forbids writes until initialization completes",
          () async {
        final storage = createMockStorage({"key": "loaded"});
        final signal = PersistSignal.lazyAsync(
          read: () async {
            await Future.delayed(Duration(milliseconds: 50));
            return storage["key"] as String? ?? "default";
          },
          write: (value) => storage["key"] = value,
          initialValue: () => "initial",
        );

        expect(signal.value, equals("initial"));
        expect(signal.isInitialized, isFalse);
        expect(
          () => signal.value = "changed-too-early",
          throwsA(isA<StateError>()),
        );

        await signal.ensure();
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("loaded"));

        signal.value = "changed";
        expect(signal.value, equals("changed"));
        expect(storage["key"], equals("changed"));
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

        await signal.ensure();
        expect(signal.isInitialized, isTrue);

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

        await signal.ensure();
        expect(signal.isInitialized, isTrue);

        bool callbackExecuted = false;
        await signal.ensure((value) {
          callbackExecuted = true;
          expect(value, equals("loaded"));
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

        await signal.ensure();
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

      test("Load error marks as initialized and keeps initialValue", () async {
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
        expect(signal.value, equals("new"));
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, equals("new"));
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
    });
  });
}
