## ADDED Requirements

### Requirement: Single-package provider-free Flutter observer integration
The system SHALL provide `QueryWidget<T>`,
`InfiniteQueryWidget<T>`, and `MutationWidget<V,D,R>` inside
`jolt_query` and SHALL export them from
`package:jolt_query/jolt_query.dart`. `jolt_query` SHALL depend on Flutter and
`jolt_flutter`; this capability SHALL NOT create or require a separate
`jolt_query_flutter` package. It SHALL NOT provide QueryClientProvider,
inherited client lookup, a QueryWidget or InfiniteQueryWidget client parameter,
automatic execution, automatic Material/Cupertino presentation, Suspense, or
ErrorBoundary.

#### Scenario: One package exposes runtime and widget APIs
- **WHEN** a Flutter application imports `package:jolt_query/jolt_query.dart`
- **THEN** it can use the query runtime and ordinary, infinite, and mutation widgets without adding or importing a companion query package

#### Scenario: QueryWidget is constructed
- **WHEN** a Flutter application supplies a typed QueryTarget and builder
- **THEN** the builder receives a borrowed `QueryObserver<T>` without a client argument or provider lookup

#### Scenario: InfiniteQueryWidget is constructed
- **WHEN** a Flutter application supplies a typed InfiniteQueryTarget and builder
- **THEN** the builder receives a borrowed `InfiniteQueryObserver<T>` without a client argument or provider lookup

#### Scenario: MutationWidget is constructed
- **WHEN** a Flutter application supplies a typed Mutation recipe, optional explicit client, and builder
- **THEN** the builder receives a borrowed `MutationObserver<V,D,R>` and no mutation executes automatically

### Requirement: Query-owned client and observer lifecycle
QueryWidget and InfiniteQueryWidget SHALL resolve `query.client`, create and
own one corresponding observer for the mounted widget, and dispose that
observer at unmount without disposing the client. Updating to a target whose
resolved client is identical SHALL retain the observer and apply the new
target. Updating to another client SHALL dispose the prior observer before
creating one in the new cache universe and SHALL not carry placeholder
presentation across clients. An externally disposed client while the widget
remains mounted SHALL remain caller misuse and SHALL surface the core
disposed-client contract rather than causing a widget to invent a replacement.

#### Scenario: Widget mounts and unmounts
- **WHEN** QueryWidget is mounted and later removed
- **THEN** exactly its observer attaches and detaches while its query client remains active

#### Scenario: Query changes client
- **WHEN** a rebuilt QueryWidget receives a target bound to a different QueryClient
- **THEN** the old observer is disposed before a new observer binds the new client and key

#### Scenario: Infinite query changes client
- **WHEN** a rebuilt InfiniteQueryWidget receives a target bound to a different QueryClient
- **THEN** the old infinite observer is disposed before a new observer binds the new client and key

### Requirement: MutationWidget client and recipe lifecycle
MutationWidget SHALL use its explicit `QueryClient` when supplied and otherwise
resolve `QueryClient.defaultClient`. It SHALL create and own one
`MutationObserver<V,D,R>`, dispose only that observer at unmount, and never
execute the mutation automatically. For the same client, parent updates SHALL
call `updateMutation`: equal nullable structural MutationKeys preserve current
presentation and change only future submissions, while a changed key resets
presentation to idle. A client identity change SHALL dispose the old observer
and create an idle observer in the new client. Already submitted executions
SHALL continue under their captured recipe and client.

#### Scenario: Same-key mutation recipe is rebuilt
- **WHEN** a parent supplies a new Mutation instance with an equal nullable structural key
- **THEN** MutationWidget preserves observer presentation and the next explicit execution uses the new recipe

#### Scenario: Mutation key changes
- **WHEN** a parent supplies a Mutation with a different nullable structural key
- **THEN** the retained observer resets to idle without cancelling an earlier execution

#### Scenario: Mutation client changes
- **WHEN** a parent changes MutationWidget to another QueryClient
- **THEN** the prior observer is disposed and a new idle observer is created without disposing either client

### Requirement: Explicit Flutter application lifecycle focus binding
`QueryClient.bindFlutterLifecycle()` SHALL install one explicitly owned Flutter application lifecycle listener, initialize the client's FocusManager from the current lifecycle state, map resumed to focused and non-resumed application states to unfocused, and return an idempotent Disposable that removes only that listener. No query observer widget SHALL install this binding implicitly, and disposing the binding SHALL NOT dispose the client.

#### Scenario: Application resumes
- **WHEN** an installed lifecycle binding observes the application return to resumed
- **THEN** the bound client's focus manager becomes focused and eligible stale observers may perform their configured focus refetch

#### Scenario: Lifecycle binding is disposed
- **WHEN** the returned binding is disposed twice
- **THEN** its listener is removed once and the QueryClient remains active

### Requirement: Target updates preserve query semantics
For one client, QueryWidget and InfiniteQueryWidget SHALL each preserve one
corresponding observer across target updates. A different key SHALL switch
cache entries and preserve ordinary previous-presentation placeholder behavior.
A new target instance with the same key SHALL update its plan and observer
presentation configuration without detaching, reattaching, resetting mount
completion state, or re-running `refetchOnMount`. Flutter Widget keys SHALL not
participate in Query cache identity.

#### Scenario: Parent rebuilds with an equivalent key
- **WHEN** a parent rebuild creates a new immediately-stale query instance with the same client and structural key
- **THEN** QueryWidget updates the target without another query-function invocation caused by mount policy

#### Scenario: Parent changes the query key
- **WHEN** a parent rebuild supplies a target with a different structural key
- **THEN** the same observer switches to that key, publishes its cache/presentation state, and starts work only under ordinary activation policy

#### Scenario: Previous presentation is configured as placeholder
- **WHEN** the new key is absent and its placeholder resolver returns the prior presentation
- **THEN** the builder sees observer-local placeholder data while the new cache entry remains absent until real data commits

#### Scenario: Infinite target is rebuilt with the same key
- **WHEN** a parent supplies a new InfiniteQueryTarget instance with the same client and structural key
- **THEN** InfiniteQueryWidget updates its retained observer without mount refetch or loss of directional presentation

### Requirement: Whole-result Flutter rebuilding without implicit Jolt builder tracking
Each observer widget SHALL subscribe to its complete observer value using the
existing Jolt Flutter watcher behavior and invoke an ordinary Flutter builder
with the borrowed observer. It SHALL NOT wrap the user builder in JoltBuilder
or implicitly subscribe to other Jolt values read inside it. Query-driven
rebuilds SHALL occur when the currently bound cache transition changes the
complete observer result, the target key/client binding changes, or
observer-local status changes. Mutation-driven rebuilds SHALL occur when the
owned mutation observer's complete presentation changes or the widget applies
a recipe/client transition. Cache events for unrelated keys or executions
SHALL not rebuild a widget. Normal Flutter parent updates and
inherited-dependency changes SHALL retain ordinary Flutter behavior.

#### Scenario: Current cache data changes
- **WHEN** the bound cache entry accepts new data
- **THEN** the complete observer result notifies and QueryWidget rebuilds with the latest observer

#### Scenario: Observer fetch state changes
- **WHEN** fetching, paused, stale, placeholder, success, or failure presentation changes
- **THEN** QueryWidget rebuilds from the complete result even when selected data identity is retained

#### Scenario: Unrelated cache entry changes
- **WHEN** another structural key in the same QueryClient changes
- **THEN** QueryWidget does not rebuild from that cache event

#### Scenario: Builder reads another Jolt signal
- **WHEN** the builder reads an unrelated Jolt signal without an enclosing application-owned reactive widget
- **THEN** the observer widget does not make that signal a dependency or rebuild when only it changes

#### Scenario: Infinite directional state changes
- **WHEN** an infinite direction starts, fails, or succeeds
- **THEN** InfiniteQueryWidget rebuilds from the complete infinite observer result

#### Scenario: Mutation settles
- **WHEN** MutationWidget's observer reaches success or error
- **THEN** the widget rebuilds from that terminal result without requiring a parent rebuild
