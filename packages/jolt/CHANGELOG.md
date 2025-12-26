## 3.0.1

 - **FIX**(jolt): sync upstream fix for effect flush error handling. ([39ad65d9](https://github.com/vowdemon/jolt/commit/39ad65d9f860227dad52a030b1766a6f8e325549))

## 3.0.0

 - **REFACTOR**: simplify API by removing native methods and toSignal extensions. ([6ed87fa3](https://github.com/vowdemon/jolt/commit/434a2e9d325f35dbcf36f2a11f6bf3dfe611c90c))

- Refactor base interfaces
  - Remove ReadonlyNodeMixin, replace with DisposableNodeMixin
  - Simplify interface hierarchy (ReadableNode, WritableNode, DisposableNode)
  - Move disposal logic to finalizer utilities

- Refactor persist signal implementation
  - Introduce write queue management mixin
  - Implement 2-element write queue for efficient writes
  - Add throttling support with trailing write behavior
  - Split into sync and async implementations

- Add extension methods
  - Add .get() and .call() extensions for readable nodes
  - Add .set() and .update() extensions for writable nodes
  - Add delegated, stream, until, finalizer extensions

- Remove native methods from classes
  - Remove .get(), .set(), .call() methods from Signal, Computed, etc.
  - Classes now only use .value property
  - Methods moved to extension methods for better API consistency

- Remove toSignal extension methods
  - Remove all conversion extension methods

Migration Guide:

1. Replace .get() with .value:
  ```dart
  // Before
  signal.get()
  // After
  signal.value
  ```

2. Replace .set(value) with .value = value:
  ```dart
  // Before
  signal.set(10)
  // After
  signal.value = 10
  ```

3. Replace .call() with .value:
  ```dart
  // Before
  readonly.call()
  // After
  readonly.value
  ```

4. Remove toSignal() and similar conversion methods:
  ```dart
  // Before
  final signal = someValue.toSignal()
  // After
  final signal = Signal(someValue)
  ```

5. Import extension methods if needed:
  ```dart
  // If you need .get()/.set()/.call() as extension methods
  import 'package:jolt/extension.dart';
  ```

 - **REFACTOR**: rename Readonly to Readable and update related interfaces. ([daeafdd5](https://github.com/vowdemon/jolt/commit/daeafdd597492160e7d70121d9ed15c971121f0c))

## 2.1.1

 - **FIX**: mark ReadonlySignal factory as const. ([66e6f692](https://github.com/vowdemon/jolt/commit/66e6f69259c2d705f5468894143c0867936b518d))
 - **FIX**: type hints. ([9d6cc8c3](https://github.com/vowdemon/jolt/commit/9d6cc8c3427e78e29f26cf2bef7cff8773db4166))

## 2.1.0

 - **REFACTOR**(jolt): optimize fine-grained update detection for collection signals. ([26781582](https://github.com/vowdemon/jolt/commit/26781582536cef4a8b066169addc8f47c0c907c0))
 - **FEAT**: add Computed.withPrevious(). ([87da01b4](https://github.com/vowdemon/jolt/commit/87da01b447f978cf5d2e0d8e104317b7fb9a22f1))
 - **FEAT**(jolt): add ReadonlySignalImpl and ProxySignal implementations. ([fa6e9879](https://github.com/vowdemon/jolt/commit/fa6e9879fe45eace43810af240af34ca389f1ba4))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-beta.5

 - **PERF**: improve base interface. ([58b0e706](https://github.com/vowdemon/jolt/commit/58b0e7060df2c9c9f52ab5546a4e40777c62f39b))
 - **FIX**: add test coverage. ([b3e7bca7](https://github.com/vowdemon/jolt/commit/b3e7bca7566b9464f7d6ac31f76a278d520c39d7))
 - **FIX**: sync upstream's trigger. ([7ce8d459](https://github.com/vowdemon/jolt/commit/7ce8d45935e3f202d0ca0823654472abcc3f1f97))
 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

## 2.0.0-beta.4

 - **FEAT**(jolt): add ReadonlySignal factory constructor documentation and implementation. ([8b1be50e](https://github.com/vowdemon/jolt/commit/8b1be50ea00432b8a463a1a32a8df1972882f669))
 - **FEAT**: add call helpers, useInherited hook, drop extra rebuild. ([69263dd1](https://github.com/vowdemon/jolt/commit/69263dd1b0c69c7e2c3c9ad787202ccbdfdb3f37))

## 2.0.0-beta.3

> Note: This release has breaking changes.

 - **FIX**(convert_computed): accept WritableNode instead of Signal for source. ([41adf88a](https://github.com/vowdemon/jolt/commit/41adf88acafee7633b5bda83a91ed27901fa6425))
 - **FEAT**: improve notify() support for mutable values and add tests. ([8e238f7d](https://github.com/vowdemon/jolt/commit/8e238f7dfd97a1f58de60abc26ff669d0891ee8f))
 - **BREAKING** **FEAT**(jolt): add Effect.lazy and improve CustomReactiveNode tests. ([ef64a431](https://github.com/vowdemon/jolt/commit/ef64a431cf75538175d6e9ea0151c0ea51005992))

## 2.0.0-beta.2

 - **REFACTOR**(jolt_flutter): refactor SetupWidget hook system architecture. ([db32a9a3](https://github.com/vowdemon/jolt/commit/db32a9a3d1e2a18c82ea58fdfa97406899d3e0a2))
 - **REFACTOR**: make notifySignal more generic and remove redundant dirty flag. ([8bf595de](https://github.com/vowdemon/jolt/commit/8bf595dec20146443a406bbc5de037ba5c678907))
 - **REFACTOR**: restructure public API exports. ([d3716988](https://github.com/vowdemon/jolt/commit/d37169880998cfc145962cca6efc339d7a39c898))
 - **FEAT**(jolt): add Signal.lazy factory constructor. ([436ec10d](https://github.com/vowdemon/jolt/commit/436ec10d1cc2801d7a53ea64a997a4e03d6d7c3e))

## 2.0.0-beta.1

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

## 1.0.4

 - **REFACTOR**: flatten ReactiveSystem to library level, add upstream sync. ([1969693f](https://github.com/vowdemon/jolt/commit/1969693f4dd1a655711419937f43b2fdee6d4266))

## 1.0.3

 - **REFACTOR**: inlined function consolidates assert and debug functions. ([1bd31e26](https://github.com/vowdemon/jolt/commit/1bd31e262002d30fec4d5d36653db10f08aa0b5f))
 - **PERF**(jolt): optimize inlining of common short functions and type checks. ([54f4d6ed](https://github.com/vowdemon/jolt/commit/54f4d6ed6fb15830a1f0f5ffeac0959eb4f41a4f))

## 1.0.2

 - **FIX**(jolt): type annotation. ([475ef361](https://github.com/vowdemon/jolt/commit/475ef36117e0e3f24d204f6db9e57ef7f5be8d78))

## 1.0.1

 - **REVERT**(jolt): protected annotations for pub score. ([3efd724c](https://github.com/vowdemon/jolt/commit/3efd724ca8f4078800d3a3b8595562e31c35bae1))

## 1.0.0

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
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))


## 0.0.7

- fix: make Computed.peek initialize via untracked and return cached value

## 0.0.6

- chore: use `melos` for monorepo management
- fix: fix outdated documentation API comments
- fix: peek in signal
- fix: expose onDispose method for subclass

## 0.0.5

- **BREAKING**: remove autoDispose, MapEntrySignal, joltObserver
- feat: add onDebug hook for debug(assert method)
- feat: JReadonlyValue now supports toString() for value display
- sync: align with alien_signals v3.0.3
- docs: add comprehensive readme and documentation for tricks

## 0.0.4

- fix: notify method not working
- feat: align stream shortcut listen parameters with original implementation
- fix: equality comparison issue caused by operator== overloading

## 0.0.3+1

- fix: effect scope context

## 0.0.3

- sync: align with alien_signals v3.0.1
- feat: advanced observer
- chore: update dependencies

## 0.0.2+1

- fix: some bugs

## 0.0.2

- Initial version.
