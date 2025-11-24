## 2.0.0-beta.3

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(jolt_surge): add Cubit-compatible factory constructors and .full constructors. ([4efff1d0](https://github.com/vowdemon/jolt/commit/4efff1d0bd3e73eb5a14b1aed9bc2722713a51f9))

## 2.0.0-beta.2

 - Update a dependency to the latest release.

## 2.0.0-beta.1

**BREAKING CHANGES:**

- **Type replacements:**
  - `SurgeStateCreator<T>` (returns `JWritableValue<T>`) → `SurgeStateCreator<T>` (returns `WritableNode<T>`)
  - `Surge.raw` (returns `JWritableValue<T>`) → `Surge.raw` (returns `WritableNode<T>`)
  
  **Migration guide:**
  - Type annotations: `JWritableValue<T>` → `WritableNode<T>`

 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))

## 1.0.4

 - Update a dependency to the latest release.

## 1.0.3

 - **FIX**(surge): dispose order. ([f3bc4e7c](https://github.com/vowdemon/jolt/commit/f3bc4e7c57a955a19ef863ce84f9adf83088b07c))

## 1.0.2

 - Update a dependency to the latest release.

## 1.0.1

 - **FIX**(jolt_surge): add example. ([4565580e](https://github.com/vowdemon/jolt/commit/4565580e90c4f21e0b7491f730e26448f4b25d2f))

## 1.0.0

 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))
 - CHORE: dependency

## 0.0.1-beta.1

 - feat: add creator parameter for custom state container creation.
 - init surge

