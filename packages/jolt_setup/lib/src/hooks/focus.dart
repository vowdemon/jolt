import 'package:flutter/widgets.dart';

import 'annotation.dart';
import 'listenable.dart';

/// Creates a [FocusNode] for the current setup scope.
///
/// The node is disposed automatically when the setup unmounts. Use this when a
/// widget needs stable focus state created once during setup.
///
/// ```dart
/// setup(context, props) {
///   final focusNode = useFocusNode(debugLabel: 'search');
///
///   onMounted(focusNode.requestFocus);
///
///   return () => TextField(focusNode: focusNode);
/// }
/// ```
@defineHook
FocusNode useFocusNode({
  String? debugLabel,
  KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  bool descendantsAreFocusable = true,
  bool descendantsAreTraversable = true,
}) {
  return useChangeNotifier(
    () => FocusNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      descendantsAreFocusable: descendantsAreFocusable,
      descendantsAreTraversable: descendantsAreTraversable,
    ),
  );
}

/// Creates a [FocusScopeNode] for the current setup scope.
///
/// Use this when the widget owns a dedicated focus scope, such as a dialog,
/// composite input surface, or keyboard-managed section of the tree.
///
/// ```dart
/// setup(context, props) {
///   final scopeNode = useFocusScopeNode(debugLabel: 'editor-scope');
///
///   return () => FocusScope(
///     node: scopeNode,
///     child: const Placeholder(),
///   );
/// }
/// ```
@defineHook
FocusScopeNode useFocusScopeNode({
  String? debugLabel,
  FocusOnKeyEventCallback? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  TraversalEdgeBehavior traversalEdgeBehavior =
      TraversalEdgeBehavior.closedLoop,
  TraversalEdgeBehavior directionalTraversalEdgeBehavior =
      TraversalEdgeBehavior.stop,
}) {
  return useChangeNotifier(
    () => FocusScopeNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      traversalEdgeBehavior: traversalEdgeBehavior,
      directionalTraversalEdgeBehavior: directionalTraversalEdgeBehavior,
    ),
  );
}
