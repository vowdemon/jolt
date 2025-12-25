import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("shared", () {
    group("JoltAttachments", () {
      test("should trigger disposal on signal dispose", () {
        final signal = Signal(0);
        var count = 0;

        JFinalizer.attachToJoltAttachments(signal, () {
          count++;
        });

        expect(JFinalizer.getJoltAttachments(signal), isNotEmpty);

        signal.dispose();

        expect(count, equals(1));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);
      });

      test("should be idempotent when manually disposing attachments", () {
        final signal = Signal(0);
        var count = 0;

        JFinalizer.attachToJoltAttachments(signal, () {
          count++;
        });

        expect(JFinalizer.getJoltAttachments(signal), isNotEmpty);

        JFinalizer.disposeObject(signal);

        expect(count, equals(1));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);

        JFinalizer.disposeObject(signal);

        expect(count, equals(1));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(1));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);
      });

      test("should allow manual detachment by calling returned disposer", () {
        final signal = Signal(0);
        var count = 0;

        final disposer = JFinalizer.attachToJoltAttachments(signal, () {
          count++;
        });

        expect(JFinalizer.getJoltAttachments(signal), isNotEmpty);
        expect(count, equals(0));

        disposer();

        expect(count, equals(0));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(0));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);
      });

      test("should detach using detachFromJoltAttachments", () {
        final signal = Signal(0);
        var count = 0;

        void originalDisposer() {
          count++;
        }

        JFinalizer.attachToJoltAttachments(signal, originalDisposer);

        expect(JFinalizer.getJoltAttachments(signal), isNotEmpty);
        expect(count, equals(0));

        JFinalizer.detachFromJoltAttachments(signal, originalDisposer);

        expect(count, equals(0));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(0));
        expect(JFinalizer.getJoltAttachments(signal), isEmpty);
      });

      test("should work with effect nodes", () {
        final effectNode = _TestEffectNode();
        var count = 0;

        JFinalizer.attachToJoltAttachments(effectNode, () {
          count++;
        });

        expect(count, equals(0));
        expect(effectNode.isDisposed, isFalse);

        effectNode.dispose();

        expect(count, equals(1));
        expect(effectNode.isDisposed, isTrue);
      });
    });
  });
}

class _TestEffectNode with DisposableNodeMixin implements EffectNode {
  _TestEffectNode() : super();
}
