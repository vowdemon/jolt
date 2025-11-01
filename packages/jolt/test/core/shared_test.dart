import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/shared.dart';
import 'package:test/test.dart';

void main() {
  group('shared', () {
    group('JoltAttachments', () {
      test('should trigger disposal on signal dispose', () {
        final signal = Signal(0);
        int count = 0;

        attachToJoltAttachments(signal, () {
          count++;
        });

        expect(getJoltAttachments(signal), isNotEmpty);

        signal.dispose();

        expect(count, equals(1));
        expect(getJoltAttachments(signal), isEmpty);
      });

      test('should be idempotent when manually disposing attachments', () {
        final signal = Signal(0);
        int count = 0;

        attachToJoltAttachments(signal, () {
          count++;
        });

        expect(getJoltAttachments(signal), isNotEmpty);

        manuallyDisposeJoltAttachments(signal);

        expect(count, equals(1));
        expect(getJoltAttachments(signal), isEmpty);

        manuallyDisposeJoltAttachments(signal);

        expect(count, equals(1));
        expect(getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(1));
        expect(getJoltAttachments(signal), isEmpty);
      });

      test('should allow manual detachment by calling returned disposer', () {
        final signal = Signal(0);
        int count = 0;

        final disposer = attachToJoltAttachments(signal, () {
          count++;
        });

        expect(getJoltAttachments(signal), isNotEmpty);
        expect(count, equals(0));

        disposer();

        expect(count, equals(0));
        expect(getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(0));
        expect(getJoltAttachments(signal), isEmpty);
      });

      test('should detach using detachFromJoltAttachments', () {
        final signal = Signal(0);
        int count = 0;

        void originalDisposer() {
          count++;
        }

        attachToJoltAttachments(signal, originalDisposer);

        expect(getJoltAttachments(signal), isNotEmpty);
        expect(count, equals(0));

        detachFromJoltAttachments(signal, originalDisposer);

        expect(count, equals(0));
        expect(getJoltAttachments(signal), isEmpty);

        signal.dispose();

        expect(count, equals(0));
        expect(getJoltAttachments(signal), isEmpty);
      });
    });
  });
}
