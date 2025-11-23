import 'package:flutter/material.dart';

import 'package:jolt_flutter/setup.dart';
import 'animation.dart';

/// Creates a scroll controller
///
/// The controller will be automatically disposed when the component is unmounted
ScrollController useScrollController({
  double initialScrollOffset = 0.0,
  bool keepScrollOffset = true,
  String? debugLabel,
  ScrollControllerCallback? onAttach,
  ScrollControllerCallback? onDetach,
}) {
  final controller = useMemoized(
      () => ScrollController(
            initialScrollOffset: initialScrollOffset,
            keepScrollOffset: keepScrollOffset,
            debugLabel: debugLabel,
            onAttach: onAttach,
            onDetach: onDetach,
          ),
      (controller) => controller.dispose);

  return controller;
}

/// Creates a Tab controller
///
/// The controller will be automatically disposed when the component is unmounted
///
/// [length] Number of tabs (required)
/// [initialIndex] Initial selected tab index
TabController useTabController({
  required int length,
  int initialIndex = 0,
  TickerProvider? vsync,
  Duration? animationDuration,
}) {
  final controller = useMemoized(
      () => TabController(
            length: length,
            initialIndex: initialIndex,
            vsync: vsync ?? useSingleTickerProvider(),
            animationDuration: animationDuration,
          ),
      (controller) => controller.dispose);

  return controller;
}

/// Creates a Page controller
///
/// The controller will be automatically disposed when the component is unmounted
PageController usePageController(
    {int initialPage = 0,
    bool keepPage = true,
    double viewportFraction = 1.0,
    void Function(ScrollPosition)? onAttach,
    void Function(ScrollPosition)? onDetach}) {
  final controller = useMemoized(
      () => PageController(
            initialPage: initialPage,
            keepPage: keepPage,
            viewportFraction: viewportFraction,
            onAttach: onAttach,
            onDetach: onDetach,
          ),
      (controller) => controller.dispose);

  return controller;
}

/// Creates a fixed extent scroll controller
///
/// The controller will be automatically disposed when the component is unmounted
FixedExtentScrollController useFixedExtentScrollController({
  int initialItem = 0,
  void Function(ScrollPosition)? onAttach,
  void Function(ScrollPosition)? onDetach,
  bool keepScrollOffset = true,
  String? debugLabel,
}) {
  final controller = useMemoized(
      () => FixedExtentScrollController(
            initialItem: initialItem,
            onAttach: onAttach,
            onDetach: onDetach,
            keepScrollOffset: keepScrollOffset,
            debugLabel: debugLabel,
          ),
      (controller) => controller.dispose);

  return controller;
}
