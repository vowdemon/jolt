import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/remove_props_replacer_visitor.dart';

class ConvertStatelessWidgetFromSetupWidgetAssist
    extends ResolvedCorrectionProducer {
  ConvertStatelessWidgetFromSetupWidgetAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertSetupWidgetToStateless;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (node is! ClassDeclaration) return;

    final clazzDeclaration = node as ClassDeclaration;
    final clazz = clazzDeclaration.declaredFragment?.element;
    if (clazz == null) return;

    // Check if the class extends SetupWidget
    if (!isSubtypeOfSetupWidget(clazz)) {
      return;
    }

    // Find the setup method
    MethodDeclaration? setupMethod;
    for (final member in clazzDeclaration.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme == 'setup' &&
            member.parameters?.parameters.length == 2) {
          setupMethod = member;
          break;
        }
      }
    }

    if (setupMethod == null) return;

    // Get the second parameter name (props parameter)
    final propsParameter = setupMethod.parameters?.parameters[1];
    if (propsParameter == null) return;

    final propsParamName = propsParameter.name?.lexeme;
    // If props parameter is '_', skip props conversion but still convert widget
    final shouldConvertProps = propsParamName != null && propsParamName != '_';

    final extendsClause = clazzDeclaration.extendsClause;

    // Step 1: Change extends SetupWidget<ClassName> to extends StatelessWidget
    if (extendsClause != null) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(
          SourceRange(
            extendsClause.superclass.offset,
            extendsClause.superclass.length,
          ),
          (edit) {
            edit.write('StatelessWidget');
          },
        );
      });
    }

    // Step 2: Convert setup method to build method
    final method = setupMethod;
    await builder.addDartFileEdit(file, (builder) {
      // Add return type Widget before method name
      if (method.returnType != null) {
        builder.addSimpleReplacement(
          SourceRange(method.returnType!.offset, method.returnType!.length),
          'Widget',
        );
      } else {
        builder.addInsertion(method.name.offset, (edit) {
          edit.write('Widget ');
        });
      }

      // Replace method name from 'setup' to 'build'
      builder.addSimpleReplacement(
        SourceRange(method.name.offset, method.name.length),
        'build',
      );

      // Update method signature: setup(context, props) -> build(BuildContext context)
      final parameters = method.parameters;
      if (parameters != null) {
        builder.addReplacement(
          SourceRange(parameters.offset, parameters.length),
          (edit) {
            edit.write('(BuildContext context)');
          },
        );
      }

      // Unwrap return statement from function and replace props() calls
      final body = method.body;

      if (body is BlockFunctionBody) {
        // Replace props() calls in the method body (only if shouldConvertProps)

        if (shouldConvertProps) {
          final visitor = RemovePropsReplacerVisitor(clazz.thisType);
          body.accept(visitor);

          RemovePropsReplacerVisitor.applyReplacements(
            builder,
            visitor.toRemove,
            visitor.toReplace,
          );
        }

        final returnBody = getReturnExpression(body);

        if (returnBody != null && returnBody.returnStatement != null) {
          final returnExpression = returnBody.returnExpression;
          final returnStatement = returnBody.returnStatement!;

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
      } else if (body is ExpressionFunctionBody) {
        // Replace props() calls in expression body (only if shouldConvertProps)
        if (shouldConvertProps) {
          final visitor = RemovePropsReplacerVisitor(clazz.thisType);
          body.accept(visitor);

          RemovePropsReplacerVisitor.applyReplacements(
            builder,
            visitor.toRemove,
            visitor.toReplace,
          );
        }

        // Handle expression body: setup(context, props) => (...parameters) Expression; -> build(context) { Expression }
        // ExpressionFunctionBody structure: 'async'? '=>' [Expression] ';'
        // If the expression is FunctionExpression with parameters, remove "=> (...parameters)"
        final expression = body.expression;
        final finalResultIsBlockBody =
            _unwrapFunctionExpressionFromExpressionBody(
              body,
              unitResult,
              builder,
            );

        // Delete semicolon only if the final result is a BlockFunctionBody
        // If the final result is an ExpressionFunctionBody, keep the semicolon
        if (finalResultIsBlockBody) {
          _removeSemicolonAfterExpression(
            expression,
            body,
            unitResult,
            builder,
          );
        }
      }
    });
  }

  /// Removes the parameters from a FunctionExpression
  /// Returns true if the function body is a BlockFunctionBody
  static bool _removeFunctionExpressionParameters(
    FunctionExpression expression,
    DartFileEditBuilder builder,
    ParsedUnitResult unitResult,
  ) {
    final parameters = expression.parameters;
    if (parameters == null) return false;

    final functionBody = expression.body;
    if (functionBody.offset > parameters.offset) {
      builder.addSimpleReplacement(
        SourceRange(parameters.offset, functionBody.offset - parameters.offset),
        '',
      );
    }

    // If functionBody is BlockFunctionBody, reduce indentation by 2 levels
    // setup(context, props) => () { ... } -> build(context) { ... }
    // Need to reduce 2 levels: one for () { ... } and one for => () { ... }
    if (functionBody is BlockFunctionBody) {
      final block = functionBody.block;
      addIndentToLines(
        unitResult,
        builder,
        startOffset: block.beginToken.offset,
        endOffset: block.endToken.offset,
        indent: -2,
      );
    }

    return functionBody is BlockFunctionBody;
  }

  /// Removes the semicolon after an expression if it exists
  static void _removeSemicolonAfterExpression(
    Expression expression,
    ExpressionFunctionBody body,
    ResolvedUnitResult unitResult,
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

  /// Handles unwrapping a FunctionExpression from ExpressionFunctionBody
  /// Returns true if the final result is a BlockFunctionBody
  static bool _unwrapFunctionExpressionFromExpressionBody(
    ExpressionFunctionBody body,
    ResolvedUnitResult unitResult,
    DartFileEditBuilder builder,
  ) {
    final expression = body.expression;

    // Delete "=>" and any preceding "async" keyword: from body.offset to expression.offset
    if (expression.offset > body.offset) {
      builder.addSimpleReplacement(
        SourceRange(body.offset, expression.offset - body.offset),
        '',
      );
    }

    // If expression is FunctionExpression, remove its parameters "()"
    bool finalResultIsBlockBody = false;
    if (expression is FunctionExpression) {
      finalResultIsBlockBody = _removeFunctionExpressionParameters(
        expression,
        builder,
        unitResult,
      );
    }

    return finalResultIsBlockBody;
  }

  /// Handles unwrapping a FunctionExpression from a return statement
  static void _unwrapFunctionExpressionFromReturn(
    FunctionExpression functionExpression,
    ReturnStatement returnStatement,
    DartFileEditBuilder builder,
    ParsedUnitResult unitResult,
  ) {
    final parameters = functionExpression.parameters;
    if (parameters == null) return;

    final functionBody = functionExpression.body;

    if (functionBody is ExpressionFunctionBody) {
      // return () => Widget -> return Widget
      // Delete "() =>" part: from parameters start to expression start
      final expression = functionBody.expression;
      if (expression.offset > parameters.offset) {
        builder.addSimpleReplacement(
          SourceRange(parameters.offset, expression.offset - parameters.offset),
          '',
        );
      }
    } else if (functionBody is BlockFunctionBody) {
      // return () { ... } -> ... (remove return, (), {, }, and semicolon)
      // Delete "return" keyword and space before parameters
      final returnKeyword = returnStatement.returnKeyword;
      if (returnKeyword.offset < parameters.offset) {
        builder.addSimpleReplacement(
          SourceRange(
            returnKeyword.offset,
            parameters.offset - returnKeyword.offset,
          ),
          '',
        );
      }
      // Delete "()" part
      final block = functionBody.block;
      if (block.offset > parameters.offset) {
        builder.addSimpleReplacement(
          SourceRange(parameters.offset, block.offset - parameters.offset),
          '',
        );
      }
      // Delete "{" and "}" brackets
      final leftBracket = block.leftBracket;
      final rightBracket = block.rightBracket;

      // Reduce indentation of inner content (one level less)
      addIndentToLines(
        unitResult,
        builder,
        startOffset: block.beginToken.offset,
        endOffset: block.endToken.offset,
        indent: -1,
      );

      builder.addSimpleReplacement(
        SourceRange(leftBracket.offset, leftBracket.length),
        '',
      );
      builder.addSimpleReplacement(
        SourceRange(rightBracket.offset, rightBracket.length),
        '',
      );
      // Delete semicolon
      final semicolon = returnStatement.semicolon;
      builder.addSimpleReplacement(
        SourceRange(semicolon.offset, semicolon.length),
        '',
      );
    }
  }
}
