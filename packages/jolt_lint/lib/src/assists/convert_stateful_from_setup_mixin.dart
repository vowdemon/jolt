import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/remove_props_mixin_replacer_visitor.dart';

class ConvertStatefulFromSetupMixinAssist extends ResolvedCorrectionProducer {
  ConvertStatefulFromSetupMixinAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertStatefulFromSetupMixin;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final statefullDeclaration = getStatefullDeclaration(node, unit);
    if (statefullDeclaration == null) return;
    final stateClassDeclaration = statefullDeclaration.stateClassDeclaration;
    final widgetClassDeclaration = statefullDeclaration.widgetClassDeclaration;

    if (stateClassDeclaration.declaredFragment == null ||
        !isWithSetupMixin(stateClassDeclaration.declaredFragment!.element)) {
      return;
    }

    // Find the setup method
    final setupMethod = getMethodDeclarationByNameAndParametersCount(
      stateClassDeclaration,
      name: 'setup',
      parametersCount: 1,
      isAsync: false,
    );
    if (setupMethod == null) return;

    // Get widget type for props replacement
    final widgetClass = widgetClassDeclaration.declaredFragment?.element;
    if (widgetClass == null) return;
    final widgetType = widgetClass.thisType;

    // Convert setup method to build method and remove SetupMixin
    await builder.addDartFileEdit(file, (builder) {
      // 1. Remove SetupMixin from the class
      removeMixinClass(builder, stateClassDeclaration, 'SetupMixin');

      // 2. Convert setup method to build method
      convertSetupToBuildInState(unitResult, builder, setupMethod, widgetType);
    });
  }
}

void convertSetupToBuildInState(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
  MethodDeclaration setupMethod,
  InterfaceType widgetType,
) {
  final methodName = setupMethod.name;

  // Add return type Widget before method name
  if (setupMethod.returnType != null) {
    builder.addSimpleReplacement(
      SourceRange(
        setupMethod.returnType!.offset,
        setupMethod.returnType!.length,
      ),
      'Widget',
    );
  } else {
    builder.addInsertion(methodName.offset, (edit) {
      edit.write('Widget ');
    });
  }

  // Replace method name from 'setup' to 'build'
  builder.addSimpleReplacement(
    SourceRange(methodName.offset, methodName.length),
    'build',
  );

  // Update method signature: setup(context) -> build(BuildContext context)
  final parameters = setupMethod.parameters;
  if (parameters != null) {
    builder.addReplacement(SourceRange(parameters.offset, parameters.length), (
      edit,
    ) {
      edit.write('(BuildContext context)');
    });
  }

  // Replace props.xxx with widget.xxx before unwrapping
  final body = setupMethod.body;
  if (body is BlockFunctionBody) {
    // Replace props() calls in the method body
    final visitor = RemovePropsMixinReplacerVisitor(widgetType);
    body.accept(visitor);

    RemovePropsMixinReplacerVisitor.applyReplacements(
      builder,
      visitor.toRemove,
      visitor.toReplaceWithWidget,
    );

    _unwrapSetupBodyFromBlock(unitResult, builder, body);
  } else if (body is ExpressionFunctionBody) {
    // Replace props() calls in expression body
    final visitor = RemovePropsMixinReplacerVisitor(widgetType);
    body.accept(visitor);

    RemovePropsMixinReplacerVisitor.applyReplacements(
      builder,
      visitor.toRemove,
      visitor.toReplaceWithWidget,
    );

    _unwrapSetupBodyFromExpression(unitResult, builder, body);
  }
}

void _unwrapSetupBodyFromBlock(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
  BlockFunctionBody body,
) {
  final block = body.block;
  final statements = block.statements;

  // Find the return statement
  ReturnStatement? returnStatement;
  for (final stmt in statements) {
    if (stmt is ReturnStatement) {
      returnStatement = stmt;
      break;
    }
  }

  if (returnStatement == null) return;

  final returnExpression = returnStatement.expression;
  if (returnExpression == null) return;

  // Check if it's a function expression: () => Widget or () { ... }
  if (returnExpression is FunctionExpression) {
    _unwrapFunctionExpressionFromReturn(
      returnExpression,
      returnStatement,
      builder,
      unitResult,
    );
  }
}

void _unwrapSetupBodyFromExpression(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
  ExpressionFunctionBody body,
) {
  final expression = body.expression;

  // If expression is FunctionExpression, unwrap it
  // setup(context) => () { return Text(...); }; -> build(context) { return Text(...); }
  // setup(context) => () => Text(...); -> build(context) => Text(...);
  if (expression is FunctionExpression) {
    final parameters = expression.parameters;
    final functionBody = expression.body;

    // Unwrap function body
    if (functionBody is BlockFunctionBody) {
      // setup(context) => () { ... } -> build(context) { ... }
      // Delete "=>" part: from body.offset to expression.offset
      if (expression.offset > body.offset) {
        builder.addSimpleReplacement(
          SourceRange(body.offset, expression.offset - body.offset),
          '',
        );
      }

      // Remove function parameters "()"
      if (parameters != null && functionBody.offset > parameters.offset) {
        builder.addSimpleReplacement(
          SourceRange(
            parameters.offset,
            functionBody.offset - parameters.offset,
          ),
          '',
        );
      }

      // Keep the block body, just reduce indentation
      // The braces stay, we just need to adjust indentation
      // Need to reduce 2 levels: one for () { ... } and one for => () { ... }
      final block = functionBody.block;

      // Reduce indentation of inner content (two levels less)
      addIndentToLines(
        unitResult,
        builder,
        startOffset: block.beginToken.offset,
        endOffset: block.endToken.offset,
        indent: -2,
      );

      // Remove semicolon from the original ExpressionFunctionBody
      _removeSemicolonAfterExpression(expression, body, unitResult, builder);
    } else if (functionBody is ExpressionFunctionBody) {
      // setup(context) => () => Widget -> build(context) => Widget;
      // Need to delete: "()" and inner "=>", but keep outer "=>" and semicolon
      final innerExpression = functionBody.expression;

      // Delete "() =>" part: from parameters.offset to innerExpression.offset
      // This will keep the outer "=>" from body
      if (parameters != null && innerExpression.offset > parameters.offset) {
        builder.addSimpleReplacement(
          SourceRange(
            parameters.offset,
            innerExpression.offset - parameters.offset,
          ),
          '',
        );
      }

      // Keep the semicolon from the original ExpressionFunctionBody
      // Do not call _removeSemicolonAfterExpression
    }
  }
}

/// Removes the semicolon after an expression if it exists
void _removeSemicolonAfterExpression(
  Expression expression,
  ExpressionFunctionBody body,
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
) {
  final contentAfterExpression = unitResult.content.substring(
    expression.end,
    body.end,
  );
  if (contentAfterExpression.trim().startsWith(';')) {
    final semicolonOffset =
        expression.end + contentAfterExpression.indexOf(';');
    builder.addSimpleReplacement(SourceRange(semicolonOffset, 1), '');
  }
}

void _unwrapFunctionExpressionFromReturn(
  FunctionExpression functionExpression,
  ReturnStatement returnStatement,
  DartFileEditBuilder builder,
  ParsedUnitResult unitResult,
) {
  final parameters = functionExpression.parameters;
  final functionBody = functionExpression.body;

  if (functionBody is ExpressionFunctionBody) {
    // return () => Widget -> return Widget
    final expression = functionBody.expression;
    // Delete "return" keyword and "() =>" part
    final returnKeyword = returnStatement.returnKeyword;
    if (expression.offset > returnKeyword.offset) {
      builder.addSimpleReplacement(
        SourceRange(
          returnKeyword.offset,
          expression.offset - returnKeyword.offset,
        ),
        'return ',
      );
    }
  } else if (functionBody is BlockFunctionBody) {
    // return () { ... } -> ... (remove return, (), {, }, and semicolon)
    final block = functionBody.block;

    // Delete "return" keyword and space before parameters
    final returnKeyword = returnStatement.returnKeyword;
    if (parameters != null && parameters.offset > returnKeyword.offset) {
      builder.addSimpleReplacement(
        SourceRange(
          returnKeyword.offset,
          parameters.offset - returnKeyword.offset,
        ),
        '',
      );
    }

    // Delete "()" part
    if (parameters != null && block.offset > parameters.offset) {
      builder.addSimpleReplacement(
        SourceRange(parameters.offset, block.offset - parameters.offset),
        '',
      );
    }

    // Delete "{" and "}" brackets
    builder.addSimpleReplacement(
      SourceRange(block.leftBracket.offset, block.leftBracket.length),
      '',
    );
    builder.addSimpleReplacement(
      SourceRange(block.rightBracket.offset, block.rightBracket.length),
      '',
    );

    // Delete semicolon
    final semicolon = returnStatement.semicolon;
    builder.addSimpleReplacement(
      SourceRange(semicolon.offset, semicolon.length),
      '',
    );

    // Reduce indentation of inner content
    addIndentToLines(
      unitResult,
      builder,
      startOffset: block.beginToken.offset,
      endOffset: block.endToken.offset,
      indent: -1,
    );
  }
}
