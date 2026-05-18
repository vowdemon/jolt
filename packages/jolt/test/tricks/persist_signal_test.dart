import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:jolt/tricks.dart";
import "package:test/test.dart";

const _throttle = Duration(milliseconds: 50);

Map<String, dynamic> createMockStorage([Map<String, dynamic>? initial]) {
  return <String, dynamic>{...?initial};
}

String readStorage(Map<String, dynamic> storage) =>
    storage["key"] as String? ?? "default";

void writeStorage(Map<String, dynamic> storage, String? value) {
  storage["key"] = value;
}

void main() {
  group("PersistSignal write queue", () {
    group("via sync", () {
      test("rapid writes coalesce pending slot to last value", () async {
        final storage = createMockStorage({"key": "initial"});
        final writes = <String>[];
        final writeGate = Completer<void>();
        final signal = PersistSignal.sync(
          read: () => readStorage(storage),
          write: (value) async {
            if (writes.isEmpty) {
              await writeGate.future;
            }
            writes.add(value);
            writeStorage(storage, value);
          },
        );

        signal.value = "1";
        signal.value = "2";
        signal.value = "3";
        writeGate.complete();
        await signal.ensureWrite();

        expect(writes, equals(["1", "3"]));
        expect(readStorage(storage), equals("3"));
      });

      test("without throttle each assignment is written", () async {
        final writes = <String>[];
        final signal = PersistSignal.sync(
          read: () => "initial",
          write: writes.add,
        );

        signal.value = "1";
        signal.value = "2";
        await signal.ensureWrite();

        expect(writes, equals(["1", "2"]));
      });

      test("ensureWrite waits for in-flight write", () async {
        final storage = createMockStorage({"key": "initial"});
        final writeGate = Completer<void>();
        var writeCompleted = false;
        final signal = PersistSignal.sync(
          read: () => readStorage(storage),
          write: (value) async {
            await writeGate.future;
            writeStorage(storage, value);
            writeCompleted = true;
          },
        );

        signal.value = "new";
        final drained = signal.ensureWrite();
        await Future<void>.delayed(Duration.zero);
        expect(writeCompleted, isFalse);

        writeGate.complete();
        await drained;

        expect(writeCompleted, isTrue);
        expect(readStorage(storage), equals("new"));
      });

      test("ensureWrite waits for queued writes", () async {
        final storage = createMockStorage({"key": "initial"});
        final writes = <String>[];
        final writeGate = Completer<void>();
        final signal = PersistSignal.sync(
          read: () => readStorage(storage),
          write: (value) async {
            if (writes.isEmpty) {
              await writeGate.future;
            }
            writes.add(value);
            writeStorage(storage, value);
          },
        );

        signal.value = "1";
        signal.value = "2";
        writeGate.complete();
        await signal.ensureWrite();

        expect(writes, equals(["1", "2"]));
        expect(readStorage(storage), equals("2"));
      });

      test("write errors do not revert optimistic value", () async {
        final signal = PersistSignal.sync(
          read: () => "initial",
          write: (_) => throw Exception("Write error"),
        );

        signal.value = "new";
        await signal.ensureWrite();

        expect(signal.value, equals("new"));
      });
    });

    group("via sync throttle", () {
      test("burst writes keep only the last value", () {
        fakeAsync((async) {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => readStorage(storage),
            write: (value) {
              writes.add(value);
              writeStorage(storage, value);
            },
            throttle: _throttle,
          );

          signal.value = "1";
          signal.value = "2";
          signal.value = "3";
          expect(writes, isEmpty);

          var drained = false;
          signal.ensureWrite().then((_) => drained = true);

          async.elapse(_throttle);
          async.flushMicrotasks();

          expect(drained, isTrue);
          expect(writes, equals(["3"]));
          expect(readStorage(storage), equals("3"));
        });
      });

      test("ensureWrite waits for trailing throttled write", () {
        fakeAsync((async) {
          final storage = createMockStorage({"key": "initial"});
          final writes = <String>[];
          final signal = PersistSignal.sync(
            read: () => readStorage(storage),
            write: (value) {
              writes.add(value);
              writeStorage(storage, value);
            },
            throttle: _throttle,
          );

          signal.value = "throttled";
          expect(writes, isEmpty);

          var drained = false;
          signal.ensureWrite().then((_) => drained = true);

          async.elapse(_throttle);
          async.flushMicrotasks();

          expect(drained, isTrue);
          expect(writes, equals(["throttled"]));
          expect(readStorage(storage), equals("throttled"));
        });
      });
    });
  });

  group("PersistSignal.sync", () {
    test("eager init loads storage immediately", () {
      final storage = createMockStorage({"key": "value"});
      final signal = PersistSignal.sync(
        read: () => readStorage(storage),
        write: (value) => writeStorage(storage, value),
      );

      expect(signal.isInitialized, isTrue);
      expect(signal.value, equals("value"));
    });

    test("lazy init loads on first read", () {
      final storage = createMockStorage({"key": "lazy"});
      final signal = PersistSignal.lazySync(
        read: () => readStorage(storage),
        write: (value) => writeStorage(storage, value),
      );

      expect(signal.isInitialized, isFalse);
      expect(signal.value, equals("lazy"));
      expect(signal.isInitialized, isTrue);
    });

    test("write before lazy init reads storage then overwrites", () {
      final storage = createMockStorage({"key": "loaded"});
      var readCalled = false;
      final signal = PersistSignal.lazySync(
        read: () {
          readCalled = true;
          return readStorage(storage);
        },
        write: (value) => writeStorage(storage, value),
      );

      expect(signal.isInitialized, isFalse);
      signal.value = "overwritten";

      expect(readCalled, isTrue);
      expect(signal.isInitialized, isTrue);
      expect(signal.value, equals("overwritten"));
      expect(readStorage(storage), equals("overwritten"));
    });

    test("getEnsured returns the current value", () async {
      final signal = PersistSignal.sync(
        read: () => "loaded",
        write: (_) {},
      );

      expect(await signal.getEnsured(), equals("loaded"));
    });

    test("ensure runs callback and awaits returned Future", () async {
      final storage = createMockStorage({"key": "value"});
      final signal = PersistSignal.sync(
        read: () => readStorage(storage),
        write: (value) => writeStorage(storage, value),
      );

      final callbackGate = Completer<void>();
      var callbackExecuted = false;
      var futureCompleted = false;

      final ensureFuture = signal.ensure((value) async {
        callbackExecuted = true;
        expect(value, equals("value"));
        await callbackGate.future;
        futureCompleted = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(callbackExecuted, isTrue);
      expect(futureCompleted, isFalse);

      callbackGate.complete();
      await ensureFuture;
      expect(futureCompleted, isTrue);
    });
  });

  group("PersistSignal.async", () {
    group("initialization", () {
      test("eager init completes via ensure", () async {
        final storage = createMockStorage({"key": "value"});
        final signal = PersistSignal.async(
          read: () async => readStorage(storage),
          write: (value) => writeStorage(storage, value),
        );

        expect(signal.isInitialized, isFalse);
        await signal.ensure();
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("value"));
      });

      test("getEnsured waits for load and returns value", () async {
        final storage = createMockStorage({"key": "loaded"});
        final loadGate = Completer<void>();
        final signal = PersistSignal.async(
          read: () async {
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
        );

        final ensured = signal.getEnsured();
        expect(signal.isInitialized, isFalse);
        loadGate.complete();
        await expectLater(ensured, completion(equals("loaded")));
        expect(signal.isInitialized, isTrue);
      });

      test("lazy init completes after getter starts load", () async {
        final storage = createMockStorage({"key": "lazy"});
        final loadGate = Completer<void>();
        final signal = PersistSignal<String?>.lazyAsync(
          read: () async {
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
        );

        expect(signal.isInitialized, isFalse);
        expect(signal.value, isNull);
        loadGate.complete();
        await signal.ensure();
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("lazy"));
      });

      test("lazy load is single-flight across getter and ensure", () async {
        final storage = createMockStorage({"key": "lazy"});
        var loadCount = 0;
        final loadGate = Completer<void>();
        final signal = PersistSignal<String?>.lazyAsync(
          read: () async {
            loadCount++;
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
        );

        expect(signal.value, isNull);
        expect(signal.value, isNull);
        final firstEnsure = signal.ensure();
        final secondEnsure = signal.ensure();
        expect(firstEnsure, same(secondEnsure));
        loadGate.complete();
        await firstEnsure;

        expect(loadCount, equals(1));
        expect(signal.value, equals("lazy"));
      });
    });

    group("initialValue", () {
      test("is shown until load completes", () async {
        final storage = createMockStorage({"key": "loaded"});
        final loadGate = Completer<void>();
        final signal = PersistSignal.async(
          read: () async {
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
          initialValue: () => "initial",
        );

        expect(signal.value, equals("initial"));
        loadGate.complete();
        await signal.ensure();
        expect(signal.value, equals("loaded"));
      });

      test("defaults to null when omitted", () async {
        final storage = createMockStorage({"key": "loaded"});
        final loadGate = Completer<void>();
        final signal = PersistSignal<String?>.async(
          read: () async {
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
        );

        expect(signal.value, isNull);
        loadGate.complete();
        await signal.ensure();
        expect(signal.value, equals("loaded"));
      });
    });

    group("write guard", () {
      test("assignment before initialization throws StateError", () {
        final storage = createMockStorage();
        final signal = PersistSignal.lazyAsync(
          read: () async => readStorage(storage),
          write: (value) => writeStorage(storage, value),
        );

        expect(() => signal.value = "error", throwsA(isA<StateError>()));
      });

      test(
        "getter-started load forbids assignment until initialization completes",
        () async {
          final storage = createMockStorage({"key": "loaded"});
          final loadGate = Completer<void>();
          final signal = PersistSignal.lazyAsync(
            read: () async {
              await loadGate.future;
              return readStorage(storage);
            },
            write: (value) => writeStorage(storage, value),
            initialValue: () => "initial",
          );

          expect(signal.value, equals("initial"));
          expect(signal.isInitialized, isFalse);
          expect(
            () => signal.value = "changed-too-early",
            throwsA(isA<StateError>()),
          );

          loadGate.complete();
          await signal.ensure();
          expect(signal.isInitialized, isTrue);
          expect(signal.value, equals("loaded"));

          signal.value = "changed";
          await signal.ensureWrite();
          expect(readStorage(storage), equals("changed"));
        },
      );
    });

    group("load completion", () {
      test("stale storage read is ignored when version changes during load",
          () async {
        final storage = createMockStorage({"key": "stale"});
        final loadGate = Completer<void>();
        final signal = PersistSignal.async(
          read: () async {
            await loadGate.future;
            return readStorage(storage);
          },
          write: (value) => writeStorage(storage, value),
          initialValue: () => "user",
        );

        expect(signal.value, equals("user"));
        signal.version++;
        loadGate.complete();
        await signal.ensure();

        expect(signal.value, equals("user"));
        expect(signal.isInitialized, isTrue);
      });

      test("load error marks initialized and keeps initialValue", () async {
        final storage = createMockStorage();
        final signal = PersistSignal.async(
          read: () async => throw Exception("Load error"),
          write: (value) => writeStorage(storage, value),
          initialValue: () => "initial",
        );

        expect(signal.value, equals("initial"));
        await expectLater(signal.ensure(), throwsA(isA<Exception>()));
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("initial"));
      });

      test("allows write after load error", () async {
        final storage = createMockStorage();
        final signal = PersistSignal.async(
          read: () async => throw Exception("Load error"),
          write: (value) => writeStorage(storage, value),
          initialValue: () => "initial",
        );

        await expectLater(signal.ensure(), throwsA(isA<Exception>()));
        signal.value = "recovered";
        await signal.ensureWrite();

        expect(signal.value, equals("recovered"));
        expect(readStorage(storage), equals("recovered"));
      });
    });

    test("ensure on initialized signal supports sync and async callbacks",
        () async {
      final storage = createMockStorage({"key": "loaded"});
      final signal = PersistSignal.async(
        read: () async => readStorage(storage),
        write: (value) => writeStorage(storage, value),
      );

      await signal.ensure();
      await signal.ensure();

      var syncRan = false;
      await signal.ensure((value) {
        syncRan = true;
        expect(value, equals("loaded"));
      });
      expect(syncRan, isTrue);

      var asyncRan = false;
      await signal.ensure((value) async {
        asyncRan = true;
        expect(value, equals("loaded"));
      });
      expect(asyncRan, isTrue);
    });

    test("ensure callback receives loaded value and awaits returned Future",
        () async {
      final storage = createMockStorage({"key": "loaded"});
      final loadGate = Completer<void>();
      final callbackGate = Completer<void>();
      final signal = PersistSignal.async(
        read: () async {
          await loadGate.future;
          return readStorage(storage);
        },
        write: (value) => writeStorage(storage, value),
      );

      var callbackExecuted = false;
      var futureCompleted = false;
      final ensureFuture = signal.ensure((value) async {
        callbackExecuted = true;
        expect(value, equals("loaded"));
        await callbackGate.future;
        futureCompleted = true;
      });

      loadGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(callbackExecuted, isTrue);
      expect(futureCompleted, isFalse);

      callbackGate.complete();
      await ensureFuture;
      expect(futureCompleted, isTrue);
    });
  });
}
