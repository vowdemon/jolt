## Purpose

Defines an explicit restoration scope for setup-based Flutter owners that restores Jolt writables and ordinary Flutter `RestorableProperty` instances through one coherent lifecycle.

## ADDED Requirements

### Requirement: Setup owners declare one explicit restoration scope
A setup owner SHALL be able to declare one restoration scope with a stable restoration identifier from setup code, and the same API SHALL work for `SetupBuilder`, `SetupWidget`, and `SetupMixin` owners.

#### Scenario: Declare after unrelated hooks
- **WHEN** setup code invokes unrelated hooks before declaring its restoration scope
- **THEN** the restoration scope is created normally and may bind later setup state

#### Scenario: Reject a second scope
- **WHEN** the same setup owner declares another restoration scope
- **THEN** setup fails with an error directing the caller to reuse the first scope

#### Scenario: Reject restoration ID change during hot reload
- **WHEN** hot reload reassembles the same restoration hook with a different scope identifier
- **THEN** reassembly fails instead of associating existing restoration data with a different namespace

### Requirement: Setup restoration binds raw-node-backed writables
The setup restoration scope SHALL bind every raw-node-backed `Writable` under a caller-provided identifier, SHALL support paired custom codecs, and SHALL preserve the writable's existing type and reactive identity.

#### Scenario: Restore a signal after owner restart
- **WHEN** a bound signal changes and Flutter recreates the setup owner from saved restoration data
- **THEN** the new signal receives the saved value before later immediate setup effects are created

#### Scenario: Restore a writable variant
- **WHEN** a writable computed or Flutter notifier-backed writable is bound
- **THEN** restoration applies through that writable's normal setter and raw node

#### Scenario: Restore multiple writables atomically
- **WHEN** Flutter replaces a bucket containing multiple bound writable values
- **THEN** setup observers see the restored values as one batched state transition

#### Scenario: Bind at runtime without another frame
- **WHEN** a writable is first bound while the scheduler is idle and no UI frame follows
- **THEN** its initial restoration data is flushed in time for an immediate owner restart

#### Scenario: Persist a post-frame change
- **WHEN** an unobserved bound writable changes during a post-frame callback and no later frame is scheduled
- **THEN** restoration data is flushed after the current frame completes

### Requirement: Setup restoration has a shared binding namespace
Writable bindings and ordinary Flutter property bindings in one setup restoration scope SHALL share a unique identifier namespace and SHALL track writable aliases by canonical raw identity.

#### Scenario: Reject duplicate identifier
- **WHEN** two current declarations use the same restoration identifier for different bindings
- **THEN** the second declaration fails with a duplicate-identifier error

#### Scenario: Rebind the same writable declaration
- **WHEN** the same writable and identifier are declared again in the current generation
- **THEN** the operation is idempotent and does not reinitialize the writable

#### Scenario: Reject one writable under two identifiers
- **WHEN** the same raw-node-backed writable is declared under another identifier in the current generation
- **THEN** the second declaration fails with an ownership error

### Requirement: Setup restoration binds ordinary Flutter properties generically
The setup restoration scope SHALL accept and own any Flutter `RestorableProperty<Object?>` subtype through one generic property-binding API, including `RestorableListenable`, `RestorableChangeNotifier`, and text-editing controller properties.

#### Scenario: Restore an ordinary property
- **WHEN** an ordinary property is bound and the setup owner restarts
- **THEN** Flutter initializes a new property instance from the saved value

#### Scenario: Restore a restorable listenable
- **WHEN** a `RestorableListenable` or `RestorableChangeNotifier` subtype is bound
- **THEN** its value is restored through its native Flutter property lifecycle

#### Scenario: Register a property conditionally
- **WHEN** setup state requires a property after the restoration host has completed its initial restore
- **THEN** the property may be bound late and consumes any saved value for its identifier

#### Scenario: Bind or unbind during reactive build
- **WHEN** a reactive builder condition adds or removes an ordinary property binding
- **THEN** host synchronization completes without calling `setState` during build

#### Scenario: Missing property host is reported
- **WHEN** ordinary properties remain bound but the setup output is not built through the restoration-aware builder
- **THEN** the scope reports a missing-host Flutter error even if binding occurred while the scheduler was idle

### Requirement: Property bindings are explicitly releasable
The setup restoration scope SHALL provide explicit unbinding for writable and ordinary-property bindings. Removing a binding SHALL remove its saved data; removing an ordinary property SHALL also unregister and dispose the property.

#### Scenario: Unbind a writable
- **WHEN** a caller unbinds a writable and the owner later restarts
- **THEN** the writable initializes from its default rather than the removed restoration data

#### Scenario: Unbind an ordinary property
- **WHEN** a caller unbinds an ordinary property
- **THEN** the host unregisters it, its saved value is removed, and the property is disposed

#### Scenario: Rebind after owner disposal
- **WHEN** a setup owner is destroyed and another owner later binds the same external raw node
- **THEN** the new owner binds successfully because the previous adapter was disposed

### Requirement: Restoration-aware setup output preserves the ancestor scope
The setup restoration scope SHALL provide a callable widget builder that hosts ordinary properties with Flutter's restoration lifecycle while descendants continue to observe the ancestor restoration scope.

#### Scenario: Reactive state rebuilds hosted output
- **WHEN** the builder reads a Jolt signal and that signal changes
- **THEN** only the hosted reactive output rebuilds with the new value

#### Scenario: Descendant reads restoration scope
- **WHEN** a descendant queries the nearest restoration scope inside the hosted output
- **THEN** it observes the original ancestor scope rather than the setup scope's internal property bucket

#### Scenario: Reject multiple widget hosts
- **WHEN** one setup restoration scope is built through more than one restoration-aware host
- **THEN** the scope reports a multiple-host ownership error

### Requirement: Restoration callbacks run after state initialization
Setup code SHALL be able to register restoration callbacks that receive the previous bucket and an initial-restore flag after bound writables and ordinary properties have been initialized for the current restoration pass.

#### Scenario: Initial restoration callback
- **WHEN** the setup restoration scope completes its first restoration pass
- **THEN** the callback receives `initialRestore` as true, no previous bucket, and initialized current values

#### Scenario: Replacement restoration callback
- **WHEN** Flutter replaces the current restoration bucket
- **THEN** the callback receives `initialRestore` as false, the previous bucket, and values initialized from the replacement bucket

### Requirement: Setup restoration follows Flutter and hot-reload lifecycles
The setup restoration scope SHALL preserve current state when ancestor restoration is toggled or moved, SHALL reconcile declarations during hot reload, and SHALL release all owned resources when its setup owner is disposed.

#### Scenario: Ancestor restoration becomes available
- **WHEN** a setup scope without an ancestor restoration bucket later receives one
- **THEN** its current writable and property values are adopted as the new restorable state

#### Scenario: Ancestor restoration is disabled and re-enabled
- **WHEN** an ancestor restoration scope temporarily becomes unavailable
- **THEN** current setup state remains active and is persisted when the ancestor returns

#### Scenario: Setup moves between ancestor scopes
- **WHEN** Flutter moves the same setup owner under a different ancestor restoration bucket without replacement
- **THEN** the existing setup bucket is adopted by the new ancestor without resetting current values

#### Scenario: Hot reload retains current declarations
- **WHEN** hot reload re-declares a binding under the same identifier and compatible type
- **THEN** the existing binding and current value are retained

#### Scenario: Hot reload removes omitted declarations
- **WHEN** a prior binding is omitted by the next setup declaration generation
- **THEN** the stale binding is removed and any owned property is disposed

#### Scenario: Hot reload changes property type
- **WHEN** an existing ordinary-property identifier is re-declared with a different runtime type
- **THEN** reassembly fails and directs the caller to use a new restoration identifier

#### Scenario: Owner disposal releases resources
- **WHEN** the setup owner is unmounted or disposed
- **THEN** the scope disposes its bucket, callbacks, writable adapters, and owned ordinary properties

### Requirement: Generic property binding replaces specialized restorable hooks
The setup public API SHALL use generic ordinary-property binding instead of exposing a dedicated restorable text-editing controller hook.

#### Scenario: Bind a text-editing controller
- **WHEN** a consumer needs a restorable text-editing controller
- **THEN** the consumer constructs `RestorableTextEditingController` and binds it as an ordinary property

#### Scenario: Inspect setup hook exports
- **WHEN** a consumer imports the public setup hook API
- **THEN** no `useRestorableTextEditingController` hook is available
