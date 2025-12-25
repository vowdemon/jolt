import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/src/widgets/jolt_watch_builder.dart';

/// Extension for creating reactive widgets from Jolt Readable values.
extension JoltFlutterWatchExtension<T> on Readable<T> {
  /// Creates a widget that rebuilds when this value changes.
  ///
  /// The widget automatically tracks this Readable value and rebuilds
  /// whenever it changes.
  ///
  /// Parameters:
  /// - [builder]: Function that builds a widget from the current value
  ///
  /// Returns: A widget that rebuilds when this value changes
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  ///
  /// Column(
  ///   children: [
  ///     counter.watch((value) => Text('Count: $value')),
  ///     ElevatedButton(
  ///       onPressed: () => counter.value++,
  ///       child: Text('Increment'),
  ///     ),
  ///   ],
  /// )
  /// ```
  Widget watch(Widget Function(T value) builder) {
    return JoltWatchBuilder<T>.value(readable: this, builder: builder);
  }
}
