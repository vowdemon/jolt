import 'package:flutter/cupertino.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';


@defineHook
TransformationController useTransformationController([Matrix4? value]) {
  return useChangeNotifier(
    () => TransformationController(value),
  );
}

@defineHook
WidgetStatesController useWidgetStatesController([Set<WidgetState>? value]) {
  return useChangeNotifier(() => WidgetStatesController(value));
}

@defineHook
ExpansibleController useExpansibleController() {
  return useChangeNotifier(() => ExpansibleController());
}

@defineHook
TreeSliverController useTreeSliverController() {
  return useMemoized(() => TreeSliverController());
}

@defineHook
OverlayPortalController useOverlayPortalController({String? debugLabel}) {
  return useMemoized(() => OverlayPortalController(debugLabel: debugLabel));
}

@defineHook
SnapshotController useSnapshotController({bool allowSnapshotting = false}) {
  return useChangeNotifier(
      () => SnapshotController(allowSnapshotting: allowSnapshotting));
}

@defineHook
CupertinoTabController useCupertinoTabController({int initialIndex = 0}) {
  return useChangeNotifier(
      () => CupertinoTabController(initialIndex: initialIndex));
}

@defineHook
ContextMenuController useContextMenuController({VoidCallback? onRemove}) {
  return useMemoized(() => ContextMenuController(onRemove: onRemove));
}

@defineHook
MenuController useMenuController() {
  return useMemoized(() => MenuController());
}

@defineHook
MagnifierController useMagnifierController(
    {AnimationController? animationController}) {
  return useMemoized(
      () => MagnifierController(animationController: animationController));
}
