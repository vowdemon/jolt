import 'package:flutter/material.dart';

import 'animation.dart';
import 'listenable.dart';

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
  return useChangeNotifier(() => ScrollController(
        initialScrollOffset: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        debugLabel: debugLabel,
        onAttach: onAttach,
        onDetach: onDetach,
      ));
}

TrackingScrollController useTrackingScrollController({
  double initialScrollOffset = 0.0,
  bool keepScrollOffset = true,
  String? debugLabel,
  ScrollControllerCallback? onAttach,
  ScrollControllerCallback? onDetach,
}) {
  return useChangeNotifier(() => TrackingScrollController(
        initialScrollOffset: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        debugLabel: debugLabel,
        onAttach: onAttach,
        onDetach: onDetach,
      ));
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
  return useChangeNotifier(
    () => TabController(
      length: length,
      initialIndex: initialIndex,
      vsync: vsync ?? useSingleTickerProvider(),
      animationDuration: animationDuration,
    ),
  );
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
  return useChangeNotifier(
    () => PageController(
      initialPage: initialPage,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
      onAttach: onAttach,
      onDetach: onDetach,
    ),
  );
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
  return useChangeNotifier(
    () => FixedExtentScrollController(
      initialItem: initialItem,
      onAttach: onAttach,
      onDetach: onDetach,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    ),
  );
}

DraggableScrollableController useDraggableScrollableController() {
  return useChangeNotifier(() => DraggableScrollableController());
}

CarouselController useCarouselController({int initialItem = 0}) {
  return useChangeNotifier(() => CarouselController(initialItem: initialItem));
}
