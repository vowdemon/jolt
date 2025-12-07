import 'package:flutter/material.dart';

import 'listenable.dart';

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
  TextEditingController call({String? text}) {
    return useChangeNotifier(
      () => TextEditingController(text: text),
    );
  }

  /// Creates a text editing controller from TextEditingValue
  ///
  /// [value] Initial TextEditingValue
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
  RestorableTextEditingController call({String? text}) {
    return useChangeNotifier(
      () => RestorableTextEditingController(text: text),
    );
  }

  /// Creates a text editing controller from TextEditingValue
  ///
  /// [value] Initial TextEditingValue
  RestorableTextEditingController fromValue(TextEditingValue value) {
    return useChangeNotifier(
      () => RestorableTextEditingController.fromValue(value),
    );
  }
}

const useRestorableTextEditingController =
    _RestorableTextEditingControllerCreator._();

SearchController useSearchController() {
  return useChangeNotifier(() => SearchController());
}

UndoHistoryController useUndoHistoryController({UndoHistoryValue? value}) {
  return useChangeNotifier(() => UndoHistoryController(value: value));
}
