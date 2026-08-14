## Why

Jolt writable state currently has no supported bridge to Flutter's state-restoration system, and setup-based widgets cannot participate in `RestorationMixin` without adding a separate `State` mixin and lifecycle layer. Jolt needs a native restoration adapter plus a setup-scoped API that preserves raw-node identity and remains compatible with Flutter's existing `RestorableProperty` types.

## What Changes

- Add a canonical raw-node identity contract for Jolt reactive implementations so framework adapters can recognize aliases of the same reactive state.
- Add a `jolt_flutter` `WritableRestorationProperty` adapter and `Writable.toRestorationProperty()` extension for native `RestorationMixin` usage, including custom serialization codecs and raw-node ownership handoff during bucket replacement.
- Add `useRestorationScope()` and `SetupRestoration` to `jolt_setup`, with APIs for binding raw-node-backed `Writable` values, binding ordinary Flutter `RestorableProperty` instances, explicit unbinding, restoration callbacks, and a restoration-aware widget builder.
- Support restoration across `SetupBuilder`, `SetupWidget`, and `SetupMixin`, including late and conditional property registration, hot reload, ancestor-scope changes, bucket replacement, owner disposal, and restoration without unnecessary frame scheduling.
- **BREAKING** Remove the specialized `useRestorableTextEditingController` hook. Consumers bind `RestorableTextEditingController` and other `RestorableListenable` or `RestorableChangeNotifier` implementations through the generic `SetupRestoration.bindProperty()` API.

## Capabilities

### New Capabilities

- `flutter-restoration`: Defines the native Flutter restoration adapter for Jolt writables, raw-node identity, serialization, and restoration-owner lifecycle.
- `setup-restoration`: Defines setup-scoped restoration, writable and ordinary-property bindings, restoration callbacks, widget hosting, and setup-owner lifecycle behavior.

### Modified Capabilities

None.

## Impact

- Affected core APIs: `RawNodeProvider` in the advanced `jolt/core.dart` surface and its implementation by Jolt signals, computed values, and Flutter `ValueNotifier` bridges.
- Affected Flutter APIs: the public `jolt_flutter` library exports restoration codecs, `WritableRestorationProperty`, and `Writable.toRestorationProperty()`.
- Affected setup APIs: the public `jolt_setup` hook barrel exports `useRestorationScope` and `SetupRestoration`; the specialized restorable text-controller hook is removed.
- Affected runtime behavior: restoration data follows Flutter bucket replacement, setup hot reload, ancestor restoration-scope movement, runtime registration, disposal, and raw-node owner handoff.
- No new package dependencies are introduced.
