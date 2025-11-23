import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

abstract final class JoltCode {
  /// Accessing instance members via this
  static const setupThisExplicit = LintCode(
    'no_setup_this_explicit',

    'Accessing instance fields or methods via this is not allowed in setup.',
    correctionMessage:
        'Avoid directly using this to access instance members in setup.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Implicit access to instance members (bare identifier like 'a' or 'a()')
  static const setupThisImplicit = LintCode(
    'no_setup_this_implicit',

    'Implicit access to instance fields or methods is not allowed in setup.',
    correctionMessage:
        'Do not directly use instance field/method names in setup. Consider passing them as parameters or through other objects.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Assigning this to a variable (creating an alias)
  static const setupThisAssign = LintCode(
    'no_setup_this_assign',
    'Assigning this to a variable is not allowed in setup.',
    correctionMessage:
        'Avoid creating alias variables for this in setup, such as `that = this`.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const setupThisAssignable = LintCode(
    'no_setup_this_assignable',
    'Assigning this to a setter is not allowed in setup.',
    correctionMessage: 'Avoid assigning this to a variable in setup.',
    severity: DiagnosticSeverity.ERROR,
  );
}

abstract final class JoltFix {
  static const setupThisMulti = FixKind(
    'jolt.fix.setupThis.multi',
    DartFixKindPriority.standard + 10,
    "Fix all setup this issues",
  );
  static const setupThisImplicit = FixKind(
    'jolt.fix.setupThis.implicit',
    DartFixKindPriority.standard + 1,
    "Add props() to the member",
  );
  static const setupThisAssign = FixKind(
    'jolt.fix.setupThis.assign',
    DartFixKindPriority.standard + 1,
    "Replace this with props()",
  );
  static const setupThisAssignable = FixKind(
    'jolt.fix.setupThis.assignable',
    DartFixKindPriority.standard + 1,
    "Replace this with props()",
  );
  static const setupThisExplicit = FixKind(
    'jolt.fix.setupThis.explicit',
    DartFixKindPriority.standard + 1,
    "Replace this with props()",
  );
}

abstract final class JoltAssist {
  static const wrapJoltBuilder = AssistKind(
    'wrap_jolt_builder',
    100,
    'Wrap with JoltBuilder',
  );
  static const wrapJoltProvider = AssistKind(
    'wrap_jolt_provider',
    100,
    'Wrap with JoltProvider',
  );
  static const wrapJoltSelector = AssistKind(
    'wrap_jolt_selector',
    100,
    'Wrap with JoltSelector',
  );
  static const wrapSetupBuilder = AssistKind(
    'wrap_setup_builder',
    100,
    'Wrap with SetupBuilder',
  );
  static const wrapSurgeBuilder = AssistKind(
    'wrap_surge_builder',
    100,
    'Wrap with SurgeBuilder',
  );
  static const wrapSurgeProvider = AssistKind(
    'wrap_surge_provider',
    100,
    'Wrap with SurgeProvider',
  );
  static const wrapSurgeSelector = AssistKind(
    'wrap_surge_selector',
    100,
    'Wrap with SurgeSelector',
  );
  static const wrapSurgeListener = AssistKind(
    'wrap_surge_listener',
    100,
    'Wrap with SurgeListener',
  );
  static const wrapSurgeConsumer = AssistKind(
    'wrap_surge_consumer',
    100,
    'Wrap with SurgeConsumer',
  );
  static const convertStatelessWidgetToSetup = AssistKind(
    'convert_statelessWidget_to_setup',
    100,
    'Convert StatelessWidget to Setup',
  );
  static const convertToSignal = AssistKind(
    'convert_to_signal',
    100,
    'Convert to Signal',
  );
  static const convertFromSignal = AssistKind(
    'convert_from_signal',
    100,
    'Convert from Signal',
  );
}

Expression getTargetExpression(dynamic node) {
  return node.target ?? node.realTarget;
}

bool isSubtypeOfSetupWidget(ClassElement clazz) {
  if (clazz.supertype == null) return false;
  final superClassElement = clazz.supertype!.element;
  final superClassIdentifier = superClassElement.library.identifier;
  if (superClassIdentifier != joltSetupWidgetSrcUri) {
    return false;
  }
  return superClassElement.displayName == 'SetupWidget';
}

bool isSubtypeOfWidget(Element? clazz) {
  if (clazz == null || clazz is! InterfaceElement) return false;
  InterfaceElement? el = clazz;
  while (el != null) {
    if (el.library.identifier == flutterWidgetUri) {
      if (el.displayName.contains('Widget')) return true;
    }
    el = el.supertype?.element;
  }
  return false;
}

bool isSubtypeOfWidgetByType(DartType? type) {
  if (type == null) return false;
  if (type is InterfaceType) {
    final element = type.element;
    return isSubtypeOfWidget(element);
  }
  return false;
}

bool isAccessNode(AstNode n) =>
    n is PropertyAccess ||
    n is PrefixedIdentifier ||
    n is InvocationExpression ||
    n is IndexExpression ||
    n is InstanceCreationExpression;

Expression findLongestQualifiedExpression(AstNode node) {
  AstNode? current = node;
  Expression? result;

  while (current != null) {
    if (isAccessNode(current)) {
      result = current as Expression;
    } else if (current is SimpleIdentifier) {
      final parent = current.parent;
      if (parent is PropertyAccess && parent.propertyName == current) {
        result = parent;
      } else if (parent is PrefixedIdentifier && parent.identifier == current) {
        result = parent;
      } else if (parent is IndexExpression && parent.index == current) {
        result = parent;
      } else if (parent is InstanceCreationExpression) {
        result = parent;
      } else {
        result ??= current;
      }
    } else {
      break;
    }

    current = current.parent;
  }

  return result ?? (node as Expression);
}

bool isChainNode(AstNode n) =>
    n is PropertyAccess ||
    n is PrefixedIdentifier ||
    n is IndexExpression ||
    n is InvocationExpression ||
    n is InstanceCreationExpression ||
    n is ParenthesizedExpression;

Expression? findFullChainExpression(AstNode node) {
  AstNode? current = node;
  Expression? result;

  if (node is InstanceCreationExpression ||
      node is FunctionExpressionInvocation) {
    return null;
  }

  if (node.thisOrAncestorOfType<CascadeExpression>() != null) {
    return node as Expression;
  }

  if (isChainNode(current)) {
    result = current as Expression;
  }

  while (current != null) {
    final parent = current.parent;
    if (parent == null) break;

    // Upper level of the chain
    if (isChainNode(parent)) {
      result = parent as Expression;
      current = parent;
      continue;
    }

    // SimpleIdentifier is wrapped inside a chain node
    if (current is SimpleIdentifier) {
      // a.b structure
      if (parent is PropertyAccess && parent.propertyName == current) {
        result = parent;
        current = parent;
        continue;
      }

      // prefix.identifier structure
      if (parent is PrefixedIdentifier && parent.identifier == current) {
        result = parent;
        current = parent;
        continue;
      }

      // SimpleIdentifier for constructor name
      if (parent is ConstructorName) {
        final ic = parent.parent;
        if (ic is InstanceCreationExpression) {
          result = ic;
          current = ic;
          continue;
        }
      }

      // SimpleIdentifier is the target of obj.method
      if (parent is MethodInvocation && parent.methodName == current) {
        result = parent;
        current = parent;
        continue;
      }
    }

    break;
  }

  return result;
}

MethodDeclaration? getAncestorSetupMethod(AstNode node) =>
    node.thisOrAncestorMatching(
      (node) => node is MethodDeclaration && node.name.lexeme == 'setup',
    );

String ensureSetupPropsName(AstNode node, DartFileEditBuilder builder) {
  final setupMethod = getAncestorSetupMethod(node)!;

  final propsParamName = setupMethod.parameters!.parameters[1].name!;
  var propsName = propsParamName.lexeme;

  if (propsName == '_') {
    builder.addSimpleReplacement(
      SourceRange(propsParamName.offset, propsParamName.length),
      'props',
    );
    propsName = 'props';
  }

  return propsName;
}

const flutterWidgetUri = 'package:flutter/src/widgets/framework.dart';
const joltSetupWidgetSrcUri = 'package:jolt_flutter/src/setup/widget.dart';
const joltFlutterSetupUri = 'package:jolt_flutter/setup.dart';
const joltFlutterUri = 'package:jolt_flutter/jolt_flutter.dart';
const joltSurgeUri = 'package:jolt_surge/jolt_surge.dart';
const joltUri = 'package:jolt/jolt.dart';
