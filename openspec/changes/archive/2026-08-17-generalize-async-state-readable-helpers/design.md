## Context

See `proposal.md` for motivation and `specs/async-state-readable-helpers/spec.md` for behavior. `AsyncState<T>` already owns variant inspection and mapping. `AsyncSignal<T>` repeats that API, and `AsyncSignalImpl<T>` implements each member by reading `value` and delegating to the state. Jolt already exposes general utilities as extensions on `Readable<T>`, so async-state views can follow the same public pattern.

## Goals / Non-Goals

**Goals:**

- Give every `Readable<AsyncState<T>>` one consistent inspection and mapping surface.
- Preserve tracked reads by evaluating each helper through `Readable.value`.
- Remove pure delegation requirements from `AsyncSignal` and its implementation.
- Keep ordinary statically typed `AsyncSignal` call sites source-compatible when the public Jolt library is imported.

**Non-Goals:**

- Changing `AsyncState` variants, nullability, or mapping behavior.
- Changing source subscription, replacement, completion, error, or disposal behavior.
- Adding mutation, refresh, retry, cancellation, or loading-transition helpers.
- Making extension helpers available through `dynamic` dispatch.
- Changing low-level reactive nodes or the general `Readable<T>` interface.

## Decisions

### Extend Readable async-state values

Declare the public extension next to `AsyncSignal` in `src/jolt/async.dart`:

```dart
extension AsyncStateReadableX<T> on Readable<AsyncState<T>> {
  T? get data => value.data;
  bool get isLoading => value.isLoading;
  bool get isSuccess => value.isSuccess;
  bool get isError => value.isError;
  Object? get error => value.error;
  StackTrace? get stackTrace => value.stackTrace;

  R? map<R>({
    R Function()? loading,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  }) => value.map(
        loading: loading,
        success: success,
        error: error,
      );
}
```

`Readable<AsyncState<T>>` is the narrowest receiver that owns the required operation: a normal current-value read. It covers signals, computed values, readonly views, and compatible adapters without exposing writes or source control. The name describes the value and receiver rather than implying that every receiver is an `AsyncSignal`.

Keep the existing prefer-inline pragmas on `map`; trivial getters can rely on normal compiler inlining unless measurement or project convention justifies additional hints.

Alternative considered: extend only `AsyncSignal<T>`. This removes implementation delegation but preserves the unnecessary restriction and gives no benefit to computed or read-only async states.

Alternative considered: add more helpers to `AsyncState<T>`. The state already has the relevant API; this would not remove `signal.value` at readable call sites or share tracked access.

### Remove helper members from AsyncSignal

Remove `data`, state flags, error views, stack trace, and `map` from the `AsyncSignal<T>` interface and delete their overrides from `AsyncSignalImpl<T>`. Keep the factories and `fetch` on `AsyncSignal`; those operations create or control the source and therefore belong to the signal abstraction.

Extension methods are statically resolved. A caller whose receiver has static type `AsyncSignal<T>` or `Readable<AsyncState<T>>` continues to use the same call syntax after importing `package:jolt/jolt.dart`. A receiver erased to `dynamic` or `Object` no longer receives these helpers, and a custom implementation cannot override their meaning. This is intentional because the helpers are defined solely by `value` and should not vary across implementations.

Alternative considered: retain the interface members while also adding the extension. Members always win over extensions, so async signals would keep duplicated implementations and could diverge from other readable views.

Alternative considered: introduce a mixin with concrete members. It preserves dynamic member dispatch but requires every implementation to adopt the mixin and still restricts helpers to participating classes, adding more structure than the fixed derivation warrants.

### Test the shared contract at the readable boundary

Keep existing `AsyncState` variant tests and `AsyncSignal` source lifecycle tests. Move convenience-helper expectations to tests whose variables are statically typed as `Readable<AsyncState<T>>`, and cover an async signal, a computed async state, and a readonly async-state view. Add a reactive tracking test that reads an extension helper inside an effect or computed value and observes state replacement.

This proves the generalized contract without binding tests to the removed forwarding implementation. Existing lifecycle tests protect the non-goal that `fetch` and disposal behavior remain unchanged.

## Risks / Trade-offs

- **[Dynamic calls stop resolving]** Code using a `dynamic` async signal cannot invoke the removed instance members. → Mark the API change as breaking and document retaining a static `AsyncSignal<T>` or `Readable<AsyncState<T>>` type, or reading `value` directly.
- **[Custom overrides stop participating]** Implementations that customized helper results lose that override point. → Define helpers as fixed projections of `value`; callers needing different semantics create their own named extension or wrapper.
- **[Extension availability depends on imports]** Narrow imports that expose types without the extension may lose helper resolution. → Export the extension from the same public async library and use `package:jolt/jolt.dart` in public examples.
- **[Common method name]** `map` can collide with another applicable extension. → Use the specific `Readable<AsyncState<T>>` receiver; concrete members continue to take precedence under Dart resolution.
- **[Generated API location changes]** Documentation lists helpers under an extension rather than `AsyncSignal`. → Update Dartdoc, tutorials, and the Jolt skill reference to point users to the shared readable API.

## Migration Plan

1. Add the extension and shared readable-boundary tests while the existing members still take precedence.
2. Remove helper declarations and forwarding overrides, then verify ordinary async-signal calls resolve through the extension.
3. Add computed, readonly, mapping, and dependency-tracking coverage.
4. Update API documentation, tutorials, and Jolt skill references with shared readable examples and the dynamic-dispatch caveat.
5. Run formatting, analysis, focused async tests, the full Jolt suite, skill validation, and strict OpenSpec validation.

Rollback restores the `AsyncSignal` member declarations and `AsyncSignalImpl` forwarding overrides; `AsyncState` values and persisted or external data require no migration.
