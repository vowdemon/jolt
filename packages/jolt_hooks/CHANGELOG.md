## 3.0.1

 - Update a dependency to the latest release.

## 3.0.0

 - **REFACTOR**(jolt_hooks): remove tricks methods and update type names. ([611ed474](https://github.com/vowdemon/jolt/commit/611ed4742874696be76251c6ca188631513d178e))

## 2.0.1

 - **REFACTOR**: replace abstract hook creators with final implementations. ([87314ba2](https://github.com/vowdemon/jolt/commit/87314ba29eaff94486445aa7d26101a945ba37e1))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-beta.4

 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

## 2.0.0-beta.3

 - **REFACTOR**(jolt_flutter,jolt_hooks): unify hook calling style for better extensibility. ([fc27ba2e](https://github.com/vowdemon/jolt/commit/fc27ba2e6ea31ee22a281eb5200e594c19fd4614))

## 2.0.0-beta.2

 - Update a dependency to the latest release.

## 2.0.0-beta.1

**BREAKING CHANGES:**

- **API signature changes:**
  - `JoltHook(signal)` (passing instance) → `JoltHook(() => signal)` (passing factory function)
  - `JoltEffectHook(effect)` (passing instance) → `JoltEffectHook(() => effect)` (passing factory function)
  
  **Migration guide:**
  - Custom hooks need to change parameters from instances to factory functions
  - Official hooks (`useSignal`, `useComputed`, etc.) require no changes

 - **CHORE**: update dependencies (jolt-v2.0.0)
 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))
 - **FEAT**: implement Setup Widget with type-based hook hot reload. ([e71cf18c](https://github.com/vowdemon/jolt/commit/e71cf18c67d2dbf1c011309ef5e45cba219d8299))

## 1.0.3

 - **FIX**(jolt_hooks): delay instance creation to avoid recreating on rebuild. ([b2121cf9](https://github.com/vowdemon/jolt/commit/b2121cf9d87ff45597efd9884c649f3ecb5303af))

## 1.0.2

 - Update a dependency to the latest release.

## 1.0.1

 - **REFACTOR**(jolt_hooks): optimize useJoltWidget dependency tracking and rebuild logic for better performance. ([af143da1](https://github.com/vowdemon/jolt/commit/af143da1cb2ae63e92cf6e5fee0313a50cd39088))

## 1.0.0

 - **REFACTOR**: simplify EffectScope API, add detach parameter. ([eed8cc1a](https://github.com/vowdemon/jolt/commit/eed8cc1a87a96a6b56aad9efae2ecf34b6ee1450))
 - **FIX**(jolt_hooks): sync upstream asyncSignal. ([7bbac97f](https://github.com/vowdemon/jolt/commit/7bbac97f898b3df30e43ab0f15f11ec693d5b662))
 - **FIX**: add missing tests for jolt, rename currentValue to cachedValue. ([87de3c6a](https://github.com/vowdemon/jolt/commit/87de3c6a975b81d5be7222734e72f5a534b6bf79))
 - **FEAT**: add cleanup function support for Effect, Watcher and EffectScope. ([d0e8b367](https://github.com/vowdemon/jolt/commit/d0e8b367326da88a3797fda0e7670ebb3d46af64))
 - **FEAT**: add useJoltWidget hook. ([e5d5addb](https://github.com/vowdemon/jolt/commit/e5d5addbc482d9a46f954ec86c26482a72801940))
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))

## 0.0.6

- chore: update dependencies

## 0.0.5+1

- chore: use `melos` for monorepo management
- chore: update dependencies

## 0.0.5

- Initial version.
