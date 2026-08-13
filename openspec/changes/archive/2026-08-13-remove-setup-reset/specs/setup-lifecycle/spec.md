## Purpose

Defines how a Jolt setup scope is created, retained, updated, and disposed in relation to the lifetime of its owning Flutter element or state.

## ADDED Requirements

### Requirement: Setup scope follows its Flutter owner lifetime
The setup runtime SHALL create one setup scope for the lifetime of the owning `SetupWidget` element or `SetupMixin` state and SHALL dispose that scope when the owner is unmounted or disposed. Debug hot-reload reconciliation MAY re-execute setup code without changing this runtime lifetime contract.

#### Scenario: Reactive rebuild retains the setup scope
- **WHEN** a reactive dependency used by the returned widget builder changes
- **THEN** the runtime rebuilds the rendered widget without rerunning setup or recreating setup-owned hooks

#### Scenario: Parent update retains the setup scope
- **WHEN** a parent supplies an updated widget with the same runtime type and key
- **THEN** the existing setup scope remains active and receives the normal property and widget lifecycle updates

#### Scenario: Owner disposal disposes the setup scope
- **WHEN** the owning element is unmounted or the owning state is disposed
- **THEN** the runtime unmounts setup hooks and disposes setup-owned reactive resources

### Requirement: Setup recreation uses Flutter owner replacement
The setup runtime SHALL create a fresh setup scope when Flutter replaces the owning element or state, including replacement caused by a changed key.

#### Scenario: Key change creates a fresh setup scope
- **WHEN** a parent rebuilds a setup-based widget with a different key
- **THEN** Flutter disposes the previous owner and the setup runtime initializes a fresh setup scope for the new owner

### Requirement: Runtime setup reset is not part of the public API
The `jolt_setup` public API SHALL NOT expose a hook, setup context operation, setup element operation, or setup mixin operation that tears down and reruns setup while retaining the same Flutter owner.

#### Scenario: Consumer inspects setup APIs
- **WHEN** a consumer imports the public `jolt_setup` library
- **THEN** no runtime setup-reset hook or in-place setup-reset method is available

#### Scenario: External state changes
- **WHEN** a signal, selected value, listenable, inherited dependency, or widget property changes
- **THEN** the setup scope remains active and the consumer handles the change through the corresponding reactive, listener, synchronization, or lifecycle API
