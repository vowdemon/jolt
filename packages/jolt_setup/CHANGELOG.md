## 2.1.0

 - **REFACTOR**: rename lifecycle hook methods for consistency. ([25a6567e](https://github.com/vowdemon/jolt/commit/25a6567e07f36792666f315a2bfe01f39b0b473b))
 - **REFACTOR**: replace abstract hook creators with final implementations. ([87314ba2](https://github.com/vowdemon/jolt/commit/87314ba29eaff94486445aa7d26101a945ba37e1))
 - **PERF**: optimize listenable implementation with peek and code refactor. ([b36ec5d5](https://github.com/vowdemon/jolt/commit/b36ec5d5921baffe9f59140eef4c0fd86ded5e60))
 - **FEAT**: add hooks withPrevious for computed values. ([6c3c3b04](https://github.com/vowdemon/jolt/commit/6c3c3b0494d8e1269d0951fd516468906a6868f3))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-beta.6

 - **PERF**: improve base interface. ([58b0e706](https://github.com/vowdemon/jolt/commit/58b0e7060df2c9c9f52ab5546a4e40777c62f39b))
 - **FIX**: add test coverage. ([b3e7bca7](https://github.com/vowdemon/jolt/commit/b3e7bca7566b9464f7d6ac31f76a278d520c39d7))
 - **FIX**(jolt_flutter): fix useSignal.async function signature and implementation. ([5bfdb1e0](https://github.com/vowdemon/jolt/commit/5bfdb1e0bf0e5168c16b90d95e33a7995fef5e31))
 - **FEAT**: add FlutterEffect for frame-end scheduling. ([9caccf58](https://github.com/vowdemon/jolt/commit/9caccf5832d177b7cb6725a6cc69f2ecfafbfd6b))

## 2.0.0-beta.5

 - **FIX**(jolt_flutter): prevent duplicate scheduled rebuilds. ([59d535df](https://github.com/vowdemon/jolt/commit/59d535df27db8f1c860fd48db6c7a558a8cde893))
 - **FIX**(jolt_flutter): fix provider update logic and add .value constructor. ([88177013](https://github.com/vowdemon/jolt/commit/88177013c3e372c658893118ea75341dfa63130a))
 - **FEAT**: add call helpers, useInherited hook, drop extra rebuild. ([69263dd1](https://github.com/vowdemon/jolt/commit/69263dd1b0c69c7e2c3c9ad787202ccbdfdb3f37))

## 2.0.0-beta.4

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(jolt_flutter): add SetupMixin. ([50487f6c](https://github.com/vowdemon/jolt/commit/50487f6cd809618f2da4bc05d797f214e49ec5ac))

## 2.0.0-beta.3

 - **REFACTOR**(jolt_flutter,jolt_hooks): unify hook calling style for better extensibility. ([fc27ba2e](https://github.com/vowdemon/jolt/commit/fc27ba2e6ea31ee22a281eb5200e594c19fd4614))
 - **REFACTOR**(setup): restructure hook system with improved lifecycle management. ([9fa92a97](https://github.com/vowdemon/jolt/commit/9fa92a979afb7c2e0ccc5ddd5a22b49d50bf7604))
 - **FIX**: adapt PropsReadonlyNode to CustomReactiveNode. ([5470aa67](https://github.com/vowdemon/jolt/commit/5470aa67fb0a8ff93310c8cc504e263d52822579))

## 2.0.0-beta.2

 - **REFACTOR**(jolt_flutter): refactor SetupWidget hook system architecture. ([db32a9a3](https://github.com/vowdemon/jolt/commit/db32a9a3d1e2a18c82ea58fdfa97406899d3e0a2))
 - **REFACTOR**: restructure public API exports. ([d3716988](https://github.com/vowdemon/jolt/commit/d37169880998cfc145962cca6efc339d7a39c898))

## 2.0.0-beta.1

**New features:**

- **New library:**
  - Added `setup.dart` library, exporting `SetupWidget`, `SetupBuilder`, and corresponding hooks

 - **REFACTOR**: rename setup widget. ([c7f5fb71](https://github.com/vowdemon/jolt/commit/c7f5fb71a9bf64ef9732c131b7e0d7676443d2fb))
 - **REFACTOR**: extract hooks into separate jolt_flutter_hooks package. ([e12adb35](https://github.com/vowdemon/jolt/commit/e12adb35c1de431d5032745f5bf44ceea4960b67))
 - **REFACTOR**(setup): improve reactive tracking. ([70bffa24](https://github.com/vowdemon/jolt/commit/70bffa24742c80d1388d227541a4182c8b69dbb7))
 - **REFACTOR**(setup): consolidate hooks exports. ([4f4dcf70](https://github.com/vowdemon/jolt/commit/4f4dcf70d8d7dfbef8fab7f6ddc12bc73979323d))
 - **REFACTOR**(core): optimize reactive system core and improve code quality. ([444957b6](https://github.com/vowdemon/jolt/commit/444957b6f5e382d689e91db0159fc81d604dfecf))
 - **REFACTOR**: restructure core interfaces and implementation classes. ([e552ab33](https://github.com/vowdemon/jolt/commit/e552ab336b5a3a759bf55b7c77b29bdabf5fd780))
 - **FEAT**: implement Setup Widget with type-based hook hot reload. ([e71cf18c](https://github.com/vowdemon/jolt/commit/e71cf18c67d2dbf1c011309ef5e45cba219d8299))
 - **FEAT**: add onChangedDependencies() hook. ([00a540bf](https://github.com/vowdemon/jolt/commit/00a540bf20b7300fd59ac5e88f23f299f3b5df45))
 - **DOCS**(jolt_flutter): update api documents. ([48b51351](https://github.com/vowdemon/jolt/commit/48b513518fd5e346817a5fb807d9e265af1fa971))

## 1.1.3

 - **FIX**: prevent rebuild on disposed widgets, extract shared effect builder. ([6cc45681](https://github.com/vowdemon/jolt/commit/6cc456818593360581201f45fe912d8302e0eaf3))

## 1.1.2

 - Update a dependency to the latest release.

## 1.1.1

 - **REFACTOR**(jolt_flutter): optimize widgets dependency tracking and rebuild logic for better performance. ([52ebbeee](https://github.com/vowdemon/jolt/commit/52ebbeeecdc430dc8134227831f4fa63e6e23063))

## 1.1.0

 - **FEAT**(jolt): add value parameter support to JoltProvider. ([e7b4faac](https://github.com/vowdemon/jolt/commit/e7b4faac8f9702c747f1c7f0f722aa5db3efecd1))

## 1.0.0

> Note: This release has breaking changes.

 - **REFACTOR**: simplify EffectScope API, add detach parameter. ([eed8cc1a](https://github.com/vowdemon/jolt/commit/eed8cc1a87a96a6b56aad9efae2ecf34b6ee1450))
 - **FIX**(jolt_flutter): remove redundant dependency. ([942c61a2](https://github.com/vowdemon/jolt/commit/942c61a20ba7ebbf9ed553b2f4066268ace7e315))
 - **FEAT**(jolt): allow watcher to receive null as old value when called immediately. ([b101c68e](https://github.com/vowdemon/jolt/commit/b101c68e53ece6ca7e2416b1cd604573e692a459))
 - **DOCS**: improve code documentation. ([c152870a](https://github.com/vowdemon/jolt/commit/c152870a09809628ddc21e4d9d60c65fab563734))
 - **BREAKING** **REFACTOR**: remove JoltResource, add JoltProvider, refactor JoltSelector. ([a91e0860](https://github.com/vowdemon/jolt/commit/a91e0860f7d0302a9d9414ee69a00af21a6c7003))

## 0.0.7

- chore: update dependencies

## 0.0.6

- chore: use `melos` for monorepo management
- feat: add mutual conversion between `ValueListenable`/`ValueNotifier` and `signal`

## 0.0.5
- docs: update README
- chore: bump minimum required jolt version to 0.0.5

## 0.0.4

- chore: update dependencies

## 0.0.3+1

- fix: effect scope context

## 0.0.3

- chore: update dependencies

## 0.0.2+1

- fix: some bugs
- refactor: value notifier extension

## 0.0.2

- Initial version.
