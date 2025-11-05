# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

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

