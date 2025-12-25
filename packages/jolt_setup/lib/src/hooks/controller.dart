import 'package:flutter/cupertino.dart';
import 'package:jolt_setup/jolt_setup.dart';

import 'listenable.dart';

TransformationController useTransformationController([Matrix4? value]) {
  return useChangeNotifier(
    () => TransformationController(value),
  );
}

WidgetStatesController useWidgetStatesController([Set<WidgetState>? value]) {
  return useChangeNotifier(() => WidgetStatesController(value));
}

ExpansibleController useExpansibleController() {
  return useChangeNotifier(() => ExpansibleController());
}

TreeSliverController useTreeSliverController() {
  return useMemoized(() => TreeSliverController());
}

OverlayPortalController useOverlayPortalController({String? debugLabel}) {
  return useMemoized(() => OverlayPortalController(debugLabel: debugLabel));
}

SnapshotController useSnapshotController({bool allowSnapshotting = false}) {
  return useChangeNotifier(
      () => SnapshotController(allowSnapshotting: allowSnapshotting));
}

CupertinoTabController useCupertinoTabController({int initialIndex = 0}) {
  return useChangeNotifier(
      () => CupertinoTabController(initialIndex: initialIndex));
}

ContextMenuController useContextMenuController({VoidCallback? onRemove}) {
  return useMemoized(() => ContextMenuController(onRemove: onRemove));
}

MenuController useMenuController() {
  return useMemoized(() => MenuController());
}

MagnifierController useMagnifierController(
    {AnimationController? animationController}) {
  return useMemoized(
      () => MagnifierController(animationController: animationController));
}
