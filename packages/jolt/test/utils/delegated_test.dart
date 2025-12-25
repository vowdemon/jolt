import "package:jolt/core.dart";
import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/utils/delegated.dart";
import "package:test/test.dart";

void main() {
  group("DelegatedRefCountHelper", () {
    test("should create with source and call onCreate", () {
      bool onCreateCalled = false;
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(
        source,
        onCreate: (_) => onCreateCalled = true,
      );

      expect(onCreateCalled, isTrue);
      expect(helper.source, same(source));
      expect(helper.count, equals(0));
    });

    test("acquire should increment ref count", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);

      expect(helper.count, equals(0));
      helper.acquire();
      expect(helper.count, equals(1));
      helper.acquire();
      expect(helper.count, equals(2));
    });

    test("release should decrement ref count", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);

      helper.acquire();
      helper.acquire();
      expect(helper.count, equals(2));

      final released = helper.release();
      expect(released, isFalse);
      expect(helper.count, equals(1));

      final released2 = helper.release();
      expect(released2, isTrue);
      expect(helper.count, equals(0));
    });

    test("release should call dispose when ref count reaches zero", () {
      bool onDisposeCalled = false;
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(
        source,
        onDispose: (_) => onDisposeCalled = true,
      );

      helper.acquire();
      helper.release();

      expect(onDisposeCalled, isTrue);
    });

    test(
        "dispose should call onDispose and dispose source if autoDispose is true",
        () {
      bool onDisposeCalled = false;
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(
        source,
        onDispose: (_) => onDisposeCalled = true,
        autoDispose: true,
      );

      helper.dispose();

      expect(onDisposeCalled, isTrue);
      expect(source.isDisposed, isTrue);
    });

    test("dispose should not dispose source if autoDispose is false", () {
      bool onDisposeCalled = false;
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(
        source,
        onDispose: (_) => onDisposeCalled = true,
        autoDispose: false,
      );

      helper.dispose();

      expect(onDisposeCalled, isTrue);
      expect(source.isDisposed, isFalse);
    });
  });

  group("DelegatedReadonlySignal", () {
    test("should delegate value access", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(
        source.readonly(),
      );
      final delegated = DelegatedReadonlySignal(helper);

      expect(delegated.value, equals(42));
      expect(delegated.peek, equals(42));
      expect(delegated.toString(), equals("42"));
    });

    test("should delegate notify", () {
      final source = Signal(42);
      final values = <int>[];
      final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(
        source.readonly(),
      );
      final delegated = DelegatedReadonlySignal(helper);

      Effect(() {
        values.add(delegated.value);
      });

      expect(values, equals([42]));

      delegated.notify();
      expect(values, equals([42, 42]));
    });

    test("should increment ref count on creation", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(
        source.readonly(),
      );

      expect(helper.count, equals(0));
      final delegated = DelegatedReadonlySignal(helper);
      expect(helper.count, equals(1));
      expect(delegated.isDisposed, isFalse);
    });

    test("dispose should decrement ref count", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(
        source.readonly(),
      );
      final delegated = DelegatedReadonlySignal(helper);

      expect(helper.count, equals(1));
      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);
    });

    test("dispose should be idempotent", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(
        source.readonly(),
      );
      final delegated = DelegatedReadonlySignal(helper);

      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);

      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);
    });
  });

  group("DelegatedSignal", () {
    test("should delegate value access and mutation", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      expect(delegated.value, equals(42));
      expect(delegated.peek, equals(42));

      delegated.value = 100;
      expect(delegated.value, equals(100));
      expect(source.value, equals(100));
    });

    test("should delegate notify", () {
      final source = Signal(42);
      final values = <int>[];
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      Effect(() {
        values.add(delegated.value);
      });

      expect(values, equals([42]));

      delegated.notify();
      expect(values, equals([42, 42]));
    });

    test("should increment ref count on creation", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);

      expect(helper.count, equals(0));
      final delegated = DelegatedSignal(helper);
      expect(helper.count, equals(1));
      expect(delegated.isDisposed, isFalse);
    });

    test("dispose should decrement ref count", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      expect(helper.count, equals(1));
      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);
    });

    test("set value should throw when disposed", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      delegated.dispose();

      expect(() => delegated.value = 100, throwsA(isA<AssertionError>()));
    });

    test("dispose should be idempotent", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);

      delegated.dispose();
      expect(helper.count, equals(0));
      expect(delegated.isDisposed, isTrue);
    });

    test("toString should return value.toString()", () {
      final source = Signal(42);
      final helper = DelegatedRefCountHelper<Signal<int>>(source);
      final delegated = DelegatedSignal(helper);

      expect(delegated.toString(), equals("42"));

      delegated.value = 100;
      expect(delegated.toString(), equals("100"));
    });
  });
}
