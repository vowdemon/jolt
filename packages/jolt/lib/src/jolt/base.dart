import 'dart:async';

import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:meta/meta.dart';

import '../core/reactive.dart';
import 'shared.dart';

/// Marker interface for mutable collection types.
///
/// This interface is used internally to identify reactive collections
/// that can be modified and need special handling for change detection.
abstract interface class IMutableCollection<T> {}

mixin ReadonlyNodeMixin<T> implements ReadonlyNode<T> {
  @override
  bool get isDisposed => _isDisposed;
  @protected
  bool _isDisposed = false;

  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    onDispose();
    JFinalizer.disposeObject(this);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  String toString() => value.toString();
}

abstract interface class ReadonlyNode<T>
    implements Readonly<T>, ChainedDisposable {
  bool get isDisposed;

  @override
  @protected
  FutureOr<void> onDispose();
}

abstract interface class WritableNode<T>
    implements ReadonlyNode<T>, Writable<T> {}

mixin EffectNode implements ChainedDisposable {
  bool get isDisposed => _isDisposed;
  @protected
  bool _isDisposed = false;

  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    onDispose();
    JFinalizer.disposeObject(this);
  }

  @override
  @protected
  FutureOr<void> onDispose();
}
// /// Base class for all readable reactive values.
// ///
// /// JReadonlyValue provides the foundation for reactive values that can
// /// be read and tracked as dependencies. It handles disposal, dependency
// /// tracking, and notification of subscribers.
// abstract class JReadonlyValue<T> extends ReadonlyNode<T> with NodeMixin<T> {
//   /// Creates a readable reactive value.
//   ///
//   /// Parameters:
//   /// - [flags]: Reactive flags for this node
//   /// - [pendingValue]: Initial internal value storage
//   JReadonlyValue({required super.flags, super.pendingValue});
// }

// /// Interface for writable reactive values.
// ///
// /// JWritableValue extends JReadonlyValue to provide write access,
// /// allowing values to be both read and modified reactively.
// abstract interface class JWritableValue<T>
//     implements JReadonlyValue<T>, WritableNode<T> {}
