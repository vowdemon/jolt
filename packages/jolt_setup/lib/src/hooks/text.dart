import 'package:flutter/material.dart';
import 'package:jolt_setup/hooks.dart';


/// Creates a text editing controller
///
/// The controller will be automatically disposed when the component is unmounted
///
/// Usage example:
/// ```dart
/// final controller = useTextEditingController('Initial text');
/// final controller2 = useTextEditingController.fromValue(
///   TextEditingValue(text: 'Initial text'),
/// );
/// ```
final class _TextEditingControllerCreator {
  const _TextEditingControllerCreator._();

  /// Creates a text editing controller
  ///
  /// [text] Initial text content
  @defineHook
  TextEditingController call({String? text}) {
    return useChangeNotifier(
      () => TextEditingController(text: text),
    );
  }

  /// Creates a text editing controller from TextEditingValue
  ///
  /// [value] Initial TextEditingValue
  @defineHook
  TextEditingController fromValue(TextEditingValue? value) {
    return useChangeNotifier(
      () => TextEditingController.fromValue(value),
    );
  }
}

const useTextEditingController = _TextEditingControllerCreator._();

/// Creates a text editing controller
///
/// The controller will be automatically disposed when the component is unmounted
///
/// Usage example:
/// ```dart
/// final controller = useTextEditingController('Initial text');
/// final controller2 = useTextEditingController.fromValue(
///   TextEditingValue(text: 'Initial text'),
/// );
/// ```
final class _RestorableTextEditingControllerCreator {
  const _RestorableTextEditingControllerCreator._();

  /// Creates a text editing controller
  ///
  /// [text] Initial text content
  @defineHook
  RestorableTextEditingController call({String? text}) {
    return useChangeNotifier(
      () => RestorableTextEditingController(text: text),
    );
  }

  /// Creates a text editing controller from TextEditingValue
  ///
  /// [value] Initial TextEditingValue
  @defineHook
  RestorableTextEditingController fromValue(TextEditingValue value) {
    return useChangeNotifier(
      () => RestorableTextEditingController.fromValue(value),
    );
  }
}

const useRestorableTextEditingController =
    _RestorableTextEditingControllerCreator._();

@defineHook
SearchController useSearchController() {
  return useChangeNotifier(() => SearchController());
}

@defineHook
UndoHistoryController useUndoHistoryController({UndoHistoryValue? value}) {
  return useChangeNotifier(() => UndoHistoryController(value: value));
}
