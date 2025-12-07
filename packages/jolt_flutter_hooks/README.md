# Jolt Flutter Hooks

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter_hooks](https://img.shields.io/pub/v/jolt_flutter_hooks?label=jolt_flutter_hooks)](https://pub.dev/packages/jolt_flutter_hooks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Declarative hooks for Flutter widgets built on top of the [Jolt Flutter](https://pub.dev/packages/jolt_flutter) setup system. These hooks help manage common Flutter resources such as controllers, focus nodes, and lifecycle states with automatic cleanup.

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

class MyWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController('Hello');
    final focusNode = useFocusNode();
    
    return Scaffold(
      body: TextField(
        controller: textController,
        focusNode: focusNode,
      ),
    );
  }
}
```

## API Reference

### Listenable Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useValueNotifier<T>(initialValue)` | Creates a value notifier | `ValueNotifier<T>` |
| `useValueListenable<T>(...)` | Listens to a value notifier and triggers rebuilds | `void` |
| `useListenable<T>(...)` | Listens to any listenable and triggers rebuilds | `void` |
| `useListenableSync<T, C>(...)` | Bidirectional sync between Signal and Listenable | `void` |
| `useChangeNotifier<T>(creator)` | Generic ChangeNotifier hook | `T extends ChangeNotifier` |

### Animation Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useSingleTickerProvider()` | Creates a single ticker provider | `TickerProvider` |
| `useTickerProvider()` | Creates a ticker provider that supports multiple tickers | `TickerProvider` |
| `useAnimationController({...})` | Creates an animation controller | `AnimationController` |

### Focus Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useFocusNode({...})` | Creates a focus node | `FocusNode` |
| `useFocusScopeNode({...})` | Creates a focus scope node | `FocusScopeNode` |

### Lifecycle Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useAppLifecycleState([initialState])` | Listens to app lifecycle state | `ReadonlySignal<AppLifecycleState?>` |

### Scroll Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useScrollController({...})` | Creates a scroll controller | `ScrollController` |
| `useTrackingScrollController({...})` | Creates a tracking scroll controller | `TrackingScrollController` |
| `useTabController({...})` | Creates a tab controller | `TabController` |
| `usePageController({...})` | Creates a page controller | `PageController` |
| `useFixedExtentScrollController({...})` | Creates a fixed extent scroll controller | `FixedExtentScrollController` |
| `useDraggableScrollableController()` | Creates a draggable scrollable controller | `DraggableScrollableController` |
| `useCarouselController({...})` | Creates a carousel controller | `CarouselController` |

### Text Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useTextEditingController([text])` | Creates a text editing controller | `TextEditingController` |
| `useTextEditingController.fromValue([value])` | Creates a text editing controller from value | `TextEditingController` |
| `useRestorableTextEditingController([value])` | Creates a restorable text editing controller | `RestorableTextEditingController` |
| `useSearchController()` | Creates a search controller | `SearchController` |
| `useUndoHistoryController({...})` | Creates an undo history controller | `UndoHistoryController` |

### Controller Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useTransformationController([value])` | Creates a transformation controller | `TransformationController` |
| `useWidgetStatesController([value])` | Creates a widget states controller | `WidgetStatesController` |
| `useExpansibleController()` | Creates an expansible controller | `ExpansibleController` |
| `useTreeSliverController()` | Creates a tree sliver controller | `TreeSliverController` |
| `useOverlayPortalController({...})` | Creates an overlay portal controller | `OverlayPortalController` |
| `useSnapshotController({...})` | Creates a snapshot controller | `SnapshotController` |
| `useCupertinoTabController({...})` | Creates a Cupertino tab controller | `CupertinoTabController` |
| `useContextMenuController({...})` | Creates a context menu controller | `ContextMenuController` |
| `useMenuController()` | Creates a menu controller | `MenuController` |
| `useMagnifierController({...})` | Creates a magnifier controller | `MagnifierController` |


### Async Hooks
| Hook | Description | Returns |
|------|-------------|---------|
| `useFuture<T>(future, {...})` | Creates a reactive future signal | `AsyncSnapshotFutureSignal<T>` |
| `useStream<T>(stream, {...})` | Creates a reactive stream signal | `AsyncSnapshotStreamSignal<T>` |
| `useStreamController<T>(...)` | Creates a stream controller | `StreamController<T>` |
| `useStreamSubscription<T>(...)` | Manages a stream subscription | `void` |

### Keep Alive Hook
| Hook | Description | Returns |
|------|-------------|---------|
| `useAutomaticKeepAlive(wantKeepAlive)` | Manages automatic keep alive with reactive signal | `void` |


## Related Packages

Jolt Flutter Hooks is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider, and SetupWidget |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
