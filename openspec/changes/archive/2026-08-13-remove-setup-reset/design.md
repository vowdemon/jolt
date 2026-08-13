## Context

See `proposal.md` for motivation. Today `SetupContext` receives an owner callback for tearing down and rebuilding setup, tracks frame-level reset scheduling, and exposes that machinery to both setup owners. `SetupWidgetElement` and `SetupMixin` each duplicate the teardown-and-recreate sequence, while `useSetupReset` adds manual, `Listenable`, reactive-source, and selector triggers on top.

The reset path is independent from debug hot-reload reconciliation. Hot reload uses hook-index reconciliation to preserve compatible hook state, whereas runtime reset destroys the entire hook sequence. The package is currently on the v4 prerelease line, so this is the appropriate release boundary for removing the public behavior without adding another compatibility layer.

## Goals / Non-Goals

**Goals:**

- Remove all public and internal machinery whose sole purpose is restarting setup in place.
- Make the production setup-scope lifetime match the lifetime of its owning Flutter element or state.
- Preserve normal reactive rendering, widget lifecycle forwarding, resource disposal, and debug hot-reload reconciliation.
- Leave consumers with established migration paths: targeted reactive updates for ordinary changes and Flutter owner replacement for complete reinitialization.
- Keep verification focused on the remaining lifecycle contract rather than deleted implementation details.

**Non-Goals:**

- Introduce a replacement reset abstraction, dependency-aware memoization API, or key-management helper.
- Change signal, effect, listener, synchronization, timer, or controller semantics.
- Rename or remove unrelated operations such as `_resetHookIndex()`, `TimerHook.reset()`, or application-defined local reset methods.
- Modify repository or package changelog files in this change.

## Decisions

### Remove the complete in-place reset path

Remove the hook namespace, its reset-only hook implementations, the `SetupContext` callback and scheduler, and the element/mixin entry points together. Removing only `useSetupReset` would leave a destructive lifecycle operation exposed through `SetupContext`, `SetupWidgetElement`, and `SetupMixin`, along with duplicated owner implementations that have no internal caller.

Alternative considered: keep the owner and context methods as an advanced API. This was rejected because it preserves the ambiguous dual lifetime model and continues to require reset-specific runtime state and tests.

### Use Flutter owner replacement as the full-reinitialization boundary

Consumers that truly require a clean setup scope will change the setup-based widget's key from a parent. Flutter will then dispose the old owner and create a new owner with a fresh setup scope. This aligns setup resource ownership with normal Flutter lifecycle behavior.

Alternative considered: add a Jolt-specific restart widget or generation helper. This was rejected because Flutter keys already express the behavior and a wrapper would add API surface without new capability.

Targeted state, side-effect, subscription, asynchronous-source, and controller updates remain owned by the existing signal, watcher/effect, listener, async watch, synchronization, and widget lifecycle APIs.

### Keep hot-reload reconciliation unchanged

The hot-reload fields and methods in `SetupContext`, including hook index reset and compatible-hook reassembly, remain in place. Their purpose is development-time source reconciliation and state preservation, not runtime setup restart. Removal work will target exact reset symbols rather than every identifier containing `reset`.

### Remove APIs directly on the v4 prerelease line

No deprecated forwarding shim will be added. `useSetupReset` is experimental, and retaining a forwarding layer for the other reset entry points would keep the runtime feature alive. The proposal and current API guidance will identify the breaking surface and migration behavior instead.

### Replace reset-specific verification with lifecycle-contract verification

The dedicated reset-hook test file and direct owner reset tests will be removed. Existing lifecycle and hot-reload tests will remain, and focused coverage will verify that same-owner updates retain the setup scope while key-based owner replacement creates and disposes scopes normally if current tests do not already prove those scenarios.

Current API documentation and `skills/use-jolt-setup` will be updated to remove reset references and explain reactive updates and keyed remounts. Historical and current changelog files remain untouched per scope.

## Risks / Trade-offs

- [External consumers fail to compile after a public API removal] → Treat the change as an explicit v4 breaking change and provide migration guidance in current API documentation and planning artifacts.
- [Changing a key replaces the entire element/state, while the removed reset preserved it] → Document the semantic difference and direct consumers that must preserve owner state toward explicit targeted resource or signal updates instead.
- [A broad cleanup accidentally removes hot-reload or unrelated reset behavior] → Delete exact symbols and run repository searches for both removed setup-reset names and preserved reset names before verification.
- [Deleting reset tests also removes useful lifecycle coverage] → Retain existing lifecycle tests and add narrowly scoped same-owner/key-replacement assertions where coverage is missing.
- [Direct users of the public `SetupContext` constructor are affected by removal of its required callback] → Include the constructor change in the breaking surface and verify all repository construction sites use the simplified signature.

## Migration Plan

1. Remove the reset hook family and its private trigger implementations.
2. Simplify `SetupContext` and both setup owners by removing reset-only callbacks, scheduling state, public methods, and duplicated restart flows.
3. Remove reset-specific tests and ensure the remaining tests cover owner lifetime, disposal, keyed recreation, and hot reload.
4. Update current API documentation and the `use-jolt-setup` skill without editing changelog files.
5. Run package analysis and the full `jolt_setup` test suite, then search the repository for stale setup-reset symbols and documentation references.

Rollback is a normal source revert because this change has no persisted data or deployment migration.
