import 'package:jolt/jolt.dart' show Readable;
import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('barrel exposes the unified typed mutation surface', () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    client.registerMutationDefaults(
      const MutationDefaults(networkMode: NetworkMode.always),
      key: MutationKey(<Object?>['public']),
    );
    final MutationCache cache = client.mutationCache;
    final Readable<int> count = client.mutatingCount;
    final MutationObserver<int, int, String> observer = client.observeMutation(
      mutation<int, int, String>(
        key: MutationKey(<Object?>['public', 'save']),
        onMutate: (variables, context) => 'before:$variables',
        mutate: (variables, context) => variables + 1,
      ),
    );

    expect(await observer.execute(1), 2);
    await Future<void>.delayed(Duration.zero);
    expect(cache.snapshots.single.data.requireValue(), 2);
    expect(
      observer.snapshot.onMutateResult,
      const QueryPresent<String>('before:1'),
    );
    expect(count.peek, 0);

    final MutationObserver<NoVariables, String, void> actionObserver =
        client.observeMutation(
      action<String, void>(mutate: (context) => 'done'),
    );
    expect(await actionObserver.run(), 'done');
    expect(
      await client.executeAction(
        action<int, void>(mutate: (context) => 3),
      ),
      3,
    );
  });

  test('action observer preserves typed onMutate result', () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final MutationObserver<NoVariables, int, String?> observer =
        client.observeMutation(
      action<int, String?>(
        onMutate: (context) => null,
        mutate: (context) => 8,
      ),
    );

    expect(await observer.run(), 8);
    await Future<void>.delayed(Duration.zero);
    expect(observer.snapshot.data, const QueryPresent<int>(8));
    expect(
      observer.snapshot.onMutateResult,
      const QueryPresent<String?>(null),
    );
  });
}
