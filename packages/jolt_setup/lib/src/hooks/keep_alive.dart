import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Creator class for the useAutomaticKeepAlive hook.
///
/// Provides two ways to control widget keep-alive behavior:
/// - [call]: Accepts a boolean value directly
/// - [value]: Accepts a reactive ReadableNode
class _UseAutomaticKeepAliveCreator {
  const _UseAutomaticKeepAliveCreator._();

  /// Controls whether the widget should be kept alive using a boolean value.
  ///
  /// When [wantKeepAlive] is `true`, the widget will be kept alive even when
  /// it's scrolled out of view (e.g., in a PageView or ListView). When `false`,
  /// the widget will be disposed normally when scrolled out of view.
  ///
  /// Parameters:
  /// - [wantKeepAlive]: Whether to keep the widget alive
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   useAutomaticKeepAlive(true); // Keep widget alive
  ///   return () => MyExpensiveWidget();
  /// }
  /// ```
  void call(bool wantKeepAlive) {
    return useHook(_AutomaticKeepAliveClientHook(
        wantKeepAlive: ReadonlySignal(wantKeepAlive)));
  }

  /// Controls whether the widget should be kept alive using a reactive value.
  ///
  /// When [wantKeepAlive] evaluates to `true`, the widget will be kept alive.
  /// The keep-alive state will automatically update when the reactive value changes.
  ///
  /// Parameters:
  /// - [wantKeepAlive]: A reactive ReadableNode that controls keep-alive
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   final shouldKeepAlive = useSignal(true);
  ///   useAutomaticKeepAlive.value(shouldKeepAlive);
  ///
  ///   return () => Column(
  ///     children: [
  ///       MyExpensiveWidget(),
  ///       ElevatedButton(
  ///         onPressed: () => shouldKeepAlive.value = !shouldKeepAlive.value,
  ///         child: Text('Toggle Keep Alive'),
  ///       ),
  ///     ],
  ///   );
  /// }
  /// ```
  void value(ReadableNode<bool> wantKeepAlive) {
    return useHook(_AutomaticKeepAliveClientHook(wantKeepAlive: wantKeepAlive));
  }
}

/// Hook for controlling widget keep-alive behavior.
///
/// This hook allows you to prevent widgets from being disposed when they're
/// scrolled out of view, which is useful for expensive widgets that should
/// maintain their state (e.g., in PageView, ListView, or TabBarView).
///
/// Use [call] for static boolean values, or [value] for reactive values.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   // Static value
///   useAutomaticKeepAlive(true);
///
///   // Or reactive value
///   final keepAlive = useSignal(true);
///   useAutomaticKeepAlive.value(keepAlive);
///
///   return () => MyExpensiveWidget();
/// }
/// ```
final useAutomaticKeepAlive = _UseAutomaticKeepAliveCreator._();

class _AutomaticKeepAliveClientHook extends SetupHook<void> {
  _AutomaticKeepAliveClientHook({required ReadableNode<bool> wantKeepAlive})
      : _wantKeepAlive = wantKeepAlive;

  final ReadableNode<bool> _wantKeepAlive;
  FlutterEffect? _effect;
  KeepAliveHandle? _keepAliveHandle;

  void _ensureKeepAlive() {
    assert(_keepAliveHandle == null);
    _keepAliveHandle = KeepAliveHandle();
    KeepAliveNotification(_keepAliveHandle!).dispatch(context);
  }

  void _releaseKeepAlive() {
    _keepAliveHandle!.dispose();
    _keepAliveHandle = null;
  }

  bool _isActive = false;

  void updateKeepAlive() {
    if (_wantKeepAlive.peek) {
      if (_keepAliveHandle == null) {
        _ensureKeepAlive();
      }
    } else {
      if (_keepAliveHandle != null) {
        _releaseKeepAlive();
      }
    }
  }

  @override
  @protected
  void mount() {
    _isActive = true;
    _effect = FlutterEffect(() {
      _wantKeepAlive.value;
      if (_isActive) {
        updateKeepAlive();
      }
    });
  }

  @override
  @protected
  void unmount() {
    _effect?.dispose();
    _effect = null;
  }

  @override
  @protected
  void deactivate() {
    if (_keepAliveHandle != null) {
      _releaseKeepAlive();
    }
    _isActive = false;
  }

  // coverage:ignore-start
  @override
  @protected
  void activate() {
    _isActive = true;
    updateKeepAlive();
  }
  // coverage:ignore-end

  @override
  @protected
  void build() {}
}
