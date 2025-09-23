import 'package:jolt/jolt.dart' as jolt;

import '../mixins/value_notifier.dart';
import 'signal.dart';

/// A signal that handles asynchronous operations with state tracking.
///
/// [AsyncSignal] wraps asynchronous data sources and provides reactive state
/// management for loading, success, and error states. It integrates with Flutter's
/// ValueNotifier system for seamless widget integration.
///
/// ## Parameters
///
/// - [source]: The asynchronous data source to wrap
/// - [initialValue]: Optional initial state value
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final userSignal = AsyncSignal(FutureSource(fetchUser()));
///
/// JoltBuilder(
///   builder: (context) => userSignal.value.when(
///     loading: () => CircularProgressIndicator(),
///     data: (user) => Text('Hello ${user.name}'),
///     error: (error) => Text('Error: $error'),
///   ),
/// )
/// ```
class AsyncSignal<T> extends jolt.AsyncSignal<T>
    with JoltValueNotifier<jolt.AsyncState<T>>
    implements ReadonlySignal<jolt.AsyncState<T>> {
  AsyncSignal(super.source, {super.initialValue, super.autoDispose});

  /// Creates an AsyncSignal from a Future.
  ///
  /// This factory constructor provides a convenient way to create an AsyncSignal
  /// from a Future, automatically wrapping it in a FutureSource.
  ///
  /// ## Parameters
  ///
  /// - [future]: The Future to wrap
  ///
  /// ## Returns
  ///
  /// An [AsyncSignal] that tracks the Future's state
  ///
  /// ## Example
  ///
  /// ```dart
  /// final userData = AsyncSignal.fromFuture(
  ///   http.get('/api/user').then((response) => User.fromJson(response.data))
  /// );
  ///
  /// // Use in widgets
  /// JoltBuilder(
  ///   builder: (context) => userData.value.maybeWhen(
  ///     data: (user) => UserProfile(user),
  ///     orElse: () => LoadingSpinner(),
  ///   ),
  /// )
  /// ```
  factory AsyncSignal.fromFuture(Future<T> future) {
    return AsyncSignal(jolt.FutureSource(future));
  }

  /// Creates an AsyncSignal from a Stream.
  ///
  /// This factory constructor provides a convenient way to create an AsyncSignal
  /// from a Stream, automatically wrapping it in a StreamSource.
  ///
  /// ## Parameters
  ///
  /// - [stream]: The Stream to wrap
  ///
  /// ## Returns
  ///
  /// An [AsyncSignal] that tracks the Stream's values
  ///
  /// ## Example
  ///
  /// ```dart
  /// final messagesSignal = AsyncSignal.fromStream(
  ///   FirebaseFirestore.instance
  ///     .collection('messages')
  ///     .snapshots()
  ///     .map((snapshot) => snapshot.docs.map((doc) => Message.fromDoc(doc)))
  /// );
  ///
  /// // Use in widgets
  /// JoltBuilder(
  ///   builder: (context) => messagesSignal.value.when(
  ///     loading: () => Text('Loading messages...'),
  ///     data: (messages) => MessageList(messages),
  ///     error: (error) => Text('Failed to load: $error'),
  ///   ),
  /// )
  /// ```
  factory AsyncSignal.fromStream(Stream<T> stream) {
    return AsyncSignal(jolt.StreamSource(stream));
  }
}

/// A signal specifically for handling Future-based asynchronous operations.
///
/// [FutureSignal] is a specialized async signal for working with Futures.
/// It provides the same reactive state management as AsyncSignal but is
/// specifically typed for Future sources.
///
/// ## Parameters
///
/// - [source]: The Future to track
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final apiCall = FutureSignal(fetchUserData());
///
/// JoltBuilder(
///   builder: (context) => apiCall.value.when(
///     loading: () => CircularProgressIndicator(),
///     data: (data) => DataWidget(data),
///     error: (error) => ErrorWidget(error),
///   ),
/// )
/// ```
class FutureSignal<T> extends jolt.FutureSignal<T>
    with JoltValueNotifier<jolt.AsyncState<T>>
    implements ReadonlySignal<jolt.AsyncState<T>> {
  FutureSignal(super.source, {super.autoDispose});
}

/// A signal specifically for handling Stream-based asynchronous operations.
///
/// [StreamSignal] is a specialized async signal for working with Streams.
/// It provides reactive state management for continuous data streams and
/// integrates with Flutter's ValueNotifier system.
///
/// ## Parameters
///
/// - [source]: The Stream to track
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final chatMessages = StreamSignal(
///   FirebaseFirestore.instance
///     .collection('chat')
///     .orderBy('timestamp')
///     .snapshots()
///     .map((snapshot) => snapshot.docs.map(Message.fromDoc))
/// );
///
/// JoltBuilder(
///   builder: (context) => chatMessages.value.when(
///     loading: () => Text('Connecting...'),
///     data: (messages) => ChatList(messages),
///     error: (error) => Text('Connection failed: $error'),
///   ),
/// )
/// ```
class StreamSignal<T> extends jolt.StreamSignal<T>
    with JoltValueNotifier<jolt.AsyncState<T>>
    implements ReadonlySignal<jolt.AsyncState<T>> {
  StreamSignal(super.source, {super.autoDispose});
}
