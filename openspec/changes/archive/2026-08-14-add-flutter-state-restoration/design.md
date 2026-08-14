## Context

See `proposal.md` for motivation. Flutter state restoration is centered on `RestorationMixin`, `RestorationBucket`, and stable `RestorableProperty` instances owned by a `State`. Jolt state is instead represented by multiple public writable views whose true identity is their internal reactive node. Setup-based widgets add another ownership model: setup runs once per owner, works across three owner forms, and does not directly expose a `State` subclass where callers can mix in `RestorationMixin`.

The design must therefore support both native Flutter code and setup code without introducing a parallel family of restorable signal types. It must also follow Flutter's bucket-replacement order, preserve setup hot-reload reconciliation, accept Flutter's existing property subclasses, and dispose adapters before a raw node can be bound by another owner.

## Goals / Non-Goals

**Goals:**

- Make an existing Jolt `Writable` usable as a native Flutter `RestorableProperty` without changing its public writable subtype.
- Identify restoration ownership by canonical raw node so aliases cannot create competing adapters.
- Give setup owners one low-intrusion restoration session that works across `SetupBuilder`, `SetupWidget`, and `SetupMixin`.
- Support both Jolt writable bindings and arbitrary Flutter `RestorableProperty` bindings with native restoration semantics.
- Preserve values across process restart, bucket replacement, ancestor-scope changes, hot reload, runtime conditional registration, and owner recreation.
- Keep data serialization timely without forcing restoration serialization in the middle of a Flutter frame.

**Non-Goals:**

- Add a parallel `RestorableSignal` hierarchy or change existing signal, computed, collection, or notifier-bridge types.
- Automatically enable application-level restoration when no ancestor bucket exists.
- Add type-specific setup hooks for individual `RestorableProperty` subclasses.
- Expose raw-node identity from the primary `jolt.dart` API; it remains an advanced integration contract.

## Decisions

### Use canonical raw-node identity as the integration boundary

Add `RawNodeProvider` to the advanced core API and implement it on Jolt signal/computed implementations and the Flutter `ValueNotifier` signal bridge. Restoration ownership and setup writable lookup are keyed by the returned raw node, not by the public wrapper object.

This makes every current writable variant eligible without adding variant-specific adapters, and it ensures aliases over one node share ownership. The interface describes identity only; it does not imply that an integration owns or may dispose the node.

Alternative considered: define signal-specific and writable-specific provider interfaces. This was rejected because the relevant property is reactive identity, not a particular read/write surface, and separate interfaces would recreate the variant hierarchy inside integrations.

Alternative considered: convert writables into a new `RestorableSignal` type. This was rejected because conversion changes the user's type graph and creates a parallel state container instead of restoring the existing node.

### Adapt a writable with a native RestorableProperty

`WritableRestorationProperty<T>` extends Flutter's `RestorableProperty<T>` and holds a detached Jolt effect that observes the existing writable. Flutter initialization writes through the writable setter; ordinary writable changes notify the property owner. A restoration guard prevents Flutter initialization from being reflected back as a new user-originated change.

The default value is snapshotted at adapter creation through `StandardMessageCodec`. Primitive values are returned directly during later serialization, while structured values are codec-round-tripped so mutable collections returned to Flutter cannot be changed in place afterward. Paired encoder and decoder callbacks support application types outside the standard codec.

Alternative considered: manually read and write buckets from every native `State`. This was rejected because it would bypass `RestorationMixin` registration, enabled-state handling, and the familiar Flutter ownership pattern.

### Enforce one adapter per raw node with replacement-aware handoff

An `Expando` associates the canonical raw node with its active adapter. Creating a second adapter normally fails, including through another writable alias. Disposal clears the association but never disposes the writable.

Flutter may create a new state owner before disposing the old one during restoration-bucket replacement. During that replacement window, the new adapter becomes authoritative immediately and the old adapter ignores initialization. A post-frame check reports an error if the old owner did not dispose its adapter by the end of the replacement frame.

Alternative considered: reject all overlaps. This was rejected because it prevents valid Flutter owner replacement for externally owned writables.

### Use one setup session with two restoration paths

`useRestorationScope(restorationId)` creates one `SetupRestoration` session per setup owner. The session claims a child bucket from the nearest ancestor restoration scope and stores raw-node-backed writable snapshots directly in that child bucket. Direct writable bindings therefore do not require a widget host.

Ordinary Flutter properties still need `RestorationMixin`. Calling the session as `restoration(() => widget)` inserts one private stateful host. The host sees the setup child bucket as its restoration parent, registers ordinary properties in a fixed internal child namespace, and then restores the original ancestor scope for descendants.

```text
ancestor RestorationBucket
          │
          └─ setup restorationId bucket
                 ├─ writable values
                 └─ internal property-host bucket
                        └─ Flutter RestorableProperty values

descendant widget context ──────────────► ancestor scope
```

This split keeps setup owner classes and `SetupContext` free of restoration mixins while letting native property subclasses execute through Flutter's own closed lifecycle.

Alternative considered: add restoration behavior directly to every setup owner class. This was rejected because it couples the base setup runtime to an optional Flutter feature and duplicates behavior across owner forms.

Alternative considered: make setup automatically create an application restoration scope. This was rejected because root restoration remains an application decision and must use Flutter's normal `MaterialApp.restorationScopeId` or root scope APIs.

### Bind ordinary properties by instance through one generic API

`bindProperty(property, id:)` accepts an already-created `RestorableProperty` and takes ownership of that property. The same path supports scalar restorable values, `RestorableListenable`, `RestorableChangeNotifier`, and `RestorableTextEditingController`. Explicit unbinding unregisters and disposes the property.

The API accepts an instance rather than a factory because callers already construct native Flutter properties that way, and conditional runtime registration does not need hook-style creation. During hot reload, a newly supplied compatible property is disposed and the existing instance is retained; changing the runtime type under an existing ID is rejected because the persisted data format may differ.

Alternative considered: add forwarding APIs such as `bindListenable` and `bindChangeNotifier`. This was rejected because they add no behavior beyond the generic property bound.

Alternative considered: retain `useRestorableTextEditingController`. This was rejected because a type-specific hook creates a second lifecycle path and does not generalize to other restorable notifier types.

### Reconcile bindings by generation, ID, and identity

The setup session maintains one binding namespace by restoration ID, an identity map for raw writable targets, and an identity map for ordinary properties. Each setup execution advances a declaration generation. Re-declared compatible bindings are retained; declarations omitted by the next generation are removed and disposed.

The distinct indexes serve independent contracts:

- ID lookup prevents writable/property collisions and locates saved data.
- Raw-node lookup makes writable aliases idempotent and enforces one active restoration owner.
- Property identity lookup supports explicit unbinding and native registration tracking.

This preserves setup hot-reload behavior without making binding calls into independent hooks.

### Coordinate bucket replacement before callbacks

On ancestor bucket replacement, the session claims its replacement child, restores all direct writables inside one Jolt batch, and lets the private host re-register ordinary properties through `RestorationMixin.restoreState`. Restoration callbacks run in a microtask after both paths have initialized, receiving the previous setup bucket and Flutter-compatible `initialRestore` semantics. Superseded pending old buckets are disposed, and the bucket passed to the final callback remains valid until that callback returns.

When an ancestor scope is added, removed, or changed without replacement, the current setup state is preserved: an existing child bucket is adopted by the new parent, or current values seed a newly available bucket.

### Make registration and serialization scheduler-safe

Writable bucket changes request an explicit restoration flush only when Flutter would otherwise have no frame to serialize them:

- During `SchedulerPhase.idle`, flush immediately.
- During post-frame callbacks, schedule a microtask so the current frame fully completes before flushing.
- During transient, mid-frame, and persistent phases, rely on the current frame's queued restoration serialization.

This avoids losing runtime or post-frame changes while preventing bucket finalization during build or owner handoff.

Ordinary property binding changes synchronize through the private host. Host `setState` is deferred to a microtask when synchronization occurs during persistent callbacks, preventing ancestor `setState` during descendant build. Missing-host validation uses a post-frame callback plus `ensureVisualUpdate()` so runtime misuse is reported even when the scheduler was idle.

## Risks / Trade-offs

- [A custom writable has no canonical raw node] → Reject it explicitly; integrations require `RawNodeProvider` so ownership cannot silently diverge across aliases.
- [Persisted data no longer matches a property's codec or runtime type] → Require paired codecs and reject ordinary-property type changes under an existing ID; callers use a new restoration ID for schema changes.
- [A caller builds one setup session through multiple widget hosts] → Reject the second host because one native property set cannot be registered with multiple `RestorationMixin` owners.
- [A caller binds ordinary properties but omits the restoration-aware builder] → Report a Flutter error after the frame and ensure an idle runtime binding still receives a validation frame.
- [Structured serialization adds codec-copy cost] → Return immutable primitives directly and copy only structured values that Flutter requires to remain unchanged.
- [Post-frame changes could wait forever for another frame] → Flush in a microtask after the current frame when no new frame is scheduled.
- [External code uses the removed specialized controller hook] → Migrate to `restoration.bindProperty(RestorableTextEditingController(...), id: ...)`, which also covers other restorable notifier types.

## Migration Plan

1. Expose canonical raw identity from the advanced core API and implement it on built-in reactive values used by Flutter integrations.
2. Export the native writable restoration adapter from `jolt_flutter` and verify native `RestorationMixin` registration, codecs, owner handoff, and disposal.
3. Export the setup restoration hook/session, private property host, writable/property binding lifecycle, callbacks, and hot-reload reconciliation.
4. Replace uses of `useRestorableTextEditingController` with a `RestorableTextEditingController` passed to `SetupRestoration.bindProperty()` and build the affected output through the restoration session.
5. Verify direct writables, ordinary properties, notifier-backed properties, conditional registration, ancestor-scope transitions, process restart, bucket replacement, and owner disposal across all setup owner forms.

Rollback is a normal source revert. Previously written restoration entries are namespaced by Flutter bucket IDs and become inert if the corresponding feature code is removed.
