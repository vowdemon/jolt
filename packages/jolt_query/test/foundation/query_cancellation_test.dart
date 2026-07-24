import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('cancellation carries reason, future, listeners, and consumption',
      () async {
    final controller = QueryCancellationController();
    final reasons = <Object?>[];

    expect(controller.wasConsumed, isFalse);
    final remove = controller.token.addListener(reasons.add);
    expect(controller.wasConsumed, isTrue);

    expect(controller.cancel('replaced'), isTrue);
    expect(controller.cancel('again'), isFalse);
    expect(reasons, <Object?>['replaced']);
    expect(await controller.token.whenCancelled, 'replaced');
    expect(controller.token.reason, 'replaced');
    expect(
      controller.token.throwIfCancelled,
      throwsA(
        isA<QueryCancelledException>()
            .having((error) => error.reason, 'reason', 'replaced'),
      ),
    );
    remove();
  });

  test('removed listeners are not invoked', () {
    final controller = QueryCancellationController();
    var called = false;
    final remove = controller.token.addListener((_) => called = true);

    remove();
    controller.cancel();

    expect(called, isFalse);
  });
}
