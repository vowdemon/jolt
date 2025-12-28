import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/analysis/results.dart';
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

  /// Mutating a mutable collection signal's value
  static const mutableCollectionValueOperation = LintCode(
    'no_mutable_collection_value_operation',
    'Mutating operations on mutable collection signal\'s value are dangerous.',
    correctionMessage:
        'Avoid mutating the collection returned by .value. Use the signal\'s mutation methods directly or update the entire value.',
    severity: DiagnosticSeverity.WARNING,
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
  static const convertStatelessWidgetToSetupWidget = AssistKind(
    'convert_statelessWidget_to_setupWidget',
    100,
    'Convert StatelessWidget to SetupWidget',
  );
  static const convertSetupWidgetToStateless = AssistKind(
    'convert_setupWidget_to_stateless',
    100,
    'Convert SetupWidget to StatelessWidget',
  );
  static const convertStatefulToSetupMixin = AssistKind(
    'convert_stateful_to_setupMixin',
    100,
    'Convert StatefulWidget to SetupMixin',
  );
  static const convertStatefulFromSetupMixin = AssistKind(
    'convert_stateful_from_setupMixin',
    100,
    'Convert SetupMixin to StatefulWidget',
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
  return isSubtypeOfUri(clazz, joltSetupWidgetSrcUri, 'SetupWidget');
}

bool isSubtypeOfState(ClassElement clazz) {
  return isSubtypeOfUri(clazz, flutterWidgetUri, 'State');
}

bool isSubtypeOfStatelessWidget(ClassElement clazz) {
  return isSubtypeOfUri(clazz, flutterWidgetUri, 'StatelessWidget');
}

bool isSubtypeOfStatefulWidget(ClassElement clazz) {
  return isSubtypeOfUri(clazz, flutterWidgetUri, 'StatefulWidget');
}

bool isSubtypeOfUri(ClassElement clazz, String identifier, String displayName) {
  if (clazz.supertype == null) return false;
  final superClassElement = clazz.supertype!.element;
  final superClassIdentifier = superClassElement.library.identifier;
  if (superClassIdentifier != identifier) {
    return false;
  }
  return superClassElement.displayName == displayName;
}

bool isWithMixinByUri(
  ClassElement clazz,
  String identifier,
  String displayName,
) {
  final mixins = clazz.mixins;
  if (mixins.isEmpty) return false;
  for (final mixin in mixins) {
    final mixinElement = mixin.element;
    final mixinIdentifier = mixinElement.library.identifier;
    if (mixinIdentifier != identifier) {
      return false;
    }
    return mixinElement.displayName == displayName;
  }
  return false;
}

bool isWithSetupMixin(ClassElement clazz) {
  return isWithMixinByUri(clazz, joltSetupWidgetSrcUri, 'SetupMixin');
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

({ReturnStatement? returnStatement, Expression? returnExpression})?
getReturnExpression(FunctionBody body) {
  if (body is BlockFunctionBody) {
    final returnStatement = body.block.statements
        .whereType<ReturnStatement>()
        .firstOrNull;
    return (
      returnStatement: returnStatement,
      returnExpression: returnStatement?.expression,
    );
  }
  if (body is ExpressionFunctionBody) {
    return (returnStatement: null, returnExpression: body.expression);
  }
  return (returnStatement: null, returnExpression: null);
}

MethodDeclaration? getMethodDeclarationByNameAndParametersCount(
  ClassDeclaration clazz, {
  required String name,
  int? parametersCount,
  bool? isAsync,
}) {
  for (final member in clazz.members) {
    if (member is MethodDeclaration) {
      if (member.name.lexeme == name) {
        if (parametersCount != null &&
            member.parameters?.parameters.length != parametersCount) {
          break;
        }
        if (isAsync != null) {
          if (isAsync && member.body.isSynchronous) {
            break;
          } else if (!isAsync && member.body.isAsynchronous) {
            break;
          }
        }
        return member;
      }
    }
  }
  return null;
}

void removeMixinClass(
  DartFileEditBuilder builder,
  ClassDeclaration clazz,
  String mixinName,
) {
  final withClause = clazz.withClause;
  if (withClause == null) return;

  final mixinTypes = withClause.mixinTypes;
  if (mixinTypes.isEmpty) return;

  // Find the SetupMixin in the mixin list
  NamedType? setupMixinType;
  for (final mixinType in mixinTypes) {
    final typeName = mixinType.name.lexeme;
    if (typeName == mixinName) {
      setupMixinType = mixinType;
      break;
    }
  }

  if (setupMixinType == null) return;

  // If there's only one mixin, remove the entire with clause
  if (mixinTypes.length == 1) {
    // Remove " with SetupMixin<...>"
    final extendsClause = clazz.extendsClause;
    if (extendsClause != null) {
      // Remove from extendsClause.end to withClause.end
      builder.addSimpleReplacement(
        SourceRange(
          extendsClause.end,
          (withClause.end - extendsClause.end).toInt(),
        ),
        '',
      );
    } else {
      // If no extends, remove the entire with clause
      builder.addSimpleReplacement(
        SourceRange(withClause.offset, withClause.length),
        '',
      );
    }
  } else {
    // Multiple mixins, remove only SetupMixin
    final mixinIndex = mixinTypes.indexOf(setupMixinType);
    if (mixinIndex == 0) {
      // First mixin: remove "SetupMixin<...>, "
      final nextMixin = mixinTypes[1];
      builder.addSimpleReplacement(
        SourceRange(
          setupMixinType.offset,
          (nextMixin.offset - setupMixinType.offset).toInt(),
        ),
        '',
      );
    } else {
      // Not first mixin: remove ", SetupMixin<...>"
      final prevMixin = mixinTypes[mixinIndex - 1];
      builder.addSimpleReplacement(
        SourceRange(
          prevMixin.end,
          (setupMixinType.end - prevMixin.end).toInt(),
        ),
        '',
      );
    }
  }
}

({
  ClassDeclaration stateClassDeclaration,
  ClassDeclaration widgetClassDeclaration,
})?
getStatefullDeclaration(AstNode node, CompilationUnit unit) {
  if (node is! ClassDeclaration) return null;

  final clazzDeclaration = node;
  final clazz = clazzDeclaration.declaredFragment?.element;
  if (clazz == null) return null;

  ClassDeclaration? stateClassDeclaration;
  ClassDeclaration? widgetClssDeclaration;
  if (isSubtypeOfStatefulWidget(clazz)) {
    widgetClssDeclaration = clazzDeclaration;
    final stateClassName = getStateClassName(clazzDeclaration);
    if (stateClassName != null) {
      stateClassDeclaration = getClassDeclarationByClassName(
        unit,
        stateClassName,
      );
    }
  } else if (isSubtypeOfState(clazz)) {
    widgetClssDeclaration = getWidgetClassDeclarationFromStateClass(
      unit,
      clazzDeclaration,
    );
    stateClassDeclaration = clazzDeclaration;
  } else {
    return null;
  }

  if (stateClassDeclaration == null || widgetClssDeclaration == null) {
    return null;
  }

  return (
    stateClassDeclaration: stateClassDeclaration,
    widgetClassDeclaration: widgetClssDeclaration,
  );
}

String? getStateClassName(ClassDeclaration clazz) {
  final members = clazz.members;
  final createStateMethod =
      members
              .where(
                (member) =>
                    member is MethodDeclaration &&
                    member.name.lexeme == 'createState',
              )
              .firstOrNull
          as MethodDeclaration?;
  if (createStateMethod != null) {
    final returnType = getReturnExpression(
      createStateMethod.body,
    )?.returnExpression?.staticType;
    if (returnType != null && returnType.element != null) {
      return returnType.element!.displayName;
    }
  }
  return null;
}

ClassDeclaration? getClassDeclarationByClassName(
  CompilationUnit unit,
  String className,
) {
  return unit.declarations
          .where(
            (declaration) =>
                declaration is ClassDeclaration &&
                declaration.name.lexeme == className,
          )
          .firstOrNull
      as ClassDeclaration?;
}

ClassDeclaration? getWidgetClassDeclarationFromStateClass(
  CompilationUnit unit,
  ClassDeclaration stateClass,
) {
  final superClass = stateClass.extendsClause?.superclass;
  if (superClass == null) return null;

  final typeArg = superClass.typeArguments?.arguments.firstOrNull;
  if (typeArg == null) return null;

  final typeArgClassName = typeArg.type?.element?.displayName;
  if (typeArgClassName == null) return null;
  return getClassDeclarationByClassName(unit, typeArgClassName);
}

void addMixinClass(
  DartFileEditBuilder builder,
  ClassDeclaration clazz,
  String mixinClass,
) {
  final hasWithClause = clazz.withClause != null;
  if (hasWithClause) {
    builder.addSimpleInsertion(clazz.withClause!.end, ', $mixinClass');
  } else {
    if (clazz.implementsClause != null) {
      builder.addSimpleInsertion(
        clazz.implementsClause!.offset,
        'with $mixinClass ',
      );
    } else {
      builder.addSimpleInsertion(clazz.extendsClause!.end, ' with $mixinClass');
    }
  }
}

void importSetup(DartFileEditBuilder builder) {
  builder.importLibrary(Uri.parse(joltFlutterSetupUri));
}

void addIndentToLines(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder, {
  required int startOffset,
  required int endOffset,
  required int indent,
}) {
  final startLine = unitResult.lineInfo.getLocation(startOffset);
  final endLine = unitResult.lineInfo.getLocation(endOffset);

  if (indent > 0) {
    // Add indentation
    for (var i = startLine.lineNumber; i < endLine.lineNumber; i++) {
      builder.addInsertion(unitResult.lineInfo.getOffsetOfLine(i), (edit) {
        edit.writeIndent(indent);
      });
    }
  } else if (indent < 0) {
    // Remove indentation (one level = 2 spaces typically)
    final indentToRemove = -indent * 2;
    for (var i = startLine.lineNumber; i < endLine.lineNumber; i++) {
      final lineOffset = unitResult.lineInfo.getOffsetOfLine(i);
      final nextLineOffset = i + 1 < unitResult.lineInfo.lineCount
          ? unitResult.lineInfo.getOffsetOfLine(i + 1)
          : unitResult.content.length;
      final lineContent = unitResult.content.substring(
        lineOffset,
        nextLineOffset,
      );

      // Find leading whitespace
      final leadingWhitespaceMatch = RegExp(r'^\s*').matchAsPrefix(lineContent);
      if (leadingWhitespaceMatch != null && leadingWhitespaceMatch.end > 0) {
        final toRemove = leadingWhitespaceMatch.end > indentToRemove
            ? indentToRemove
            : leadingWhitespaceMatch.end;
        if (toRemove > 0) {
          builder.addSimpleReplacement(SourceRange(lineOffset, toRemove), '');
        }
      }
    }
  }
}

const flutterWidgetUri = 'package:flutter/src/widgets/framework.dart';
const joltSetupWidgetSrcUri = 'package:jolt_setup/src/setup/framework.dart';
const joltFlutterSetupUri = 'package:jolt_setup/jolt_setup.dart';
const joltFlutterUri = 'package:jolt_flutter/jolt_flutter.dart';
const joltSurgeUri = 'package:jolt_surge/jolt_surge.dart';
const joltUri = 'package:jolt/jolt.dart';
const joltCoreUri = 'package:jolt/core.dart';
