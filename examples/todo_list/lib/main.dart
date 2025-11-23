import 'package:flutter/material.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

enum FilterType { all, active, completed }

class Todo {
  final String id;
  final String text;
  final bool completed;

  Todo({
    required this.id,
    required this.text,
    this.completed = false,
  });

  Todo copyWith({String? text, bool? completed}) {
    return Todo(
      id: id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
    );
  }
}

class TodoWidget extends SetupWidget<TodoWidget> {
  const TodoWidget({super.key});

  @override
  setup(context, props) {
    final todos = useSignal.list<Todo>([]);
    final filter = useSignal<FilterType>(FilterType.all);
    final inputController = useTextEditingController();
    final inputFocus = useFocusNode();
    final scrollController = useScrollController();

    // Page fade-in animation
    final pageAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final pageFadeAnimation = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: pageAnimationController,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Header and input area animation
    final headerAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final headerSlideAnimation = useMemoized(
      () =>
          Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
        CurvedAnimation(
          parent: headerAnimationController,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    final headerFadeAnimation = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: headerAnimationController,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Computed values
    final filteredTodos = useComputed(() {
      switch (filter.value) {
        case FilterType.active:
          return todos.value.where((todo) => !todo.completed).toList();
        case FilterType.completed:
          return todos.value.where((todo) => todo.completed).toList();
        case FilterType.all:
          return todos.value;
      }
    });

    final stats = useComputed(() {
      final total = todos.value.length;
      final completed = todos.value.where((todo) => todo.completed).length;
      final active = total - completed;
      return {'total': total, 'completed': completed, 'active': active};
    });

    // Initialize animations
    Effect(() {
      if (pageAnimationController.status == AnimationStatus.dismissed) {
        pageAnimationController.forward();
      }
      if (headerAnimationController.status == AnimationStatus.dismissed) {
        headerAnimationController.forward();
      }
    });

    // Effects - directly create Effect, it should track dependencies automatically
    final e = Effect(() {
      debugPrint('Todo list updated: ${stats.value}');
    });
    debugPrint(
        (e as EffectImpl).depsTail?.dep.runtimeType.toString() ?? 'null');

    // Actions
    void addTodo() {
      final text = inputController.text.trim();
      if (text.isNotEmpty) {
        todos.add(Todo(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
        ));
        inputController.clear();
        inputFocus.requestFocus();
      }
    }

    void toggleTodo(String id) {
      final index = todos.value.indexWhere((todo) => todo.id == id);
      if (index != -1) {
        todos[index] =
            todos[index].copyWith(completed: !todos[index].completed);
      }
    }

    void removeTodo(String id) {
      todos.removeWhere((todo) => todo.id == id);
    }

    void editTodo(String id, String newText) {
      final index = todos.value.indexWhere((todo) => todo.id == id);
      if (index != -1 && newText.trim().isNotEmpty) {
        todos[index] = todos[index].copyWith(text: newText.trim());
      }
    }

    void clearCompleted() {
      todos.removeWhere((todo) => todo.completed);
    }

    void toggleAll() {
      final allCompleted = todos.value.every((todo) => todo.completed);
      for (int i = 0; i < todos.length; i++) {
        todos[i] = todos[i].copyWith(completed: !allCompleted);
      }
    }

    return () => FadeTransition(
          opacity: pageFadeAnimation,
          child: Column(
            children: [
              // Header - with slide-in and fade-in animation
              SlideTransition(
                position: headerSlideAnimation,
                child: FadeTransition(
                  opacity: headerFadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Jolt Todo List',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            'Total: ${stats.value['total']} | '
                            'Active: ${stats.value['active']} | '
                            'Completed: ${stats.value['completed']}',
                            key: ValueKey(stats.value),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Input section - with slide-in animation
              SlideTransition(
                position: headerSlideAnimation,
                child: FadeTransition(
                  opacity: headerFadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inputController,
                            focusNode: inputFocus,
                            onSubmitted: (_) => addTodo(),
                            decoration: InputDecoration(
                              hintText: 'What needs to be done?',
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: addTodo,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Filter buttons - with switch animation
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey(filter.value),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: filter.value == FilterType.all,
                        onSelected: (_) => filter.value = FilterType.all,
                        selectedColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Active'),
                        selected: filter.value == FilterType.active,
                        onSelected: (_) => filter.value = FilterType.active,
                        selectedColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Completed'),
                        selected: filter.value == FilterType.completed,
                        onSelected: (_) => filter.value = FilterType.completed,
                        selectedColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              if (todos.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: toggleAll,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          todos.value.every((todo) => todo.completed)
                              ? 'Uncheck All'
                              : 'Check All',
                        ),
                      ),
                      if (stats.value['completed']! > 0)
                        TextButton.icon(
                          onPressed: clearCompleted,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear Completed'),
                        ),
                    ],
                  ),
                ),

              // Todo list - with staggered animation
              Expanded(
                child: filteredTodos.value.isEmpty
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale:
                                  Tween<double>(begin: 0.8, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          key: ValueKey('empty-${filter.value}'),
                          child: Text(
                            filter.value == FilterType.all
                                ? 'No todos yet'
                                : filter.value == FilterType.active
                                    ? 'No active todos'
                                    : 'No completed todos',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filteredTodos.value.length,
                        itemBuilder: (context, index) {
                          final todo = filteredTodos.value[index];
                          return _AnimatedTodoItem(
                            key: ValueKey(todo.id),
                            todo: todo,
                            index: index,
                            onToggle: () => toggleTodo(todo.id),
                            onRemove: () => removeTodo(todo.id),
                            onEdit: (newText) => editTodo(todo.id, newText),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
  }
}

// Animated Todo item component using useAnimationController
class _AnimatedTodoItem extends SetupWidget<_AnimatedTodoItem> {
  final Todo todo;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final void Function(String) onEdit;

  const _AnimatedTodoItem({
    super.key,
    required this.todo,
    required this.index,
    required this.onToggle,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  setup(context, props) {
    // Call props() inside useComputed to establish reactive dependencies
    final todo = useComputed(() => props().todo);
    final index = useComputed(() => props().index);

    final editController = useTextEditingController();
    final editFocus = useFocusNode();
    final isEditing = useSignal(false);
    final prevCompleted = useSignal(false);

    // Enter animation - staggered delay
    final enterController = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );
    final enterSlideAnimation = useMemoized(
      () =>
          Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: enterController,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    final enterFadeAnimation = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: enterController,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Remove animation
    final removeController = useAnimationController(
      duration: const Duration(milliseconds: 300),
    );
    final removeSlideAnimation = useMemoized(
      () =>
          Tween<Offset>(begin: Offset.zero, end: const Offset(1.0, 0)).animate(
        CurvedAnimation(
          parent: removeController,
          curve: Curves.easeIn,
        ),
      ),
    );
    final removeFadeAnimation = useMemoized(
      () => Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: removeController,
          curve: Curves.easeIn,
        ),
      ),
    );

    // Completion state toggle animation - fade change of todo content
    final completeController = useAnimationController(
      duration: const Duration(milliseconds: 300),
    );
    final completeFadeAnimation = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.5)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.5, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50,
        ),
      ]).animate(completeController),
    );

    // Initialize enter animation (staggered delay) and initial state
    onMounted(() {
      Future.delayed(Duration(milliseconds: index.value * 50), () {
        enterController.forward();
      });
      editController.text = todo.value.text;
      prevCompleted.value = todo.value.completed;
    });

    // Listen to todo changes, update edit controller
    Effect(() {
      if (!isEditing.value) {
        editController.text = todo.value.text;
      }
    });

    // Listen to completion state changes, trigger subtle pulse animation
    Effect(() {
      if (prevCompleted.value != todo.value.completed) {
        prevCompleted.value = todo.value.completed;
        // Trigger pulse animation
        completeController.reset();
        completeController.forward();
      }
    });

    void startEdit() {
      isEditing.value = true;
      editFocus.requestFocus();
      editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: editController.text.length,
      );
    }

    void saveEdit() {
      if (editController.text.trim() != todo.value.text) {
        onEdit(editController.text);
      }
      isEditing.value = false;
    }

    void cancelEdit() {
      editController.text = todo.value.text;
      isEditing.value = false;
    }

    void handleRemove() {
      removeController.forward().then((_) {
        onRemove();
      });
    }

    // Build animation combination
    return () {
      final currentTodo = todo.value;
      final isRemoving = removeController.value > 0;

      Widget itemWidget = _buildTodoItem(
        context,
        currentTodo,
        isEditing.value,
        editController,
        editFocus,
        startEdit,
        saveEdit,
        cancelEdit,
        handleRemove,
        onToggle,
        completeFadeAnimation,
        completeController,
      );

      // If removing, show remove animation
      if (isRemoving) {
        return SlideTransition(
          position: removeSlideAnimation,
          child: FadeTransition(
            opacity: removeFadeAnimation,
            child: itemWidget,
          ),
        );
      }

      // Normal display with enter animation
      return SlideTransition(
        position: enterSlideAnimation,
        child: FadeTransition(
          opacity: enterFadeAnimation,
          child: itemWidget,
        ),
      );
    };
  }

  Widget _buildTodoItem(
    BuildContext context,
    Todo todo,
    bool isEditing,
    TextEditingController editController,
    FocusNode editFocus,
    VoidCallback startEdit,
    VoidCallback saveEdit,
    VoidCallback cancelEdit,
    VoidCallback handleRemove,
    VoidCallback onToggle,
    Animation<double> completeFadeAnimation,
    AnimationController completeController,
  ) {
    final shouldAnimateComplete =
        completeController.value > 0 || completeController.isAnimating;

    return ListTile(
      leading: Checkbox(
        value: todo.completed,
        onChanged: (_) => onToggle(),
      ),
      title: isEditing
          ? TextField(
              controller: editController,
              focusNode: editFocus,
              onSubmitted: (_) => saveEdit(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            )
          : GestureDetector(
              onDoubleTap: startEdit,
              child: shouldAnimateComplete
                  ? FadeTransition(
                      opacity: completeFadeAnimation,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          decoration: todo.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.completed ? Colors.grey : null,
                        ),
                        child: Text(todo.text),
                      ),
                    )
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        decoration:
                            todo.completed ? TextDecoration.lineThrough : null,
                        color: todo.completed ? Colors.grey : null,
                      ),
                      child: Text(todo.text),
                    ),
            ),
      trailing: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: saveEdit,
                  color: Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: cancelEdit,
                  color: Colors.red,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: startEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: handleRemove,
                  color: Colors.red,
                ),
              ],
            ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jolt Todo List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TodoPage(),
    );
  }
}

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jolt Todo List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const TodoWidget(),
    );
  }
}
