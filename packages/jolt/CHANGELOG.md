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
