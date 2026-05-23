import 'package:flutter/cupertino.dart';

import '../setup/framework.dart';
import 'annotation.dart';
import 'listenable.dart';

/// Creates a [TransformationController] for the current setup scope.
///
/// Use this with [InteractiveViewer] when pan and zoom state should survive
/// rebuilds.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTransformationController();
///
///   return () => InteractiveViewer(
///     transformationController: controller,
///     child: const FlutterLogo(size: 200),
///   );
/// }
/// ```
@defineHook
TransformationController useTransformationController([Matrix4? value]) {
  return useChangeNotifier(
    () => TransformationController(value),
  );
}

/// Creates a [WidgetStatesController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useWidgetStatesController();
///
///   return () => MenuAnchor(controller: controller);
/// }
/// ```
@defineHook
WidgetStatesController useWidgetStatesController([Set<WidgetState>? value]) {
  return useChangeNotifier(() => WidgetStatesController(value));
}

/// Creates an [ExpansibleController] for the current setup scope.
///
/// Use this when expandable UI state should be owned by setup rather than
/// recreated during rebuilds.
///
/// ```dart
/// setup(context, props) {
///   final controller = useExpansibleController();
///
///   return () => Expansible(controller: controller, child: const Text('Body'));
/// }
/// ```
@defineHook
ExpansibleController useExpansibleController() {
  return useChangeNotifier(() => ExpansibleController());
}

/// Creates a [TreeSliverController] for the current setup scope.
///
/// Use this with tree sliver widgets whose expansion and selection state
/// should be preserved across rebuilds.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTreeSliverController();
///   final tree = [TreeSliverNode<String>('Inbox')];
///
///   return () => CustomScrollView(
///     slivers: [
///       TreeSliver<String>(
///         controller: controller,
///         tree: tree,
///       ),
///     ],
///   );
/// }
/// ```
@defineHook
TreeSliverController useTreeSliverController() {
  return useMemoized(() => TreeSliverController());
}

/// Creates an [OverlayPortalController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useOverlayPortalController();
///
///   return () => OverlayPortal(
///     controller: controller,
///     overlayChildBuilder: (_) => const Text('Overlay'),
///     child: const Text('Anchor'),
///   );
/// }
/// ```
@defineHook
OverlayPortalController useOverlayPortalController({String? debugLabel}) {
  return useMemoized(() => OverlayPortalController(debugLabel: debugLabel));
}

/// Creates a [SnapshotController] for the current setup scope.
///
/// Use [allowSnapshotting] to opt into snapshot capture for widgets that
/// support it.
///
/// ```dart
/// setup(context, props) {
///   final controller = useSnapshotController(allowSnapshotting: true);
///
///   return () => SnapshotWidget(
///     controller: controller,
///     child: const Text('Preview'),
///   );
/// }
/// ```
@defineHook
SnapshotController useSnapshotController({bool allowSnapshotting = false}) {
  return useChangeNotifier(
      () => SnapshotController(allowSnapshotting: allowSnapshotting));
}

/// Creates a [CupertinoTabController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useCupertinoTabController();
///
///   return () => CupertinoTabScaffold(
///     controller: controller,
///     tabBar: const CupertinoTabBar(items: []),
///     tabBuilder: (_, __) => const SizedBox.shrink(),
///   );
/// }
/// ```
@defineHook
CupertinoTabController useCupertinoTabController({int initialIndex = 0}) {
  return useChangeNotifier(
      () => CupertinoTabController(initialIndex: initialIndex));
}

/// Creates a [ContextMenuController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useContextMenuController();
///
///   return () => ContextMenuRegion(controller: controller, child: Text('Menu'));
/// }
/// ```
@defineHook
ContextMenuController useContextMenuController({VoidCallback? onRemove}) {
  return useMemoized(() => ContextMenuController(onRemove: onRemove));
}

/// Creates a [MenuController] for the current setup scope.
///
/// Use this when menu open state should be controlled from setup logic.
///
/// ```dart
/// setup(context, props) {
///   final controller = useMenuController();
///
///   return () => MenuAnchor(
///     controller: controller,
///     menuChildren: const [MenuItemButton(child: Text('Open'))],
///     child: TextButton(
///       onPressed: controller.open,
///       child: const Text('Menu'),
///     ),
///   );
/// }
/// ```
@defineHook
MenuController useMenuController() {
  return useMemoized(() => MenuController());
}

/// Creates a [MagnifierController] for the current setup scope.
///
/// Supply [animationController] when magnifier animations should share an
/// existing animation timeline.
///
/// ```dart
/// setup(context, props) {
///   final vsync = useSingleTickerProvider();
///   final animation = useAnimationController(
///     vsync: vsync,
///     duration: const Duration(milliseconds: 120),
///   );
///   final magnifier = useMagnifierController(
///     animationController: animation,
///   );
///
///   onUnmounted(magnifier.hide);
///
///   return () => const TextField();
/// }
/// ```
@defineHook
MagnifierController useMagnifierController(
    {AnimationController? animationController}) {
  return useMemoized(
      () => MagnifierController(animationController: animationController));
}
