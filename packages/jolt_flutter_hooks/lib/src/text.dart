import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/setup.dart';

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
  const _TextEditingControllerCreator();

  /// Creates a text editing controller
  ///
  /// [text] Initial text content
  TextEditingController call([String? text]) {
    final controller = useMemoized(() => TextEditingController(text: text),
        (controller) => controller.dispose);

    return controller;
  }

  /// Creates a text editing controller from TextEditingValue
  ///
  /// [value] Initial TextEditingValue
  TextEditingController fromValue([TextEditingValue? value]) {
    final controller = useMemoized(() => TextEditingController.fromValue(value),
        (controller) => controller.dispose);

    return controller;
  }
}

const useTextEditingController = _TextEditingControllerCreator();
