import 'package:flutter/material.dart';

import 'animation.dart';
import 'annotation.dart';
import 'listenable.dart';

/// Creates a [ScrollController] for the current setup scope.
///
/// The controller is disposed automatically when the setup unmounts.
///
/// ```dart
/// setup(context, props) {
///   final controller = useScrollController();
///
///   return () => ListView(controller: controller);
/// }
/// ```
@defineHook
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

/// Creates a [TrackingScrollController] for the current setup scope.
///
/// Use this when multiple scrollables should share the last observed scroll
/// offset.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTrackingScrollController();
///
///   return () => CustomScrollView(controller: controller);
/// }
/// ```
@defineHook
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

/// Creates a [TabController] for the current setup scope.
///
/// The [length] must match the number of tabs. If [vsync] is omitted, this
/// hook creates one with [useSingleTickerProvider].
///
/// ```dart
/// setup(context, props) {
///   final controller = useTabController(length: 3);
///
///   return () => Column(
///     children: [
///       TabBar(controller: controller, tabs: const [
///         Tab(text: 'A'),
///         Tab(text: 'B'),
///         Tab(text: 'C'),
///       ]),
///       Expanded(
///         child: TabBarView(
///           controller: controller,
///           children: const [Text('A'), Text('B'), Text('C')],
///         ),
///       ),
///     ],
///   );
/// }
/// ```
@defineHook
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

/// Creates a [PageController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = usePageController();
///
///   return () => PageView(
///     controller: controller,
///     children: const [Text('A'), Text('B')],
///   );
/// }
/// ```
@defineHook
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

/// Creates a [FixedExtentScrollController] for a wheel-style scroll view.
///
/// ```dart
/// setup(context, props) {
///   final controller = useFixedExtentScrollController(initialItem: 2);
///
///   return () => ListWheelScrollView.useDelegate(
///     controller: controller,
///     itemExtent: 40,
///     childDelegate: ListWheelChildListDelegate(
///       children: const [Text('A'), Text('B'), Text('C')],
///     ),
///   );
/// }
/// ```
@defineHook
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

/// Creates a [DraggableScrollableController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useDraggableScrollableController();
///
///   return () => DraggableScrollableSheet(
///     controller: controller,
///     builder: (context, scrollController) {
///       return ListView(controller: scrollController);
///     },
///   );
/// }
/// ```
@defineHook
DraggableScrollableController useDraggableScrollableController() {
  return useChangeNotifier(() => DraggableScrollableController());
}

/// Creates a [CarouselController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useCarouselController();
///   return () => CarouselView(controller: controller);
/// }
/// ```
@defineHook
CarouselController useCarouselController({int initialItem = 0}) {
  return useChangeNotifier(() => CarouselController(initialItem: initialItem));
}
