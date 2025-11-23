# Todo List Example

An elegant, fully-featured todo list application showcasing **Jolt Flutter Hooks** - a powerful combination of Jolt's reactivity system with Flutter's widget lifecycle. This example demonstrates complex state management, computed values, side effects, and sophisticated animations.

## Overview

This todo list app goes beyond basic CRUD operations. It features filtering, statistics, smooth animations, and demonstrates how Jolt Hooks enable a React-like development experience in Flutter with automatic dependency tracking and lifecycle management.

## Features

### Core Functionality
- **Add Todos**: Create new todo items with text input
- **Toggle Completion**: Mark todos as complete or incomplete
- **Edit Todos**: Double-tap to edit existing todos inline
- **Delete Todos**: Remove individual todos with smooth exit animations
- **Filter Todos**: View all, active only, or completed todos
- **Bulk Actions**: Check/uncheck all todos, clear completed todos

### Advanced Features
- **Real-time Statistics**: Live count of total, active, and completed todos
- **Computed Values**: Derived state that automatically updates
- **Side Effects**: Automatic logging and state synchronization
- **Rich Animations**: 
  - Page fade-in on load
  - Staggered item entry animations
  - Smooth removal transitions
  - Completion state pulse effects
  - Filter chip scale animations

## Jolt Hooks Concepts Demonstrated

### SetupWidget

`SetupWidget` is a special widget that uses a `setup` method instead of `build`, allowing you to use hooks and return a builder function.

```dart
class TodoWidget extends SetupWidget<TodoWidget> {
  @override
  setup(context, props) {
    // Use hooks here
    final todos = useSignal.list<Todo>([]);
    return () => YourWidget(); // Return builder function
  }
}
```

### useSignal

Creates reactive state that triggers rebuilds when changed. Supports various types including lists.

```dart
final todos = useSignal.list<Todo>([]);
final filter = useSignal<FilterType>(FilterType.all);

// Update values
todos.add(newTodo);
filter.value = FilterType.active;
```

### useComputed

Creates derived state that automatically recomputes when dependencies change. Perfect for filtering, calculations, and transformations.

```dart
final filteredTodos = useComputed(() {
  switch (filter.value) {
    case FilterType.active:
      return todos.value.where((todo) => !todo.completed).toList();
    case FilterType.completed:
      return todos.value.where((todo) => todo.completed).toList();
    default:
      return todos.value;
  }
});

final stats = useComputed(() {
  final total = todos.value.length;
  final completed = todos.value.where((todo) => todo.completed).length;
  return {'total': total, 'completed': completed, 'active': total - completed};
});
```

### useMemoized

Memoizes expensive computations, recalculating only when dependencies change. Ideal for animation tweens and complex calculations.

```dart
final pageFadeAnimation = useMemoized(
  () => Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: pageAnimationController,
      curve: Curves.easeOut,
    ),
  ),
);
```

### Effect

Performs side effects that run automatically when dependencies change. Useful for logging, synchronization, and triggering animations.

```dart
Effect(() {
  debugPrint('Todo list updated: ${stats.value}');
});

Effect(() {
  if (prevCompleted.value != todo.value.completed) {
    // Trigger animation when completion state changes
    completeController.reset();
    completeController.forward();
  }
});
```

### useAnimationController

Integrates Flutter's animation controllers with Jolt's reactivity system.

```dart
final pageAnimationController = useAnimationController(
  duration: const Duration(milliseconds: 600),
);
```

### Lifecycle Hooks

- **onMounted**: Runs when the widget is first mounted
- Automatic cleanup when widgets are disposed

```dart
onMounted(() {
  Future.delayed(Duration(milliseconds: index.value * 50), () {
    enterController.forward();
  });
});
```

## Architecture Patterns

### Component Composition

The app uses a main `TodoWidget` and a separate `_AnimatedTodoItem` component, demonstrating how to compose complex UIs from smaller, reusable pieces.

### Animation Orchestration

Multiple animation controllers work together:
- Page-level fade-in
- Header slide and fade
- Staggered item entry
- Item removal transitions
- Completion state pulses

### Reactive Dependencies

Jolt automatically tracks which signals are accessed in `useComputed` and `Effect`, ensuring updates happen at the right time without manual dependency management.

## Running the Example

```bash
cd examples/todo_list
flutter run
```

## Key Learnings

1. **Hooks Pattern**: React-like hooks for Flutter widgets
2. **Automatic Dependency Tracking**: No need to manually specify dependencies
3. **Computed Values**: Derive state from other state automatically
4. **Side Effects**: Handle side effects declaratively with `Effect`
5. **Animation Integration**: Seamlessly combine Jolt reactivity with Flutter animations
6. **Lifecycle Management**: Automatic cleanup and lifecycle hooks
7. **Performance**: Memoization prevents unnecessary recalculations

This example demonstrates how Jolt Hooks can make complex, interactive UIs more maintainable and easier to reason about, while providing excellent performance through automatic optimization.
