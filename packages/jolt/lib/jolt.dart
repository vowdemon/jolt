/// Jolt - A high-performance reactive system for Dart and Flutter.
///
/// Jolt provides a complete reactive programming solution with signals, computed values,
/// effects, and reactive collections. It's designed for building responsive applications
/// with automatic dependency tracking and efficient updates.
///
/// ## Core Concepts
///
/// ### Signals
/// Signals are reactive containers that hold values and notify subscribers when changed:
/// ```dart
/// final counter = Signal(0);
/// counter.value = 1; // Automatically notifies subscribers
/// ```
///
/// ### Computed Values
/// Computed values derive from other reactive values and update automatically:
/// ```dart
/// final doubled = Computed(() => counter.value * 2);
/// ```
///
/// ### Effects
/// Effects run side-effect functions when their dependencies change:
/// ```dart
/// Effect(() {
///   print('Counter: ${counter.value}');
/// });
/// ```
///
/// ## Quick Start
///
/// ```dart
/// import 'package:jolt/jolt.dart';
///
/// void main() {
///   // Create reactive state
///   final name = Signal('World');
///   final greeting = Computed(() => 'Hello, ${name.value}!');
///
///   // React to changes
///   Effect(() {
///     print(greeting.value); // Prints: "Hello, World!"
///   });
///
///   // Update state
///   name.value = 'Jolt'; // Prints: "Hello, Jolt!"
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Async Operations
/// Handle asynchronous operations with built-in state management:
/// ```dart
/// final userSignal = AsyncSignal.fromFuture(fetchUser());
///
/// Effect(() {
///   final state = userSignal.value;
///   if (state.isLoading) print('Loading...');
///   if (state.isSuccess) print('User: ${state.data}');
///   if (state.isError) print('Error: ${state.error}');
/// });
/// ```
///
/// ### Reactive Collections
/// Work with reactive lists, sets, and maps:
/// ```dart
/// final items = ListSignal(['apple', 'banana']);
/// final tags = SetSignal({'dart', 'flutter'});
/// final userMap = MapSignal({'name': 'Alice', 'age': 30});
///
/// // All mutations trigger reactive updates
/// items.add('cherry');
/// tags.add('reactive');
/// userMap['city'] = 'New York';
/// ```
///
/// ### Batching Updates
/// Batch multiple updates to prevent intermediate notifications:
/// ```dart
/// batch(() {
///   firstName.value = 'Jane';
///   lastName.value = 'Smith';
/// }); // Single notification for both changes
/// ```
///
/// ### Untracked Access
/// Access values without creating dependencies:
/// ```dart
/// final computed = Computed(() {
///   final tracked = signal1.value; // Creates dependency
///   final untracked = untracked(() => signal2.value); // No dependency
///   return '$tracked + $untracked';
/// });
/// ```
///
/// ### Effect Scopes
/// Manage effect lifecycles with automatic cleanup:
/// ```dart
/// final scope = EffectScope((scope) {
///   Effect(() => print('Reactive effect'));
///   // Effects are automatically disposed when scope is disposed
/// });
///
/// scope.dispose(); // Cleans up all effects in scope
/// ```
///
/// ## Extension Methods
///
/// Convert existing types to reactive equivalents:
/// ```dart
/// final reactiveList = [1, 2, 3].toListSignal();
/// final reactiveMap = {'key': 'value'}.toMapSignal();
/// final asyncSignal = someFuture.toAsyncSignal();
/// final streamSignal = someStream.toStreamSignal();
/// ```
library;

export 'src/base.dart';
export 'src/effect.dart';
export 'src/computed.dart';
export 'src/signal.dart';
export 'src/async.dart';
export 'src/utils.dart';
export 'src/untracked.dart';
export 'src/batch.dart';

export 'src/collection/iterable_signal.dart';
export 'src/collection/list_signal.dart';
export 'src/collection/map_signal.dart';
export 'src/collection/set_signal.dart';
export 'src/extension/signal.dart';
export 'src/extension/stream.dart';
export 'src/extension/watcher.dart';
