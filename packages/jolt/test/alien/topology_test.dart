import 'package:test/test.dart';

import 'common.dart';

class MockFunction<T> {
  int callCount = 0;
  List<DateTime> callTimes = [];
  final T Function() _fn;

  MockFunction(this._fn);

  T call() {
    callCount++;
    callTimes.add(DateTime.now());
    return _fn();
  }

  void clear() {
    callCount = 0;
    callTimes.clear();
  }

  bool get hasBeenCalledOnce => callCount == 1;
  bool get hasNotBeenCalled => callCount == 0;
  int get calledTimes => callCount;

  bool hasBeenCalledBefore(MockFunction other) {
    if (callTimes.isEmpty || other.callTimes.isEmpty) return false;
    return callTimes.first.isBefore(other.callTimes.first) ||
        callTimes.first.isAtSameMomentAs(other.callTimes.first);
  }
}

void main() {
  group('computed', () {
    test('should drop A->B->A updates', () {
      //     A
      //   / |
      //  B  | <- Looks like a flag doesn't it? :D
      //   \ |
      //     C
      //     |
      //     D
      final a = signal(2);

      final b = computed(() => a() - 1);
      final c = computed(() => a() + b());

      final compute = MockFunction(() => "d: ${c()}");
      final d = computed(() => compute());

      // Trigger read
      expect(d(), equals("d: 3"));
      expect(compute.hasBeenCalledOnce, isTrue);
      compute.clear();

      a(4, true);
      d();
      expect(compute.hasBeenCalledOnce, isTrue);
    });

    test('should only update every signal once (diamond graph)', () {
      // In this scenario "D" should only update once when "A" receives
      // an update. This is sometimes referred to as the "diamond" scenario.
      //     A
      //   /   \
      //  B     C
      //   \   /
      //     D

      final a = signal("a");
      final b = computed(() => a());
      final c = computed(() => a());

      final spy = MockFunction(() => "${b()} ${c()}");
      final d = computed(() => spy());

      expect(d(), equals("a a"));
      expect(spy.hasBeenCalledOnce, isTrue);

      a("aa", true);
      expect(d(), equals("aa aa"));
      expect(spy.calledTimes, equals(2));
    });

    test('should only update every signal once (diamond graph + tail)', () {
      // "E" will be likely updated twice if our mark+sweep logic is buggy.
      //     A
      //   /   \
      //  B     C
      //   \   /
      //     D
      //     |
      //     E

      final a = signal("a");
      final b = computed(() => a());
      final c = computed(() => a());

      final d = computed(() => "${b()} ${c()}");

      final spy = MockFunction(() => d());
      final e = computed(() => spy());

      expect(e(), equals("a a"));
      expect(spy.hasBeenCalledOnce, isTrue);

      a("aa", true);
      expect(e(), equals("aa aa"));
      expect(spy.calledTimes, equals(2));
    });

    test('should bail out if result is the same', () {
      // Bail out if value of "B" never changes
      // A->B->C
      final a = signal("a");
      final b = computed(() {
        a();
        return "foo";
      });

      final spy = MockFunction(() => b());
      final c = computed(() => spy());

      expect(c(), equals("foo"));
      expect(spy.hasBeenCalledOnce, isTrue);

      a("aa", true);
      expect(c(), equals("foo"));
      expect(spy.hasBeenCalledOnce, isTrue);
    });

    test(
      'should only update every signal once (jagged diamond graph + tails)',
      () {
        // "F" and "G" will be likely updated twice if our mark+sweep logic is buggy.
        //     A
        //   /   \
        //  B     C
        //  |     |
        //  |     D
        //   \   /
        //     E
        //   /   \
        //  F     G
        final a = signal("a");

        final b = computed(() => a());
        final c = computed(() => a());

        final d = computed(() => c());

        final eSpy = MockFunction(() => "${b()} ${d()}");
        final e = computed(() => eSpy());

        final fSpy = MockFunction(() => e());
        final f = computed(() => fSpy());
        final gSpy = MockFunction(() => e());
        final g = computed(() => gSpy());

        expect(f(), equals("a a"));
        expect(fSpy.calledTimes, equals(1));

        expect(g(), equals("a a"));
        expect(gSpy.calledTimes, equals(1));

        eSpy.clear();
        fSpy.clear();
        gSpy.clear();

        a("b", true);

        expect(e(), equals("b b"));
        expect(eSpy.calledTimes, equals(1));

        expect(f(), equals("b b"));
        expect(fSpy.calledTimes, equals(1));

        expect(g(), equals("b b"));
        expect(gSpy.calledTimes, equals(1));

        eSpy.clear();
        fSpy.clear();
        gSpy.clear();

        a("c", true);

        expect(e(), equals("c c"));
        expect(eSpy.calledTimes, equals(1));

        expect(f(), equals("c c"));
        expect(fSpy.calledTimes, equals(1));

        expect(g(), equals("c c"));
        expect(gSpy.calledTimes, equals(1));
        print(eSpy.callTimes);
        print(fSpy.callTimes);
        print(gSpy.callTimes);
        // top to bottom
        expect(eSpy.hasBeenCalledBefore(fSpy), isTrue);
        // left to right
        expect(fSpy.hasBeenCalledBefore(gSpy), isTrue);
      },
    );

    test('should only subscribe to signals listened to', () {
      //    *A
      //   /   \
      // *B     C <- we don't listen to C
      final a = signal("a");

      final b = computed(() => a());
      final spy = MockFunction(() => a());
      computed(() => spy());

      expect(b(), equals("a"));
      expect(spy.hasNotBeenCalled, isTrue);

      a("aa", true);
      expect(b(), equals("aa"));
      expect(spy.hasNotBeenCalled, isTrue);
    });

    test('should only subscribe to signals listened to II', () {
      // Here both "B" and "C" are active in the beginning, but
      // "B" becomes inactive later. At that point it should
      // not receive any updates anymore.
      //    *A
      //   /   \
      // *B     D <- we don't listen to C
      //  |
      // *C
      final a = signal("a");
      final spyB = MockFunction(() => a());
      final b = computed(() => spyB());

      final spyC = MockFunction(() => b());
      final c = computed(() => spyC());

      final d = computed(() => a());

      String result = "";
      final unsub = effect(() {
        result = c();
      });

      expect(result, equals("a"));
      expect(d(), equals("a"));

      spyB.clear();
      spyC.clear();
      unsub();

      a("aa", true);

      expect(d(), equals("aa"));
    });

    test('should ensure subs update even if one dep unmarks it', () {
      // In this scenario "C" always returns the same value. When "A"
      // changes, "B" will update, then "C" at which point its update
      // to "D" will be unmarked. But "D" must still update because
      // "B" marked it. If "D" isn't updated, then we have a bug.
      //     A
      //   /   \
      //  B     *C <- returns same value every time
      //   \   /
      //     D
      final a = signal("a");
      final b = computed(() => a());
      final c = computed(() {
        a();
        return "c";
      });
      final spy = MockFunction(() => "${b()} ${c()}");
      final d = computed(() => spy());

      expect(d(), equals("a c"));
      spy.clear();

      a("aa", true);
      d();
      expect(spy(), equals("aa c"));
    });

    test('should ensure subs update even if two deps unmark it', () {
      // In this scenario both "C" and "D" always return the same
      // value. But "E" must still update because "A" marked it.
      // If "E" isn't updated, then we have a bug.
      //     A
      //   / | \
      //  B *C *D
      //   \ | /
      //     E
      final a = signal("a");
      final b = computed(() => a());
      final c = computed(() {
        a();
        return "c";
      });
      final d = computed(() {
        a();
        return "d";
      });
      final spy = MockFunction(() => "${b()} ${c()} ${d()}");
      final e = computed(() => spy());

      expect(e(), equals("a c d"));
      spy.clear();

      a("aa", true);
      e();
      expect(spy(), equals("aa c d"));
    });

    test('should support lazy branches', () {
      final a = signal(0);
      final b = computed(() => a());
      final c = computed(() => a() > 0 ? a() : b());

      expect(c(), equals(0));
      a(1, true);
      expect(c(), equals(1));

      a(0, true);
      expect(c(), equals(0));
    });

    test('should not update a sub if all deps unmark it', () {
      // In this scenario "B" and "C" always return the same value. When "A"
      // changes, "D" should not update.
      //     A
      //   /   \
      // *B     *C
      //   \   /
      //     D
      final a = signal("a");
      final b = computed(() {
        a();
        return "b";
      });
      final c = computed(() {
        a();
        return "c";
      });
      final spy = MockFunction(() => "${b()} ${c()}");
      final d = computed(() => spy());

      expect(d(), equals("b c"));
      spy.clear();

      a("aa", true);
      expect(spy.hasNotBeenCalled, isTrue);
    });
  });

  group("error handling", () {
    test('should keep graph consistent on errors during activation', () {
      final a = signal(0);
      final b = computed(() {
        throw Exception("fail");
      });
      final c = computed(() => a());

      expect(() => b(), throwsA(isA<Exception>()));

      a(1, true);
      expect(c(), equals(1));
    });

    test('should keep graph consistent on errors in computeds', () {
      final a = signal(0);
      final b = computed(() {
        if (a() == 1) throw Exception("fail");
        return a();
      });
      final c = computed(() => b());

      expect(c(), equals(0));

      a(1, true);
      expect(() => b(), throwsA(isA<Exception>()));

      a(2, true);
      expect(c(), equals(2));
    });
  });
}
