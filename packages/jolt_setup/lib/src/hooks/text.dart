import 'package:flutter/material.dart';

import 'annotation.dart';
import 'listenable.dart';

/// Text-editing controller hook factory methods.
final class JoltSetupHookTextEditingControllerCreator {
  const JoltSetupHookTextEditingControllerCreator._();

  /// Creates a [TextEditingController] initialized with [text].
  @defineHook
  TextEditingController call({String? text}) {
    return useChangeNotifier(
      () => TextEditingController(text: text),
    );
  }

  /// Creates a [TextEditingController] initialized from [value].
  @defineHook
  TextEditingController fromValue(TextEditingValue? value) {
    return useChangeNotifier(
      () => TextEditingController.fromValue(value),
    );
  }
}

/// Creates a [TextEditingController] for the current setup scope.
///
/// Use `useTextEditingController.fromValue(...)` when selection or composing
/// state should be initialized together with the text.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTextEditingController(text: 'hello');
///
///   return () => TextField(controller: controller);
/// }
/// ```
const useTextEditingController = JoltSetupHookTextEditingControllerCreator._();

/// Restorable text-editing controller hook factory methods.
final class JoltSetupHookRestorableTextEditingControllerCreator {
  const JoltSetupHookRestorableTextEditingControllerCreator._();

  /// Creates a [RestorableTextEditingController] initialized with [text].
  @defineHook
  RestorableTextEditingController call({String? text}) {
    return useChangeNotifier(
      () => RestorableTextEditingController(text: text),
    );
  }

  /// Creates a [RestorableTextEditingController] initialized from [value].
  @defineHook
  RestorableTextEditingController fromValue(TextEditingValue value) {
    return useChangeNotifier(
      () => RestorableTextEditingController.fromValue(value),
    );
  }
}

/// Creates a [RestorableTextEditingController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller =
///       useRestorableTextEditingController(text: 'draft');
///
///   return () => TextField(controller: controller.value);
/// }
/// ```
const useRestorableTextEditingController =
    JoltSetupHookRestorableTextEditingControllerCreator._();

/// Creates a [SearchController] for the current setup scope.
///
/// ```dart
/// setup(context, props) {
///   final controller = useSearchController();
///
///   return () => SearchBar(controller: controller);
/// }
/// ```
@defineHook
SearchController useSearchController() {
  return useChangeNotifier(() => SearchController());
}

/// Creates an [UndoHistoryController] for the current setup scope.
///
/// Use this when an editable widget should coordinate undo and redo state with
/// other setup-scoped resources.
///
/// ```dart
/// setup(context, props) {
///   final controller = useUndoHistoryController();
///
///   return () => TextField(
///     undoController: controller,
///   );
/// }
/// ```
@defineHook
UndoHistoryController useUndoHistoryController({UndoHistoryValue? value}) {
  return useChangeNotifier(() => UndoHistoryController(value: value));
}
