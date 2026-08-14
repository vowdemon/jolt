## 1. Expose Canonical Reactive Identity

- [x] 1.1 Add `RawNodeProvider` to the advanced core API as a non-owning canonical reactive-node identity contract.
- [x] 1.2 Implement raw-node identity on Jolt signal and computed implementations without exporting the provider from the primary `jolt.dart` surface.
- [x] 1.3 Implement raw-node identity on the Flutter `ValueNotifier` signal bridge so notifier-backed writables use the same integration path.

## 2. Add the Native Flutter Restoration Adapter

- [x] 2.1 Implement `WritableRestorationProperty<T>` and `Writable.toRestorationProperty()` with native `RestorableProperty` initialization, change notification, and disposal semantics.
- [x] 2.2 Add paired encoder/decoder support, standard-message-codec defaults, stable default snapshots, and immutable structured restoration snapshots.
- [x] 2.3 Enforce one active adapter per canonical raw node, allow Flutter replacement-time handoff, and report old owners that survive the replacement frame.
- [x] 2.4 Export the restoration adapter and codec types from the public `jolt_flutter` library.

## 3. Add Setup-Scoped Restoration

- [x] 3.1 Add `useRestorationScope(restorationId)` with one `SetupRestoration` session per setup owner and support it across `SetupBuilder`, `SetupWidget`, and `SetupMixin`.
- [x] 3.2 Implement raw-node-backed writable binding, custom codecs, shared ID validation, explicit unbinding, atomic bucket replacement, and timely idle/post-frame serialization.
- [x] 3.3 Implement generic `RestorableProperty` binding and unbinding with one private `RestorationMixin` host, late conditional registration, property ownership, and missing/multiple-host validation.
- [x] 3.4 Add restoration callbacks that run after writable and ordinary-property initialization with previous-bucket and initial-restore information.
- [x] 3.5 Reconcile binding declarations during hot reload, preserve state across ancestor restoration-scope changes, and release buckets, adapters, callbacks, and owned properties on disposal.
- [x] 3.6 Export the restoration hook and session from the public `jolt_setup` hook barrel.

## 4. Consolidate Restorable Property APIs

- [x] 4.1 Remove `useRestorableTextEditingController` and its type-specific creator from the setup text hooks.
- [x] 4.2 Replace specialized-controller coverage with generic `bindProperty` coverage for `RestorableTextEditingController`, `RestorableListenable`, and `RestorableChangeNotifier` behavior.

## 5. Verify Restoration Behavior

- [x] 5.1 Test native restoration for signals, writable computed values, notifier bridges, mutable collections, custom codecs, bucket replacement, owner handoff, and disposal/rebinding.
- [x] 5.2 Test setup restoration for writables, ordinary properties, callbacks, runtime and reactive conditional registration, explicit unbinding, hot reload, ancestor-scope transitions, and all setup owner forms.
- [x] 5.3 Test duplicate IDs, raw-node aliases, missing hosts, disposed owners, atomic replacement, and scheduler-phase serialization boundaries.
- [x] 5.4 Format and analyze the affected packages and run the full `jolt`, `jolt_flutter`, and `jolt_setup` test suites.
