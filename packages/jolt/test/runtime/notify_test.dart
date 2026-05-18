import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("notify", () {
    test("without subscribers completes normally", () {
      expect(() => Signal(0).notify(), returnsNormally);
    });

    group("in-place mutation", () {
      test(
        "propagates through computed chain only from the notified node",
        () {
          final source = Signal(<int>[1, 2]);
          final length = Computed(() => source.value.length);
          final doubled = Computed(() => length.value * 2);
          var leafRuns = 0;
          var branchRuns = 0;

          Effect(() {
            doubled.value;
            leafRuns++;
          });
          Effect(() {
            length.value;
            doubled.value;
            branchRuns++;
          });

          expect(leafRuns, equals(1));
          expect(branchRuns, equals(1));

          source.value.add(3);
          source.notify();
          expect(leafRuns, equals(2));
          expect(branchRuns, equals(2));

          length.notify();
          expect(leafRuns, equals(2));
          expect(branchRuns, equals(3));

          doubled.notify();
          expect(leafRuns, equals(3));
          expect(branchRuns, equals(4));
        },
      );

      test("re-runs nested effects subscribed to the same signal", () {
        final source = Signal(<String>["a"]);
        var outerRuns = 0;
        var innerRuns = 0;

        Effect(() {
          source.value;
          outerRuns++;
          Effect(() {
            source.value;
            innerRuns++;
          });
        });

        expect(outerRuns, equals(1));
        expect(innerRuns, equals(1));

        source.value.add("b");
        source.notify();

        expect(outerRuns, equals(2));
        expect(innerRuns, equals(2));
      });

      test(
        "re-runs inner effect on computed notify without re-running outer",
        () {
          final source = Signal(<int>[1, 2]);
          final length = Computed(() => source.value.length);
          var outerRuns = 0;
          var innerRuns = 0;

          Effect(() {
            source.value;
            outerRuns++;
            Effect(() {
              length.value;
              innerRuns++;
            });
          });

          expect(outerRuns, equals(1));
          expect(innerRuns, equals(1));

          source.value.add(3);
          source.notify();
          expect(outerRuns, equals(2));
          expect(innerRuns, equals(2));

          length.notify();
          expect(outerRuns, equals(2));
          expect(innerRuns, equals(3));
        },
      );

      test(
        "propagates selectively across nested effects and multiple signals",
        () {
          final first = Signal(<int>[1]);
          final second = Signal(<int>[2]);
          var level1Runs = 0;
          var level2Runs = 0;
          var level3Runs = 0;

          Effect(() {
            first.value;
            level1Runs++;
            Effect(() {
              first.value;
              second.value;
              level2Runs++;
              Effect(() {
                second.value;
                level3Runs++;
              });
            });
          });

          expect(level1Runs, equals(1));
          expect(level2Runs, equals(1));
          expect(level3Runs, equals(1));

          first.value.add(3);
          first.notify();
          expect(level1Runs, equals(2));
          expect(level2Runs, equals(2));
          expect(level3Runs, equals(2));

          second.value.add(4);
          second.notify();
          expect(level1Runs, equals(2));
          expect(level2Runs, equals(3));
          expect(level3Runs, equals(3));
        },
      );
    });
  });
}
