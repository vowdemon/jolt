import "dart:async";

import "package:jolt/tricks.dart";
import "package:test/test.dart";

Map<String, dynamic> createMockStorage([Map<String, dynamic>? initial]) {
  final storage = <String, dynamic>{...?initial};
  return storage;
}

void main() {
  group("PersistSignal.sync", () {
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

        signal.value = "new";

        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("new"));
        expect(storage["key"], equals("new"));
      });

      test("Set value before initialization loads from storage then overwrites",
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

        signal.value = "overwritten";

        expect(readCalled, isTrue);
        expect(signal.isInitialized, isTrue);
        expect(signal.value, equals("overwritten"));
        expect(storage["key"], equals("overwritten"));
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
        expect(signal.value, equals("new"));
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, equals("new"));
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
  });
}
