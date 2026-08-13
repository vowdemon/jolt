## 1. Remove Runtime Setup-Reset APIs

- [x] 1.1 Remove `JoltSetupHookResetCreator`, `useSetupReset`, and the reset-only Listenable, Readable, and selector hook implementations from `packages/jolt_setup/lib/src/setup/hooks.dart`.
- [x] 1.2 Simplify `SetupContext` by removing the reset callback constructor parameter, scheduling flag, scheduler method, reset-specific disposal state, and now-unused scheduler import while retaining hot-reload reconciliation.
- [x] 1.3 Update `SetupWidgetElement` and `SetupMixin` to construct the simplified context and remove their public `resetSetup()` methods and duplicated private teardown-and-rerun implementations.
- [x] 1.4 Review affected Dart API comments so setup lifetime is described as owner-bound and no reset-control wording remains.

## 2. Align Lifecycle Verification

- [x] 2.1 Remove `packages/jolt_setup/test/hooks/reset_test.dart` and the direct element/mixin reset tests that exercise deleted APIs.
- [x] 2.2 Confirm or add focused tests showing that reactive rebuilds and same-key parent updates retain the existing setup scope for both setup owner forms.
- [x] 2.3 Confirm or add focused tests showing that key-based owner replacement disposes the previous setup scope and initializes a fresh one.
- [x] 2.4 Run the existing setup lifecycle and hot-reload tests to verify hook reconciliation, mounting, reverse-order unmounting, and resource disposal remain unchanged.

## 3. Update Current Guidance

- [x] 3.1 Remove setup-reset API entries and examples from `skills/use-jolt-setup/SKILL.md` and `skills/use-jolt-setup/references/hooks.md`.
- [x] 3.2 Update `skills/use-jolt-setup/references/custom-hooks.md` to remove reset-specific lifecycle wording and the reset creator entry without changing unrelated local reset examples.
- [x] 3.3 Add concise current guidance that ordinary changes use reactive/listener/synchronization APIs and complete reinitialization uses Flutter owner replacement with a key.
- [x] 3.4 Verify that no repository or package changelog file is modified by this change.

## 4. Verify the Removal

- [x] 4.1 Format and analyze the affected `jolt_setup` Dart sources and tests.
- [x] 4.2 Run the full `jolt_setup` test suite.
- [x] 4.3 Search tracked source, tests, and current guidance to confirm removed setup-reset symbols and behavior references are gone while `_resetHookIndex()`, `TimerHook.reset()`, hot reload, and application-level reset examples remain intact.
- [x] 4.4 Run strict OpenSpec validation for `remove-setup-reset` and review the final diff for scope compliance.
