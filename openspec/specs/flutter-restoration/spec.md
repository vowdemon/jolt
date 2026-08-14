# flutter-restoration Specification

## Purpose

Defines how Jolt writable values participate in Flutter state restoration while preserving canonical reactive identity, native `RestorableProperty` behavior, and owner lifecycle safety.

## Requirements

### Requirement: Reactive values expose canonical raw identity
The advanced Jolt core API SHALL expose a canonical raw-node identity for built-in reactive values used by framework integrations. Different writable views backed by the same reactive node MUST report the same identity.

#### Scenario: Built-in reactive value exposes its node
- **WHEN** an integration inspects a Jolt signal, computed value, or Flutter notifier bridge through the advanced core API
- **THEN** it obtains the canonical reactive node backing that value

#### Scenario: Aliases share identity
- **WHEN** two writable views delegate to the same reactive node
- **THEN** integrations identify them as the same restoration target

### Requirement: Raw-node-backed writables adapt to native restoration
Every `Writable<T>` that exposes canonical raw identity SHALL be convertible to a Flutter `RestorableProperty<T>` without replacing or taking ownership of the writable.

#### Scenario: Register adapter with RestorationMixin
- **WHEN** a state owner keeps the adapter stable and registers it from `restoreState`
- **THEN** Flutter restores the wrapped writable through the ordinary `RestorationMixin` lifecycle

#### Scenario: Restore writable computed state
- **WHEN** restored data initializes a writable computed value
- **THEN** the adapter writes the restored value through the writable setter

#### Scenario: Restore Flutter notifier bridge
- **WHEN** a writable backed by a Flutter `ValueNotifier` is restored
- **THEN** the notifier and its Jolt writable view expose the restored value

#### Scenario: Reject writable without raw identity
- **WHEN** a custom writable does not expose canonical raw-node identity
- **THEN** creating a restoration adapter fails with an unsupported-operation error

### Requirement: Restoration data supports standard and custom codecs
The adapter SHALL persist values supported by Flutter's standard message codec and SHALL accept paired encoder and decoder callbacks for other value types.

#### Scenario: Restore a directly serializable value
- **WHEN** a writable contains a value supported by Flutter's standard message codec
- **THEN** the value is serialized and restored without a custom codec

#### Scenario: Restore a custom value
- **WHEN** both an encoder and decoder are supplied for a non-standard value
- **THEN** the adapter serializes through the encoder and reconstructs the writable through the decoder

#### Scenario: Reject an incomplete custom codec
- **WHEN** only an encoder or only a decoder is supplied
- **THEN** adapter construction fails with an argument error

#### Scenario: Snapshot mutable serialized collections
- **WHEN** a writable collection is mutated in place after a restoration snapshot is requested
- **THEN** previously returned restoration data remains unchanged and the new mutation is persisted through a later snapshot

### Requirement: Raw-node restoration has one active owner
A canonical raw node SHALL have at most one active restoration adapter outside Flutter bucket replacement, including when callers use different writable aliases.

#### Scenario: Reject a second active owner
- **WHEN** another adapter is created for the same raw node while its existing adapter remains active
- **THEN** creation fails with a Flutter ownership error

#### Scenario: Disposal releases ownership
- **WHEN** an adapter is disposed
- **THEN** another adapter can bind the same raw node without replacing or disposing that node

#### Scenario: Replacement hands off ownership
- **WHEN** Flutter replaces restoration data and creates the new state owner before disposing the old owner
- **THEN** the new adapter becomes authoritative and restored data is applied by the new owner

#### Scenario: Surviving replacement owner is reported
- **WHEN** the previous adapter remains undisposed after the replacement frame
- **THEN** the integration reports an ownership handoff error

### Requirement: Writable changes and restores do not form feedback loops
The adapter SHALL notify Flutter when the authoritative writable changes and SHALL suppress its own persistence notification while Flutter is initializing the writable from restoration data.

#### Scenario: Writable change updates restoration state
- **WHEN** the writable value changes after registration
- **THEN** the adapter notifies its restoration owner so the new value is serialized

#### Scenario: Restoration initialization is applied once
- **WHEN** Flutter initializes the adapter from restored data
- **THEN** the writable receives that value without the adapter treating the initialization as a new user change
