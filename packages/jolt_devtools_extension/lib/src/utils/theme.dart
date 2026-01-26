import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

/// Theme configuration for VM value display.
abstract final class AppTheme {
  /// TextStyle for string values.
  static const stringStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF6A8759), // Green for strings
  );

  /// TextStyle for numeric values (int, double).
  static const numberStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF6897BB), // Blue for numbers
  );

  /// TextStyle for boolean values.
  static const boolStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFCC7832), // Orange for booleans
    fontWeight: FontWeight.w500,
  );

  /// TextStyle for null values.
  static const nullStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF808080), // Gray for null
    // fontStyle: FontStyle.italic,
  );

  /// TextStyle for collection names (List, Set, Map, etc.).
  static const collectionStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9876AA), // Purple for collections
    fontWeight: FontWeight.w500,
  );

  /// TextStyle for function/closure values.
  static const functionStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFB5B5B5), // Light gray for functions
    fontStyle: FontStyle.italic,
  );

  /// TextStyle for getter values.
  static const getterStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFA9B7C6), // Light blue for getters
  );

  /// Default TextStyle for other values.
  static const defaultStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFA9B7C6), // Default text color
  );

  /// Gets the appropriate TextStyle for a VmValueNode based on its type.
  static TextStyle getStyleForNode({
    required String? kind,
    required String? type,
    required String label,
    required String display,
    bool isGetter = false,
  }) {
    // Note: getter style is applied to "get " prefix in widgets, not here

    // Check for function/closure
    if (kind == InstanceKind.kClosure) {
      return functionStyle;
    }

    // Check for null
    if (kind == InstanceKind.kNull || display == 'null') {
      return nullStyle;
    }

    // Check for boolean
    if (kind == InstanceKind.kBool || display == 'true' || display == 'false') {
      return boolStyle;
    }

    // Check for numbers
    if (kind == InstanceKind.kInt || kind == InstanceKind.kDouble) {
      return numberStyle;
    }

    // Check for strings
    if (kind == InstanceKind.kString ||
        (display.startsWith('"') && display.endsWith('"'))) {
      return stringStyle;
    }

    // Check for collections
    if (kind == InstanceKind.kList ||
        kind == InstanceKind.kSet ||
        kind == InstanceKind.kMap ||
        kind == InstanceKind.kRecord) {
      return collectionStyle;
    }

    // Default style
    return defaultStyle;
  }
}
