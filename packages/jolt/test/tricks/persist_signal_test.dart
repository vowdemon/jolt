import "dart:async";

import "package:jolt/jolt.dart";
import "package:test/test.dart";

Map<String, dynamic> createMockStorage([Map<String, dynamic>? initial]) {
  return <String, dynamic>{...?initial};
}

String readStorage(Map<String, dynamic> storage) =>
    storage["key"] as String? ?? "default";

void writeStorage(Map<String, dynamic> storage, String value) {
  storage["key"] = value;
}

final class _TestPersistSignalStorage<K> implements PersistSignalStorage<K> {
  _TestPersistSignalStorage({
    Map<K, Object?>? values,
    this.asyncReads = false,
    this.asyncWrites = false,
    this.readError,
  }) : values = <K, Object?>{...?values};

  final Map<K, Object?> values;
  final bool asyncReads;
  final bool asyncWrites;
  final Object? readError;
  final List<MapEntry<K, Object?>> writes = [];

  @override
  FutureOr<T> read<T>(K key, [T Function()? initial]) {
    final error = readError;
    if (error != null) {
      if (asyncReads) return Future<T>.error(error);
      throw error;
    }

    final T value;
    if (values.containsKey(key)) {
      value = values[key] as T;
    } else {
      final create = initial;
      if (create == null) throw StateError("Missing value for $key");
      value = create();
    }
    return asyncReads ? Future<T>.value(value) : value;
  }

  @override
  FutureOr<void> write<T>(K key, T value) {
    values[key] = value;
    writes.add(MapEntry(key, value));
    if (asyncWrites) return Future<void>.value();
  }
}

void main() {
  group("PersistSignal write callbacks", () {
    test("writes each synchronous assignment immediately", () async {
      final writes = <String>[];
      final signal = PersistSignal(
        read: () => "initial",
        write: writes.add,
      );

      signal.value = "1";
      signal.value = "2";
      await signal.ensureWrite();

      expect(writes, ["1", "2"]);
    });

    test("invokes async callbacks immediately and waits only for latest Future",
        () async {
      final firstWriteGate = Completer<void>();
      final secondWriteGate = Completer<void>();
      final started = <String>[];
      final completed = <String>[];
      final signal = PersistSignal(
        read: () => "initial",
        write: (value) async {
          started.add(value);
          if (value == "1") {
            await firstWriteGate.future;
          } else {
            await secondWriteGate.future;
          }
          completed.add(value);
        },
      );

      signal.value = "1";
      signal.value = "2";
      expect(started, ["1", "2"]);

      secondWriteGate.complete();
      await signal.ensureWrite();

      expect(completed, ["2"]);

      firstWriteGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(completed, ["2", "1"]);
    });

    test("write failure keeps optimistic value and drains newer work",
        () async {
      final firstWriteGate = Completer<void>();
      final attempts = <String>[];
      final signal = PersistSignal(
        read: () => "initial",
        write: (value) async {
          attempts.add(value);
          if (value == "1") {
            await firstWriteGate.future;
            throw StateError("failed");
          }
        },
      );

      signal.value = "1";
      signal.value = "2";
      firstWriteGate.complete();
      await signal.ensureWrite();

      expect(signal.value, "2");
      expect(attempts, ["1", "2"]);
    });

    test("dispose keeps started write drainable and ignores later assignments",
        () async {
      final writeGate = Completer<void>();
      final writes = <String>[];
      final signal = PersistSignal(
        read: () => "initial",
        write: (value) async {
          writes.add(value);
          await writeGate.future;
        },
      );

      signal.value = "1";
      final drain = signal.ensureWrite();
      signal.dispose();
      signal.value = "2";
      writeGate.complete();
      await drain;

      expect(writes, ["1"]);
    });
  });

  group("PersistSignal", () {
    test("eager signal reads during construction", () {
      var reads = 0;

      final signal = PersistSignal(
        read: () {
          reads++;
          return "loaded";
        },
        write: (_) {},
      );

      expect(reads, 1);
      expect(signal.value, "loaded");
      expect(reads, 1);
    });
  });

  group("PersistSignal.storage", () {
    test("preserves a generic key and lets storage select the initial value",
        () {
      final storage = _TestPersistSignalStorage<int>(
        values: {1: "stored"},
      );
      var initialCalls = 0;

      final present = PersistSignal.storage<int, String>(
        key: 1,
        initial: () {
          initialCalls++;
          return "fallback";
        },
        storage: storage,
      );
      final missing = PersistSignal.storage<int, String>(
        key: 2,
        initial: () {
          initialCalls++;
          return "fallback";
        },
        storage: storage,
      );

      expect(present.value, "stored");
      expect(missing.value, "fallback");
      expect(initialCalls, 1);
    });

    test("does not treat a stored nullable value as missing", () {
      final storage = _TestPersistSignalStorage<String>(
        values: {"nullable": null},
      );
      var initialCalls = 0;

      final signal = PersistSignal.storage<String, String?>(
        key: "nullable",
        initial: () {
          initialCalls++;
          return "fallback";
        },
        storage: storage,
      );

      expect(signal.value, isNull);
      expect(initialCalls, 0);
    });

    test("rejects an asynchronous storage read", () {
      final storage = _TestPersistSignalStorage<String>(
        values: {"key": "stored"},
        asyncReads: true,
      );

      expect(
        () => PersistSignal.storage<String, String>(
          key: "key",
          initial: () => "fallback",
          storage: storage,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            "message",
            contains("AsyncPersistSignal"),
          ),
        ),
      );
    });

    test("forwards the key and value and waits for an asynchronous write",
        () async {
      final storage = _TestPersistSignalStorage<String>(asyncWrites: true);
      final signal = PersistSignal.storage<String, String>(
        key: "theme",
        initial: () => "light",
        storage: storage,
      );

      signal.value = "dark";
      await signal.ensureWrite();

      expect(storage.writes, hasLength(1));
      expect(storage.writes.single.key, "theme");
      expect(storage.writes.single.value, "dark");
    });

    test("lets storage own a missing value when initial is omitted", () {
      final storage = _TestPersistSignalStorage<String>();

      expect(
        () => PersistSignal.storage<String, String>(
          key: "missing",
          storage: storage,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group("AsyncPersistSignal.storage", () {
    test("normalizes a synchronous storage read into async state", () async {
      final storage = _TestPersistSignalStorage<String>(
        values: {"key": "stored"},
      );

      final signal = AsyncPersistSignal.storage<String, String>(
        key: "key",
        storage: storage,
      );

      expect(signal.isLoading, isTrue);

      await signal.until((state) => state.isSuccess);

      expect(signal.data, "stored");
      expect(storage.writes, isEmpty);
    });

    test("lets asynchronous storage select the optional initial value",
        () async {
      final storage = _TestPersistSignalStorage<String>(asyncReads: true);
      var initialCalls = 0;

      final signal = AsyncPersistSignal.storage<String, String>(
        key: "key",
        initial: () {
          initialCalls++;
          return "fallback";
        },
        storage: storage,
      );

      await signal.until((state) => state.isSuccess);

      expect(signal.data, "fallback");
      expect(initialCalls, 1);
    });

    test("normalizes a synchronous storage read error into AsyncError",
        () async {
      final error = StateError("read failed");
      final storage = _TestPersistSignalStorage<String>(readError: error);

      final signal = AsyncPersistSignal.storage<String, String>(
        key: "key",
        initial: () => "fallback",
        storage: storage,
      );

      expect(signal.isLoading, isTrue);

      await signal.until((state) => state.isError);

      expect(signal.error, same(error));
      expect(storage.writes, isEmpty);
    });

    test("normalizes an asynchronous storage read failure into AsyncError",
        () async {
      final error = StateError("read failed");
      final storage = _TestPersistSignalStorage<String>(
        asyncReads: true,
        readError: error,
      );

      final signal = AsyncPersistSignal.storage<String, String>(
        key: "key",
        storage: storage,
      );

      await signal.until((state) => state.isError);

      expect(signal.error, same(error));
      expect(signal.stackTrace, isNotNull);
    });

    test("forwards the key and value and waits for an asynchronous write",
        () async {
      final storage = _TestPersistSignalStorage<String>(asyncWrites: true);
      final signal = AsyncPersistSignal.storage<String, String>(
        key: "theme",
        initial: () => "light",
        storage: storage,
      );

      signal.set("dark");
      await signal.ensureWrite();

      expect(signal.data, "dark");
      expect(storage.writes, hasLength(1));
      expect(storage.writes.single.key, "theme");
      expect(storage.writes.single.value, "dark");
      expect(storage.values["theme"], "dark");
    });
  });

  group("PersistSignalStorageX", () {
    test("sync forwards key, initial, debug, and writes", () async {
      JoltDebug.init();
      final storage = _TestPersistSignalStorage<String>(asyncWrites: true);
      final debugEvents = <DebugNodeOperationType>[];
      var initialCalls = 0;

      final signal = storage.sync<String>(
        key: "theme",
        initial: () {
          initialCalls++;
          return "light";
        },
        debug: JoltDebugOption.fn((event, _) => debugEvents.add(event)),
      );

      expect(signal.value, "light");
      expect(initialCalls, 1);
      expect(debugEvents, contains(DebugNodeOperationType.create));

      signal.value = "dark";
      await signal.ensureWrite();

      expect(debugEvents, contains(DebugNodeOperationType.set));
      expect(storage.writes, hasLength(1));
      expect(storage.writes.single.key, "theme");
      expect(storage.writes.single.value, "dark");
    });

    test("sync rejects an asynchronous storage read", () {
      final storage = _TestPersistSignalStorage<String>(
        values: {"theme": "dark"},
        asyncReads: true,
      );

      expect(
        () => storage.sync<String>(key: "theme"),
        throwsA(isA<StateError>()),
      );
    });

    test("async forwards key, initial, debug, and writes as async state",
        () async {
      final storage = _TestPersistSignalStorage<int>(
        asyncReads: true,
        asyncWrites: true,
      );
      final debugEvents = <DebugNodeOperationType>[];
      var initialCalls = 0;

      final signal = storage.async<String>(
        key: 7,
        initial: () {
          initialCalls++;
          return "stored";
        },
        debug: JoltDebugOption.fn((event, _) => debugEvents.add(event)),
      );

      expect(signal.isLoading, isTrue);
      await signal.until((state) => state.isSuccess);

      expect(signal.data, "stored");
      expect(initialCalls, 1);
      expect(debugEvents, contains(DebugNodeOperationType.create));

      signal.set("updated");
      await signal.ensureWrite();

      expect(debugEvents, contains(DebugNodeOperationType.set));
      expect(storage.writes, hasLength(1));
      expect(storage.writes.single.key, 7);
      expect(storage.writes.single.value, "updated");
    });
  });

  group("AsyncPersistSignal", () {
    test("starts loading then publishes the initial read without writing",
        () async {
      final readCompleter = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () => readCompleter.future,
        write: writes.add,
      );

      expect(signal.value, isA<AsyncLoading<String>>());

      readCompleter.complete("loaded");
      await signal.until((state) => state.isSuccess);

      expect(signal.data, "loaded");
      await signal.ensureWrite();
      expect(writes, isEmpty);
    });

    test("publishes a synchronous read throw as AsyncError", () async {
      final error = StateError("read failed");
      final writes = <String>[];
      final signal = AsyncPersistSignal<String>(
        read: () => throw error,
        write: writes.add,
      );

      await signal.until((state) => state.isError);

      expect(signal.error, same(error));
      expect(signal.stackTrace, isNotNull);
      expect(writes, isEmpty);
    });

    test("publishes an asynchronous read failure as AsyncError", () async {
      final error = StateError("read failed");
      final stackTrace = StackTrace.current;
      final writes = <String>[];
      final signal = AsyncPersistSignal<String>(
        read: () => Future<String>.error(error, stackTrace),
        write: writes.add,
      );

      await signal.until((state) => state.isError);

      expect(signal.error, same(error));
      expect(signal.stackTrace, same(stackTrace));
      expect(writes, isEmpty);
    });

    test("ensureWrite does not wait for the initial read", () async {
      final readCompleter = Completer<String>();
      final signal = AsyncPersistSignal(
        read: () => readCompleter.future,
        write: (_) {},
      );

      await signal.ensureWrite();

      expect(signal.isLoading, isTrue);
      readCompleter.complete("loaded");
      await signal.until((state) => state.isSuccess);
    });

    test("set publishes success, persists, and supersedes the initial read",
        () async {
      final readCompleter = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () => readCompleter.future,
        write: writes.add,
      );

      signal.set("local");

      expect(signal.value, isA<AsyncSuccess<String>>());
      expect(signal.data, "local");
      await signal.ensureWrite();
      expect(writes, ["local"]);

      readCompleter.complete("stale");
      await Future<void>.delayed(Duration.zero);

      expect(signal.data, "local");
      expect(writes, ["local"]);
    });

    test("setFuture publishes loading then persists its current success",
        () async {
      final assigned = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(assigned.future);
      final drain = signal.ensureWrite();
      expect(signal.isLoading, isTrue);
      expect(writes, isEmpty);

      assigned.complete("resolved");
      await drain;

      expect(signal.data, "resolved");
      expect(writes, ["resolved"]);
    });

    test("setFuture publishes a current failure without writing", () async {
      final assigned = Completer<String>();
      final error = StateError("assignment failed");
      final stackTrace = StackTrace.current;
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(assigned.future);
      final drain = signal.ensureWrite();
      assigned.completeError(error, stackTrace);

      await drain;

      expect(signal.isError, isTrue);
      expect(signal.error, same(error));
      expect(signal.stackTrace, same(stackTrace));
      expect(writes, isEmpty);
    });

    test("later setFuture supersedes unresolved work and redirects the barrier",
        () async {
      final first = Completer<String>();
      final second = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(first.future);
      final drain = signal.ensureWrite();
      signal.setFuture(second.future);
      second.complete("second");

      await drain;
      expect(signal.data, "second");
      expect(writes, ["second"]);

      first.complete("first");
      await Future<void>.delayed(Duration.zero);
      expect(signal.data, "second");
      expect(writes, ["second"]);
    });

    test("reassigning the same Future persists only the latest operation",
        () async {
      final assigned = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(assigned.future);
      signal.setFuture(assigned.future);
      assigned.complete("resolved");
      await signal.ensureWrite();

      expect(signal.data, "resolved");
      expect(writes, ["resolved"]);
    });

    test("direct states supersede setFuture and only success is persisted",
        () async {
      final pending = Completer<String>();
      final manualError = StateError("manual");
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(pending.future);
      final drain = signal.ensureWrite();
      signal.value = AsyncError<String>(manualError);
      await drain;

      expect(signal.error, same(manualError));
      expect(writes, isEmpty);

      pending.complete("stale");
      await Future<void>.delayed(Duration.zero);
      expect(signal.error, same(manualError));
      expect(writes, isEmpty);

      signal.value = const AsyncLoading<String>();
      expect(signal.isLoading, isTrue);
      expect(writes, isEmpty);

      signal.value = const AsyncSuccess<String>("direct");
      await signal.ensureWrite();

      expect(signal.data, "direct");
      expect(writes, ["direct"]);
    });

    test("ensureWrite ignores an older overlapping write callback", () async {
      final firstWriteStarted = Completer<void>();
      final secondWriteStarted = Completer<void>();
      final firstWriteGate = Completer<void>();
      final secondWriteGate = Completer<void>();
      final completed = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: (value) async {
          if (value == "first") {
            firstWriteStarted.complete();
            await firstWriteGate.future;
          } else {
            secondWriteStarted.complete();
            await secondWriteGate.future;
          }
          completed.add(value);
        },
      );

      await signal.until((state) => state.isSuccess);

      signal.set("first");
      await firstWriteStarted.future;
      signal.set("second");
      await secondWriteStarted.future;

      secondWriteGate.complete();
      await signal.ensureWrite();

      expect(completed, ["second"]);
      expect(signal.data, "second");

      firstWriteGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(completed, ["second", "first"]);
    });

    test("write failures do not replace optimistic success state", () async {
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: (value) {
          writes.add(value);
          if (value == "first") {
            return Future<void>.error(StateError("failed"));
          }
        },
      );

      await signal.until((state) => state.isSuccess);

      signal.set("first");
      await signal.ensureWrite();

      expect(signal.isSuccess, isTrue);
      expect(signal.data, "first");

      signal.set("second");
      await signal.ensureWrite();

      expect(signal.data, "second");
      expect(writes, ["first", "second"]);
    });

    test("dispose prevents a pending initial read from replacing state",
        () async {
      final readCompleter = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () => readCompleter.future,
        write: writes.add,
      );

      signal.dispose();
      readCompleter.complete("late");
      await Future<void>.delayed(Duration.zero);

      expect(signal.isLoading, isTrue);
      expect(writes, isEmpty);
    });

    test("dispose supersedes unresolved assignment and prevents its write",
        () async {
      final assigned = Completer<String>();
      final writes = <String>[];
      final signal = AsyncPersistSignal(
        read: () async => "loaded",
        write: writes.add,
      );

      await signal.until((state) => state.isSuccess);

      signal.setFuture(assigned.future);
      final drain = signal.ensureWrite();
      signal.dispose();
      await drain;

      assigned.complete("late");
      await Future<void>.delayed(Duration.zero);

      expect(signal.isLoading, isTrue);
      expect(writes, isEmpty);
    });
  });
}
