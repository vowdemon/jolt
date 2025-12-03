---
---

# SurgeObserver

`SurgeObserver` is an abstract observer class for monitoring Surge lifecycle events, including creation, state changes, and disposal. This is very useful for debugging, logging, or implementing cross-cutting concerns.

## Basic Usage

Create an observer subclass and override the methods you're interested in, then set it as the global observer:

```dart
class MyObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    print('Surge created: $surge');
  }

  @override
  void onChange(Surge surge, Change change) {
    print('State changed: ${change.currentState} -> ${change.nextState}');
  }

  @override
  void onDispose(Surge surge) {
    print('Surge disposed: $surge');
  }
}

// Set global observer
SurgeObserver.observer = MyObserver();

// Now all Surge lifecycle events will be observed
final surge = CounterSurge();
// onCreate is called

surge.emit(1);
// onChange is called

surge.dispose();
// onDispose is called
```

## Lifecycle Methods

### onCreate

Called when Surge is created.

```dart
class LoggingObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    print('Created Surge with initial state: ${surge.state}');
  }
}
```

### onChange

Called when Surge state changes. Called before state is updated, allowing observers to respond to state changes.

```dart
class ChangeObserver extends SurgeObserver {
  @override
  void onChange(Surge surge, Change change) {
    print('State change: ${change.currentState} -> ${change.nextState}');
  }
}
```

### onDispose

Called when Surge is disposed.

```dart
class DisposeObserver extends SurgeObserver {
  @override
  void onDispose(Surge surge) {
    print('Surge disposed with final state: ${surge.state}');
  }
}
```

## Global Observer

`SurgeObserver.observer` is a static field for setting the global observer. Once set, all Surge instance lifecycle events will notify this observer.

```dart
SurgeObserver.observer = MyObserver();

// Now all Surge lifecycle events will be observed
final surge1 = CounterSurge(); // onCreate is called
final surge2 = UserSurge();    // onCreate is called

surge1.emit(1); // onChange is called
surge2.emit(User()); // onChange is called

surge1.dispose(); // onDispose is called
surge2.dispose(); // onDispose is called
```

## Practical Use Cases

### Debugging and Logging

```dart
class DebugObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    debugPrint('🔵 Surge created: ${surge.runtimeType}');
  }

  @override
  void onChange(Surge surge, Change change) {
    debugPrint('🟢 State changed in ${surge.runtimeType}: ${change.currentState} -> ${change.nextState}');
  }

  @override
  void onDispose(Surge surge) {
    debugPrint('🔴 Surge disposed: ${surge.runtimeType}');
  }
}

// Enable in development environment
if (kDebugMode) {
  SurgeObserver.observer = DebugObserver();
}
```

### Performance Monitoring

```dart
class PerformanceObserver extends SurgeObserver {
  final Map<Surge, Stopwatch> _stopwatches = {};

  @override
  void onCreate(Surge surge) {
    _stopwatches[surge] = Stopwatch()..start();
  }

  @override
  void onChange(Surge surge, Change change) {
    final stopwatch = _stopwatches[surge];
    if (stopwatch != null) {
      print('${surge.runtimeType} state change took ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.reset();
      stopwatch.start();
    }
  }

  @override
  void onDispose(Surge surge) {
    final stopwatch = _stopwatches.remove(surge);
    if (stopwatch != null) {
      print('${surge.runtimeType} lifetime: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}
```

### State Persistence

```dart
class PersistenceObserver extends SurgeObserver {
  final Storage _storage;

  PersistenceObserver(this._storage);

  @override
  void onChange(Surge surge, Change change) {
    // Save state to persistent storage
    _storage.save('${surge.runtimeType}', change.nextState);
  }

  @override
  void onCreate(Surge surge) {
    // Try to restore state from persistent storage
    final savedState = _storage.load('${surge.runtimeType}');
    if (savedState != null) {
      // Restore state (needs implementation based on specific Surge type)
    }
  }
}
```

### Analytics Events

```dart
class AnalyticsObserver extends SurgeObserver {
  final AnalyticsService _analytics;

  AnalyticsObserver(this._analytics);

  @override
  void onCreate(Surge surge) {
    _analytics.logEvent('surge_created', {
      'type': surge.runtimeType.toString(),
    });
  }

  @override
  void onChange(Surge surge, Change change) {
    _analytics.logEvent('surge_state_changed', {
      'type': surge.runtimeType.toString(),
      'from': change.currentState.toString(),
      'to': change.nextState.toString(),
    });
  }
}
```

## Important Notes

1. **Performance Impact**: Observers are called on every Surge lifecycle event. Ensure observer implementations are efficient and avoid blocking the main thread.

2. **Memory Management**: If observers hold references to Surges, it may cause memory leaks. Ensure references are cleaned up when not needed.

3. **Thread Safety**: Observer methods may be called in multiple threads. Ensure implementations are thread-safe.

4. **Error Handling**: Errors in observers should not affect Surge's normal operation. Consider adding error handling.

5. **Selective Observation**: If you only need to observe specific types of Surges, you can add type checks in observer methods.

