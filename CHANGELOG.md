# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-12-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v3.0.0`](#jolt---v300)
 - [`jolt_flutter` - `v3.0.0`](#jolt_flutter---v300)
 - [`jolt_flutter_hooks` - `v2.0.0`](#jolt_flutter_hooks---v200)
 - [`jolt_hooks` - `v3.0.0`](#jolt_hooks---v300)
 - [`jolt_setup` - `v3.0.0`](#jolt_setup---v300)
 - [`jolt_surge` - `v3.0.0`](#jolt_surge---v300)

---

#### `jolt` - `v3.0.0`

 - **REFACTOR**: simplify API by removing native methods and toSignal extensions. ([6ed87fa3](https://github.com/vowdemon/jolt/commit/6ed87fa31a478440df7bc8000f4b9cb956ee4c50))
 - **REFACTOR**: rename Readonly to Readable and update related interfaces. ([daeafdd5](https://github.com/vowdemon/jolt/commit/daeafdd597492160e7d70121d9ed15c971121f0c))

#### `jolt_flutter` - `v3.0.0`

 - **REFACTOR**(jolt_flutter): extract setup, deprecate JoltProvider, add JoltWatchBuilder. ([99cb936c](https://github.com/vowdemon/jolt/commit/99cb936cb4744d931736b4cd78739f0d2d6523b1))

#### `jolt_flutter_hooks` - `v2.0.0`

 - **REFACTOR**: deprecate jolt_flutter_hooks and redirect to jolt_setup. ([26c7a1c6](https://github.com/vowdemon/jolt/commit/26c7a1c6f3897db10432ea7cd7ec1df25509b69e))

#### `jolt_hooks` - `v3.0.0`

 - **REFACTOR**(jolt_hooks): remove tricks methods and update type names. ([611ed474](https://github.com/vowdemon/jolt/commit/611ed4742874696be76251c6ca188631513d178e))

#### `jolt_setup` - `v3.0.0`

 - **REFACTOR**: extract setup functionality to separate package and optimize hooks. ([cb9c4705](https://github.com/vowdemon/jolt/commit/cb9c47058c5ffde0ccf3bdc716ed63b55f7212b5))

#### `jolt_surge` - `v3.0.0`


## 2025-12-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v2.1.1`](#jolt---v211)

---

#### `jolt` - `v2.1.1`

 - **FIX**: mark ReadonlySignal factory as const. ([66e6f692](https://github.com/vowdemon/jolt/commit/66e6f69259c2d705f5468894143c0867936b518d))
 - **FIX**: type hints. ([9d6cc8c3](https://github.com/vowdemon/jolt/commit/9d6cc8c3427e78e29f26cf2bef7cff8773db4166))


## 2025-12-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v2.1.0`](#jolt---v210)
 - [`jolt_flutter` - `v2.1.0`](#jolt_flutter---v210)
 - [`jolt_flutter_hooks` - `v1.1.0`](#jolt_flutter_hooks---v110)
 - [`jolt_hooks` - `v2.0.1`](#jolt_hooks---v201)
 - [`jolt_surge` - `v2.0.1`](#jolt_surge---v201)

---

#### `jolt` - `v2.1.0`

 - **REFACTOR**(jolt): optimize fine-grained update detection for collection signals. ([26781582](https://github.com/vowdemon/jolt/commit/26781582536cef4a8b066169addc8f47c0c907c0))
 - **FEAT**: add Computed.withPrevious(). ([87da01b4](https://github.com/vowdemon/jolt/commit/87da01b447f978cf5d2e0d8e104317b7fb9a22f1))
 - **FEAT**(jolt): add ReadonlySignalImpl and ProxySignal implementations. ([fa6e9879](https://github.com/vowdemon/jolt/commit/fa6e9879fe45eace43810af240af34ca389f1ba4))

#### `jolt_flutter` - `v2.1.0`

 - **REFACTOR**: rename lifecycle hook methods for consistency. ([25a6567e](https://github.com/vowdemon/jolt/commit/25a6567e07f36792666f315a2bfe01f39b0b473b))
 - **REFACTOR**: replace abstract hook creators with final implementations. ([87314ba2](https://github.com/vowdemon/jolt/commit/87314ba29eaff94486445aa7d26101a945ba37e1))
 - **PERF**: optimize listenable implementation with peek and code refactor. ([b36ec5d5](https://github.com/vowdemon/jolt/commit/b36ec5d5921baffe9f59140eef4c0fd86ded5e60))
 - **FEAT**: add hooks withPrevious for computed values. ([6c3c3b04](https://github.com/vowdemon/jolt/commit/6c3c3b0494d8e1269d0951fd516468906a6868f3))

#### `jolt_flutter_hooks` - `v1.1.0`

 - **FEAT**: add more hooks. ([be34b78a](https://github.com/vowdemon/jolt/commit/be34b78a247f516a27f7fd2a849e9119414c22ee))
 - **FEAT**: add async and stream hooks for reactive state management. ([3b258362](https://github.com/vowdemon/jolt/commit/3b258362acb4bc38fc4bcd17a64430997966dace))
 - **FEAT**: add listenable hooks for Listenable. ([1f1f2a7b](https://github.com/vowdemon/jolt/commit/1f1f2a7b21b964c6430e611d0b365fd0dba7f933))

#### `jolt_hooks` - `v2.0.1`

 - **REFACTOR**: replace abstract hook creators with final implementations. ([87314ba2](https://github.com/vowdemon/jolt/commit/87314ba29eaff94486445aa7d26101a945ba37e1))

#### `jolt_surge` - `v2.0.1`

 - **REFACTOR**: use FlutterEffect, wrap builder and selector with JoltBuilder, add MultiSurgeProvider. ([afd17ef0](https://github.com/vowdemon/jolt/commit/afd17ef0b5078c3a1de256caec51853d5102e0b9))


## 2025-12-04

### Changes

---

Packages with breaking changes:

 - [`jolt` - `v2.0.0`](#jolt---v200)
 - [`jolt_flutter` - `v2.0.0`](#jolt_flutter---v200)
 - [`jolt_flutter_hooks` - `v1.0.0`](#jolt_flutter_hooks---v100)
 - [`jolt_hooks` - `v2.0.0`](#jolt_hooks---v200)
 - [`jolt_lint` - `v2.0.0`](#jolt_lint---v200)
 - [`jolt_surge` - `v2.0.0`](#jolt_surge---v200)

Packages with other changes:

 - There are no other changes in this release.

Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):

 - `jolt` - `v2.0.0`
 - `jolt_flutter` - `v2.0.0`
 - `jolt_flutter_hooks` - `v1.0.0`
 - `jolt_hooks` - `v2.0.0`
 - `jolt_lint` - `v2.0.0`
 - `jolt_surge` - `v2.0.0`

---

#### `jolt` - `v2.0.0`

#### `jolt_flutter` - `v2.0.0`

#### `jolt_flutter_hooks` - `v1.0.0`

#### `jolt_hooks` - `v2.0.0`

#### `jolt_lint` - `v2.0.0`

#### `jolt_surge` - `v2.0.0`


## 2025-12-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v2.0.0-beta.5`](#jolt---v200-beta5)
 - [`jolt_flutter` - `v2.0.0-beta.6`](#jolt_flutter---v200-beta6)
 - [`jolt_hooks` - `v2.0.0-beta.4`](#jolt_hooks---v200-beta4)
 - [`jolt_lint` - `v2.0.0-beta.3`](#jolt_lint---v200-beta3)
 - [`jolt_surge` - `v2.0.0-beta.4`](#jolt_surge---v200-beta4)
 - [`jolt_flutter_hooks` - `v1.0.0-beta.4`](#jolt_flutter_hooks---v100-beta4)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `jolt_surge` - `v2.0.0-beta.4`
 - `jolt_flutter_hooks` - `v1.0.0-beta.4`

---

#### `jolt` - `v2.0.0-beta.5`

 - **PERF**: improve base interface. ([58b0e706](https://github.com/vowdemon/jolt/commit/58b0e7060df2c9c9f52ab5546a4e40777c62f39b))
 - **FIX**: add test coverage. ([b3e7bca7](https://github.com/vowdemon/jolt/commit/b3e7bca7566b9464f7d6ac31f76a278d520c39d7))
 - **FIX**: sync upstream's trigger. ([7ce8d459](https://github.com/vowdemon/jolt/commit/7ce8d45935e3f202d0ca0823654472abcc3f1f97))
 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

#### `jolt_flutter` - `v2.0.0-beta.6`

 - **PERF**: improve base interface. ([58b0e706](https://github.com/vowdemon/jolt/commit/58b0e7060df2c9c9f52ab5546a4e40777c62f39b))
 - **FIX**: add test coverage. ([b3e7bca7](https://github.com/vowdemon/jolt/commit/b3e7bca7566b9464f7d6ac31f76a278d520c39d7))
 - **FIX**(jolt_flutter): fix useSignal.async function signature and implementation. ([5bfdb1e0](https://github.com/vowdemon/jolt/commit/5bfdb1e0bf0e5168c16b90d95e33a7995fef5e31))
 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

#### `jolt_hooks` - `v2.0.0-beta.4`

 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

#### `jolt_lint` - `v2.0.0-beta.3`

 - **PERF**: improve base interface. ([58b0e706](https://github.com/vowdemon/jolt/commit/58b0e7060df2c9c9f52ab5546a4e40777c62f39b))
 - **FIX**(jolt_lint): fix URI reference path. ([cdc2b6e8](https://github.com/vowdemon/jolt/commit/cdc2b6e864414ea29ab111a4fe9b4f840a5cb63b))


## 2025-12-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v2.0.0-beta.4`](#jolt---v200-beta4)
 - [`jolt_flutter` - `v2.0.0-beta.5`](#jolt_flutter---v200-beta5)

---

#### `jolt` - `v2.0.0-beta.4`

 - **FEAT**(jolt): add ReadonlySignal factory constructor documentation and implementation. ([8b1be50e](https://github.com/vowdemon/jolt/commit/8b1be50ea00432b8a463a1a32a8df1972882f669))
 - **FEAT**: add call helpers, useInherited hook, drop extra rebuild. ([69263dd1](https://github.com/vowdemon/jolt/commit/69263dd1b0c69c7e2c3c9ad787202ccbdfdb3f37))

#### `jolt_flutter` - `v2.0.0-beta.5`

 - **FIX**(jolt_flutter): prevent duplicate scheduled rebuilds. ([59d535df](https://github.com/vowdemon/jolt/commit/59d535df27db8f1c860fd48db6c7a558a8cde893))
 - **FIX**(jolt_flutter): fix provider update logic and add .value constructor. ([88177013](https://github.com/vowdemon/jolt/commit/88177013c3e372c658893118ea75341dfa63130a))
 - **FEAT**: add call helpers, useInherited hook, drop extra rebuild. ([69263dd1](https://github.com/vowdemon/jolt/commit/69263dd1b0c69c7e2c3c9ad787202ccbdfdb3f37))


## 2025-11-25

### Changes

---

Packages with breaking changes:

 - [`jolt_surge` - `v2.0.0-beta.3`](#jolt_surge---v200-beta3)

Packages with other changes:

 - There are no other changes in this release.

---

#### `jolt_surge` - `v2.0.0-beta.3`

 - **BREAKING** **FEAT**(jolt_surge): add Cubit-compatible factory constructors and .full constructors. ([4efff1d0](https://github.com/vowdemon/jolt/commit/4efff1d0bd3e73eb5a14b1aed9bc2722713a51f9))


## 2025-11-25

### Changes

---

Packages with breaking changes:

 - [`jolt_flutter` - `v2.0.0-beta.4`](#jolt_flutter---v200-beta4)

Packages with other changes:

 - There are no other changes in this release.

---

#### `jolt_flutter` - `v2.0.0-beta.4`

 - **BREAKING** **FEAT**(jolt_flutter): add SetupMixin. ([50487f6c](https://github.com/vowdemon/jolt/commit/50487f6cd809618f2da4bc05d797f214e49ec5ac))


## 2025-11-24

### Changes

---

Packages with breaking changes:

 - [`jolt` - `v2.0.0-beta.3`](#jolt---v200-beta3)

Packages with other changes:

 - [`jolt_flutter` - `v2.0.0-beta.3`](#jolt_flutter---v200-beta3)
 - [`jolt_flutter_hooks` - `v1.0.0-beta.3`](#jolt_flutter_hooks---v100-beta3)
 - [`jolt_hooks` - `v2.0.0-beta.3`](#jolt_hooks---v200-beta3)

---

#### `jolt` - `v2.0.0-beta.3`

 - **FIX**(convert_computed): accept WritableNode instead of Signal for source. ([41adf88a](https://github.com/vowdemon/jolt/commit/41adf88acafee7633b5bda83a91ed27901fa6425))
 - **FEAT**: improve notify() support for mutable values and add tests. ([8e238f7d](https://github.com/vowdemon/jolt/commit/8e238f7dfd97a1f58de60abc26ff669d0891ee8f))
 - **BREAKING** **FEAT**(jolt): add Effect.lazy and improve CustomReactiveNode tests. ([ef64a431](https://github.com/vowdemon/jolt/commit/ef64a431cf75538175d6e9ea0151c0ea51005992))

#### `jolt_flutter` - `v2.0.0-beta.3`

 - **REFACTOR**(jolt_flutter,jolt_hooks): unify hook calling style for better extensibility. ([fc27ba2e](https://github.com/vowdemon/jolt/commit/fc27ba2e6ea31ee22a281eb5200e594c19fd4614))
 - **REFACTOR**(setup): restructure hook system with improved lifecycle management. ([9fa92a97](https://github.com/vowdemon/jolt/commit/9fa92a979afb7c2e0ccc5ddd5a22b49d50bf7604))
 - **FIX**: adapt PropsReadonlyNode to CustomReactiveNode. ([5470aa67](https://github.com/vowdemon/jolt/commit/5470aa67fb0a8ff93310c8cc504e263d52822579))

#### `jolt_flutter_hooks` - `v1.0.0-beta.3`

 - **REFACTOR**(hooks): migrate to new setup hook API. ([b857d225](https://github.com/vowdemon/jolt/commit/b857d2255432893e4e3477b4171b73d29896cfce))

#### `jolt_hooks` - `v2.0.0-beta.3`

 - **REFACTOR**(jolt_flutter,jolt_hooks): unify hook calling style for better extensibility. ([fc27ba2e](https://github.com/vowdemon/jolt/commit/fc27ba2e6ea31ee22a281eb5200e594c19fd4614))


## 2025-11-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt_lint` - `v2.0.0-beta.2`](#jolt_lint---v200-beta2)

---

#### `jolt_lint` - `v2.0.0-beta.2`

 - **FIX**: improve pub score and fix minor issues. ([1306da3b](https://github.com/vowdemon/jolt/commit/1306da3b49e7fb7f105e81ce7b4ec3dd7889edeb))
 - **FEAT**: add jolt_lint package. ([ab6a50d6](https://github.com/vowdemon/jolt/commit/ab6a50d6c7caacbb5ad9fd635fc8b5723079ae44))


## 2025-11-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v2.0.0-beta.2`](#jolt---v200-beta2)
 - [`jolt_flutter` - `v2.0.0-beta.2`](#jolt_flutter---v200-beta2)
 - [`jolt_flutter_hooks` - `v1.0.0-beta.2`](#jolt_flutter_hooks---v100-beta2)
 - [`jolt_hooks` - `v2.0.0-beta.2`](#jolt_hooks---v200-beta2)
 - [`jolt_surge` - `v2.0.0-beta.2`](#jolt_surge---v200-beta2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `jolt_hooks` - `v2.0.0-beta.2`
 - `jolt_surge` - `v2.0.0-beta.2`

---

#### `jolt` - `v2.0.0-beta.2`

 - **REFACTOR**(jolt_flutter): refactor SetupWidget hook system architecture. ([db32a9a3](https://github.com/vowdemon/jolt/commit/db32a9a3d1e2a18c82ea58fdfa97406899d3e0a2))
 - **REFACTOR**: make notifySignal more generic and remove redundant dirty flag. ([8bf595de](https://github.com/vowdemon/jolt/commit/8bf595dec20146443a406bbc5de037ba5c678907))
 - **REFACTOR**: restructure public API exports. ([d3716988](https://github.com/vowdemon/jolt/commit/d37169880998cfc145962cca6efc339d7a39c898))
 - **FEAT**(jolt): add Signal.lazy factory constructor. ([436ec10d](https://github.com/vowdemon/jolt/commit/436ec10d1cc2801d7a53ea64a997a4e03d6d7c3e))

#### `jolt_flutter` - `v2.0.0-beta.2`

 - **REFACTOR**(jolt_flutter): refactor SetupWidget hook system architecture. ([db32a9a3](https://github.com/vowdemon/jolt/commit/db32a9a3d1e2a18c82ea58fdfa97406899d3e0a2))
 - **REFACTOR**: restructure public API exports. ([d3716988](https://github.com/vowdemon/jolt/commit/d37169880998cfc145962cca6efc339d7a39c898))

#### `jolt_flutter_hooks` - `v1.0.0-beta.2`

 - **REFACTOR**(jolt_flutter): refactor SetupWidget hook system architecture. ([db32a9a3](https://github.com/vowdemon/jolt/commit/db32a9a3d1e2a18c82ea58fdfa97406899d3e0a2))
 - **FIX**: hot reload of hooks. ([b6b90eef](https://github.com/vowdemon/jolt/commit/b6b90eef465b87ce7d676ba1df89503a7a1a6c77))


## 2025-11-16

### Changes

---

Packages with breaking changes:

 - [`jolt` - `v2.0.0-beta.1`](#jolt---v200-beta1)
 - [`jolt_hooks` - `v2.0.0-beta.1`](#jolt_hooks---v200-beta1)
 - [`jolt_surge` - `v2.0.0-beta.1`](#jolt_surge---v200-beta1)

Packages with other changes:

 - [`jolt` - `v2.0.0-beta.1`](#jolt---v200-beta1)
 - [`jolt_flutter` - `v2.0.0-beta.1`](#jolt_flutter---v200-beta1)
 - [`jolt_hooks` - `v2.0.0-beta.1`](#jolt_hooks---v200-beta1)
 - [`jolt_surge` - `v2.0.0-beta.1`](#jolt_surge---v200-beta1)
 - [`jolt_flutter_hooks` - `v1.0.0-beta.1`](#jolt_flutter_hooks---v100-beta1)

---

#### `jolt` - `v2.0.0-beta.1`

**BREAKING CHANGES:**

- **Type replacements:**
  - `JReadonlyValue<T>` → `ReadonlyNode<T>`
  - `JWritableValue<T>` → `WritableNode<T>`
  - `JEffect` → `EffectNode` (mixin)
  
  **Migration guide:**
  - Type annotations and generic constraints: `JReadonlyValue<T>` → `ReadonlyNode<T>`
  - Custom class inheritance: `extends JReadonlyValue<T>` → `with ReadonlyNodeMixin<T> implements ReadonlyNode<T>`
  - Effect classes: `extends JEffect` → `with EffectNode implements ChainedDisposable`

- **Property replacement:**
  - `Computed.pendingValue` → `Computed.peekCached`

- **Computed API changes:**
  - `Computed` constructor no longer exposes `initialValue` parameter
  - `Computed.peek()` method behavior changed: previously used to view cached value, now behaves the same as `untracked`, used to read value without tracking
  - Added `Computed.peekCached()` method: used to view cached value (replaces the original `peek()` functionality)
  
  **Migration guide:**
  - If you previously used `computed.peek()` to view cached value, change to `computed.peekCached()`
  - If you need to read value without tracking, use `computed.peek()` or `untracked(() => computed.value)`

**Other changes:**

- **Reactive system refactoring:**
  - Refactored reactive system abstract classes, separating implementation from interfaces for better extensibility and hiding node details

- **New methods:**
  - Added `trackWithEffect()` method: used to append dependencies to side effects
  - Added `notifyAll()` method: used to collect subscribers and notify them

- **Watcher enhancements:**
  - Added `Watcher.immediately()` factory method: creates a Watcher that executes immediately
  - Added `Watcher.once()` factory method: creates a Watcher that executes only once
  - Added pause/resume functionality: `pause()` and `resume()` methods
  - Added `ignoreUpdates()` method: used to ignore updates

- **Extension methods:**
  - Added `update()` extension method: facilitates functional updates from old value to new value
  - Added `until()` extension method: returns a Future for one-time listening to signal value changes

 - **REFACTOR**(jolt): remove EffectBase and add trackWithEffect". ([a00420e3](https://github.com/vowdemon/jolt/commit/a00420e358acc2fed4a3967e04be8ac1aff22a62))
 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))
 - **FEAT**(jolt): add until/update methods and improve APIs. ([44eb0c7b](https://github.com/vowdemon/jolt/commit/44eb0c7b58bc8a7cc07ab6cc4dbcd25d9e5083cf))
 - **FEAT**(watcher): add pause/resume and ignoreUpdates functionality. ([c882bf72](https://github.com/vowdemon/jolt/commit/c882bf72d04af4e639b29300bf0a5ec3e25bc9aa))
 - **FEAT**: implement Setup Widget with type-based hook hot reload. ([e71cf18c](https://github.com/vowdemon/jolt/commit/e71cf18c67d2dbf1c011309ef5e45cba219d8299))

#### `jolt_flutter` - `v2.0.0-beta.1`

**New features:**

- **New library:**
  - Added `setup.dart` library, exporting `SetupWidget`, `SetupBuilder`, and corresponding hooks

 - **REFACTOR**: rename setup widget. ([c7f5fb71](https://github.com/vowdemon/jolt/commit/c7f5fb71a9bf64ef9732c131b7e0d7676443d2fb))
 - **REFACTOR**: extract hooks into separate jolt_flutter_hooks package. ([e12adb35](https://github.com/vowdemon/jolt/commit/e12adb35c1de431d5032745f5bf44ceea4960b67))
 - **REFACTOR**(setup): add onChangedDependencies and improve reactive tracking. ([70bffa24](https://github.com/vowdemon/jolt/commit/70bffa24742c80d1388d227541a4182c8b69dbb7))
 - **REFACTOR**(setup): consolidate hooks exports. ([4f4dcf70](https://github.com/vowdemon/jolt/commit/4f4dcf70d8d7dfbef8fab7f6ddc12bc73979323d))
 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))
 - **FEAT**: implement Setup Widget with type-based hook hot reload. ([e71cf18c](https://github.com/vowdemon/jolt/commit/e71cf18c67d2dbf1c011309ef5e45cba219d8299))
 - **FEAT**: add onChangedDependencies() hook. ([00a540bf](https://github.com/vowdemon/jolt/commit/00a540bf20b7300fd59ac5e88f23f299f3b5df45))
 - **DOCS**(jolt_flutter): update api documents. ([48b51351](https://github.com/vowdemon/jolt/commit/48b513518fd5e346817a5fb807d9e265af1fa971))

#### `jolt_hooks` - `v2.0.0-beta.1`

**BREAKING CHANGES:**

- **API signature changes:**
  - `JoltHook(signal)` (passing instance) → `JoltHook(() => signal)` (passing factory function)
  - `JoltEffectHook(effect)` (passing instance) → `JoltEffectHook(() => effect)` (passing factory function)
  
  **Migration guide:**
  - Custom hooks need to change parameters from instances to factory functions
  - Official hooks (`useSignal`, `useComputed`, etc.) require no changes

 - **REFACTOR**(setup): add onChangedDependencies and improve reactive tracking. ([70bffa24](https://github.com/vowdemon/jolt/commit/70bffa24742c80d1388d227541a4182c8b69dbb7))
 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))
 - **FEAT**: implement Setup Widget with type-based hook hot reload. ([e71cf18c](https://github.com/vowdemon/jolt/commit/e71cf18c67d2dbf1c011309ef5e45cba219d8299))

#### `jolt_surge` - `v2.0.0-beta.1`

**BREAKING CHANGES:**

- **Type replacements:**
  - `SurgeStateCreator<T>` (returns `JWritableValue<T>`) → `SurgeStateCreator<T>` (returns `WritableNode<T>`)
  - `Surge.raw` (returns `JWritableValue<T>`) → `Surge.raw` (returns `WritableNode<T>`)
  
  **Migration guide:**
  - Type annotations: `JWritableValue<T>` → `WritableNode<T>`

 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))

#### `jolt_flutter_hooks` - `v1.0.0-beta.1`

 - **REFACTOR**: extract hooks into separate jolt_flutter_hooks package. ([e12adb35](https://github.com/vowdemon/jolt/commit/e12adb35c1de431d5032745f5bf44ceea4960b67))


## 2025-11-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt_flutter` - `v1.1.3`](#jolt_flutter---v113)

---

#### `jolt_flutter` - `v1.1.3`

 - **FIX**: prevent rebuild on disposed widgets, extract shared effect builder. ([6cc45681](https://github.com/vowdemon/jolt/commit/6cc456818593360581201f45fe912d8302e0eaf3))


## 2025-11-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt_hooks` - `v1.0.3`](#jolt_hooks---v103)

---

#### `jolt_hooks` - `v1.0.3`

 - **FIX**(jolt_hooks): delay instance creation to avoid recreating on rebuild. ([b2121cf9](https://github.com/vowdemon/jolt/commit/b2121cf9d87ff45597efd9884c649f3ecb5303af))


## 2025-11-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v1.0.4`](#jolt---v104)
 - [`jolt_flutter` - `v1.1.2`](#jolt_flutter---v112)
 - [`jolt_hooks` - `v1.0.2`](#jolt_hooks---v102)
 - [`jolt_surge` - `v1.0.4`](#jolt_surge---v104)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `jolt_flutter` - `v1.1.2`
 - `jolt_hooks` - `v1.0.2`
 - `jolt_surge` - `v1.0.4`

---

#### `jolt` - `v1.0.4`

 - **REFACTOR**: flatten ReactiveSystem to library level, add upstream sync. ([1969693f](https://github.com/vowdemon/jolt/commit/1969693f4dd1a655711419937f43b2fdee6d4266))


## 2025-11-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt_surge` - `v1.0.3`](#jolt_surge---v103)

---

#### `jolt_surge` - `v1.0.3`

 - **FIX**(surge): dispose order. ([f3bc4e7c](https://github.com/vowdemon/jolt/commit/f3bc4e7c57a955a19ef863ce84f9adf83088b07c))


## 2025-11-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v1.0.3`](#jolt---v103)
 - [`jolt_flutter` - `v1.1.1`](#jolt_flutter---v111)
 - [`jolt_hooks` - `v1.0.1`](#jolt_hooks---v101)
 - [`jolt_surge` - `v1.0.2`](#jolt_surge---v102)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `jolt_surge` - `v1.0.2`

---

#### `jolt` - `v1.0.3`

 - **REFACTOR**: inlined function consolidates assert and debug functions. ([1bd31e26](https://github.com/vowdemon/jolt/commit/1bd31e262002d30fec4d5d36653db10f08aa0b5f))
 - **PERF**(jolt): optimize inlining of common short functions and type checks. ([54f4d6ed](https://github.com/vowdemon/jolt/commit/54f4d6ed6fb15830a1f0f5ffeac0959eb4f41a4f))

#### `jolt_flutter` - `v1.1.1`

 - **REFACTOR**(jolt_flutter): optimize widgets dependency tracking and rebuild logic for better performance. ([52ebbeee](https://github.com/vowdemon/jolt/commit/52ebbeeecdc430dc8134227831f4fa63e6e23063))

#### `jolt_hooks` - `v1.0.1`

 - **REFACTOR**(jolt_hooks): optimize useJoltWidget dependency tracking and rebuild logic for better performance. ([af143da1](https://github.com/vowdemon/jolt/commit/af143da1cb2ae63e92cf6e5fee0313a50cd39088))


## 2025-11-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v1.0.2`](#jolt---v102)
 - [`jolt_flutter` - `v1.1.0`](#jolt_flutter---v110)

---

#### `jolt` - `v1.0.2`

 - **FIX**(jolt): type annotation. ([475ef361](https://github.com/vowdemon/jolt/commit/475ef36117e0e3f24d204f6db9e57ef7f5be8d78))

#### `jolt_flutter` - `v1.1.0`

 - **FEAT**(jolt): add value parameter support to JoltProvider. ([e7b4faac](https://github.com/vowdemon/jolt/commit/e7b4faac8f9702c747f1c7f0f722aa5db3efecd1))


## 2025-11-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`jolt` - `v1.0.1`](#jolt---v101)
 - [`jolt_surge` - `v1.0.1`](#jolt_surge---v101)

---

#### `jolt` - `v1.0.1`

 - **REVERT**(jolt): protected annotations for pub score. ([3efd724c](https://github.com/vowdemon/jolt/commit/3efd724ca8f4078800d3a3b8595562e31c35bae1))

#### `jolt_surge` - `v1.0.1`

 - **FIX**(jolt_surge): add example. ([4565580e](https://github.com/vowdemon/jolt/commit/4565580e90c4f21e0b7491f730e26448f4b25d2f))


## 2025-11-06

### Changes

---

Packages with breaking changes:

 - [`jolt_flutter` - `v1.0.0`](#jolt_flutter---v100)

Packages with other changes:

 - [`jolt` - `v1.0.0`](#jolt---v100)
 - [`jolt_surge` - `v1.0.0`](#jolt_surge---v100)
 - [`jolt_hooks` - `v1.0.0`](#jolt_hooks---v100)

---

#### `jolt_flutter` - `v1.0.0`

 - **REFACTOR**: simplify EffectScope API, add detach parameter. ([eed8cc1a](https://github.com/vowdemon/jolt/commit/eed8cc1a87a96a6b56aad9efae2ecf34b6ee1450))
 - **FIX**(jolt_flutter): remove redundant dependency. ([942c61a2](https://github.com/vowdemon/jolt/commit/942c61a20ba7ebbf9ed553b2f4066268ace7e315))
 - **FEAT**(jolt): allow watcher to receive null as old value when called immediately. ([b101c68e](https://github.com/vowdemon/jolt/commit/b101c68e53ece6ca7e2416b1cd604573e692a459))
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))
 - **BREAKING** **REFACTOR**: remove JoltResource, add JoltProvider, refactor JoltSelector. ([a91e0860](https://github.com/vowdemon/jolt/commit/a91e0860f7d0302a9d9414ee69a00af21a6c7003))

#### `jolt` - `v1.0.0`

 - **REFACTOR**(jolt): async signal. ([f42f70f8](https://github.com/vowdemon/jolt/commit/f42f70f81a68cc0d836f82e2ebf7bea2eb6fd8a9))
 - **REFACTOR**: simplify EffectScope API, add detach parameter. ([eed8cc1a](https://github.com/vowdemon/jolt/commit/eed8cc1a87a96a6b56aad9efae2ecf34b6ee1450))
 - **REFACTOR**(jolt): batch WritableComputed setter for atomic updates. ([7f7046e0](https://github.com/vowdemon/jolt/commit/7f7046e0dea2a567dc3c1a2e089fc681aef9d22a))
 - **PERF**(jolt): simplify Watcher comparison logic. ([47acc599](https://github.com/vowdemon/jolt/commit/47acc599834ab0aac8684e2476c36bd825f96617))
 - **PERF**(jolt): remove hard code. ([7cafc45a](https://github.com/vowdemon/jolt/commit/7cafc45a39213ddaf3723ea20d12f07ac7452dc0))
 - **FIX**(jolt): computed's annotations. ([1168f3cd](https://github.com/vowdemon/jolt/commit/1168f3cdacd987c768b3cecdd1292d2ccad1d31e))
 - **FIX**(jolt): add protected annotations. ([4a5d3a0a](https://github.com/vowdemon/jolt/commit/4a5d3a0af8793e5d8c5457732d55ccf075707724))
 - **FIX**: add missing tests for jolt, rename currentValue to cachedValue. ([87de3c6a](https://github.com/vowdemon/jolt/commit/87de3c6a975b81d5be7222734e72f5a534b6bf79))
 - **FIX**(persist_signal): ignore write errors and prevent load overwrite. ([ba9db5c2](https://github.com/vowdemon/jolt/commit/ba9db5c27a809d8d77a1e377a9c117cafd1f173f))
 - **FEAT**(jolt): expose JFinalizer. ([a90865c3](https://github.com/vowdemon/jolt/commit/a90865c3fa41f2300e9addf2de76ab3c68ac7fe6))
 - **FEAT**: add cleanup function support for Effect, Watcher and EffectScope. ([d0e8b367](https://github.com/vowdemon/jolt/commit/d0e8b367326da88a3797fda0e7670ebb3d46af64))
 - **FEAT**(jolt): allow watcher to receive null as old value when called immediately. ([b101c68e](https://github.com/vowdemon/jolt/commit/b101c68e53ece6ca7e2416b1cd604573e692a459))
 - **FEAT**(persist_signal): add setEnsured with write counting and rollback. ([bfb51d3b](https://github.com/vowdemon/jolt/commit/bfb51d3b7b2f6ffcda1ed8994e24e7c8f7b179e6))
 - **DOCS**: update 1.0 documentation. ([5a0b2847](https://github.com/vowdemon/jolt/commit/5a0b2847031a1dbbf72c42b6548313695c25a65c))
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))
 - **DOCS**: create vitepress site. ([5f7844e7](https://github.com/vowdemon/jolt/commit/5f7844e74c3230434a5293d3bfeebb329a3de037))

#### `jolt_surge` - `v1.0.0`

 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))

#### `jolt_hooks` - `v1.0.0`

 - **REFACTOR**: simplify EffectScope API, add detach parameter. ([eed8cc1a](https://github.com/vowdemon/jolt/commit/eed8cc1a87a96a6b56aad9efae2ecf34b6ee1450))
 - **FIX**(jolt_hooks): sync upstream asyncSignal. ([7bbac97f](https://github.com/vowdemon/jolt/commit/7bbac97f898b3df30e43ab0f15f11ec693d5b662))
 - **FIX**: add missing tests for jolt, rename currentValue to cachedValue. ([87de3c6a](https://github.com/vowdemon/jolt/commit/87de3c6a975b81d5be7222734e72f5a534b6bf79))
 - **FEAT**: add cleanup function support for Effect, Watcher and EffectScope. ([d0e8b367](https://github.com/vowdemon/jolt/commit/d0e8b367326da88a3797fda0e7670ebb3d46af64))
 - **FEAT**: add useJoltWidget hook. ([e5d5addb](https://github.com/vowdemon/jolt/commit/e5d5addbc482d9a46f954ec86c26482a72801940))
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))

