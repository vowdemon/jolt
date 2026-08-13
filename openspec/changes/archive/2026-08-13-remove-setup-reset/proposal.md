## Why

Runtime setup reset is a destructive escape hatch that overlaps with Jolt's reactive hooks and Flutter's keyed remount lifecycle while making resource ownership and state loss harder to reason about. Removing it during the v4 prerelease simplifies the setup runtime before the next stable API is published.

## What Changes

- **BREAKING** Remove `useSetupReset()`, `useSetupReset.listen()`, `useSetupReset.watch()`, and `useSetupReset.select()` from `jolt_setup`.
- **BREAKING** Remove the public setup-boundary reset entry points from `SetupWidgetElement`, `SetupMixin`, and `SetupContext`, including the reset callback required by `SetupContext` construction.
- Remove the reset-only runtime implementations and tests while preserving hot-reload hook reconciliation, `TimerHook.reset()`, and application-defined local reset methods.
- Update current API documentation and the `use-jolt-setup` skill so they describe setup scopes as lasting for their owning Flutter element or state lifetime and direct callers to reactive updates or keyed remounts.
- Do not modify package or repository changelog files as part of this change.

## Capabilities

### New Capabilities

- `setup-lifecycle`: Defines setup-scope lifetime, disposal, reactive update, and owner-remount behavior after runtime setup reset is removed.

### Modified Capabilities

None.

## Impact

- Affected runtime code: `packages/jolt_setup/lib/src/setup/framework.dart`, `widget.dart`, `stateful_mixin.dart`, and `hooks.dart`.
- Affected verification: reset-specific tests are removed, while existing setup lifecycle and hot-reload tests must continue to pass.
- Affected guidance: current `jolt_setup` API docs and `skills/use-jolt-setup` references must no longer advertise setup reset.
- External callers using any setup-reset API must migrate to targeted signal/effect/listenable updates or let Flutter recreate the setup owner by changing its key. Keyed recreation also replaces the owning element/state, unlike the removed in-place hook reset.
- No dependency changes are expected.
