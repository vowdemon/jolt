---
---

# SurgeObserver

`SurgeObserver` 是一个抽象观察者类，用于监控 Surge 的生命周期事件，包括创建、状态变化和释放。这对于调试、日志记录或实现横切关注点非常有用。

## 基本用法

创建一个观察者子类并重写你感兴趣的方法，然后将其设置为全局观察者：

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

// 设置全局观察者
SurgeObserver.observer = MyObserver();

// 现在所有 Surge 的生命周期事件都会被观察
final surge = CounterSurge();
// onCreate 被调用

surge.emit(1);
// onChange 被调用

surge.dispose();
// onDispose 被调用
```

## 生命周期方法

### onCreate

当 Surge 被创建时调用。

```dart
class LoggingObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    print('Created Surge with initial state: ${surge.state}');
  }
}
```

### onChange

当 Surge 的状态改变时调用。在状态更新之前调用，允许观察者响应状态变化。

```dart
class ChangeObserver extends SurgeObserver {
  @override
  void onChange(Surge surge, Change change) {
    print('State change: ${change.currentState} -> ${change.nextState}');
  }
}
```

### onDispose

当 Surge 被释放时调用。

```dart
class DisposeObserver extends SurgeObserver {
  @override
  void onDispose(Surge surge) {
    print('Surge disposed with final state: ${surge.state}');
  }
}
```

## 全局观察者

`SurgeObserver.observer` 是一个静态字段，用于设置全局观察者。设置后，所有 Surge 实例的生命周期事件都会通知这个观察者。

```dart
SurgeObserver.observer = MyObserver();

// 现在所有 Surge 生命周期事件都会被观察
final surge1 = CounterSurge(); // onCreate 被调用
final surge2 = UserSurge();    // onCreate 被调用

surge1.emit(1); // onChange 被调用
surge2.emit(User()); // onChange 被调用

surge1.dispose(); // onDispose 被调用
surge2.dispose(); // onDispose 被调用
```

## 实际应用场景

### 调试和日志记录

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

// 在开发环境中启用
if (kDebugMode) {
  SurgeObserver.observer = DebugObserver();
}
```

### 性能监控

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

### 状态持久化

```dart
class PersistenceObserver extends SurgeObserver {
  final Storage _storage;

  PersistenceObserver(this._storage);

  @override
  void onChange(Surge surge, Change change) {
    // 保存状态到持久化存储
    _storage.save('${surge.runtimeType}', change.nextState);
  }

  @override
  void onCreate(Surge surge) {
    // 尝试从持久化存储恢复状态
    final savedState = _storage.load('${surge.runtimeType}');
    if (savedState != null) {
      // 恢复状态（需要根据具体 Surge 类型实现）
    }
  }
}
```

### 分析事件

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

## 注意事项

1. **性能影响**：观察者会在每个 Surge 生命周期事件时被调用，确保观察者实现是高效的，避免阻塞主线程。

2. **内存管理**：如果观察者持有 Surge 的引用，可能导致内存泄漏。确保在不需要时清理引用。

3. **线程安全**：观察者方法可能在多个线程中调用，确保实现是线程安全的。

4. **错误处理**：观察者中的错误不应该影响 Surge 的正常运行，考虑添加错误处理。

5. **选择性观察**：如果只需要观察特定类型的 Surge，可以在观察者方法中添加类型检查。

