import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/add_props_replacer_visitor.dart';

class ConvertStatelessWidgetToSetupWidgetAssist
    extends ResolvedCorrectionProducer {
  ConvertStatelessWidgetToSetupWidgetAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertStatelessWidgetToSetupWidget;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (node is! ClassDeclaration) return;

    final clazzDeclaration = node as ClassDeclaration;
    final clazz = clazzDeclaration.declaredFragment?.element;
    if (clazz == null) return;

    // Check if the class extends StatelessWidget
    final statelessWidget = await sessionHelper.getFlutterClass(
      'StatelessWidget',
    );
    if (statelessWidget == null) return;

    if (!typeSystem.isSubtypeOf(clazz.thisType, statelessWidget.thisType)) {
      return;
    }

    // Check if already extends SetupWidget
    if (isSubtypeOfSetupWidget(clazz)) {
      return;
    }

    // Find the build method
    MethodDeclaration? buildMethod;
    for (final member in clazzDeclaration.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme == 'build' &&
            member.parameters?.parameters.length == 1) {
          buildMethod = member;
          break;
        }
      }
    }

    if (buildMethod == null) return;

    final className = clazzDeclaration.name.lexeme;
    final extendsClause = clazzDeclaration.extendsClause;

    // Step 1: Add import for SetupWidget
    await builder.addDartFileEdit(file, (builder) {
      builder.importLibrary(Uri.parse(joltFlutterSetupUri));
    });

    // Step 2: Change extends StatelessWidget to extends SetupWidget<ClassName>
    if (extendsClause != null) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(
          SourceRange(extendsClause.offset, extendsClause.length),
          (edit) {
            edit.write('extends SetupWidget<$className>');
          },
        );
      });
    }

    // Step 3: Convert build method to setup method
    final method = buildMethod;
    await builder.addDartFileEdit(file, (builder) {
      // Remove return type annotation if present
      final returnType = method.returnType;
      if (returnType != null) {
        // Remove the return type and the space after it
        final returnTypeEnd = returnType.end;
        final methodNameStart = method.name.offset;
        // Check if there's a space between return type and method name
        final hasSpace = returnTypeEnd < methodNameStart;
        if (hasSpace) {
          // Remove return type and the space
          builder.addSimpleReplacement(
            SourceRange(returnType.offset, methodNameStart - returnType.offset),
            '',
          );
        } else {
          // Remove only the return type
          builder.addSimpleReplacement(
            SourceRange(returnType.offset, returnType.length),
            '',
          );
        }
      }

      // Replace method name from 'build' to 'setup'
      builder.addSimpleReplacement(
        SourceRange(method.name.offset, method.name.length),
        'setup',
      );

      // Update method signature: build(BuildContext context) -> setup(context, props)
      final parameters = method.parameters;
      if (parameters != null) {
        // Replace parameters - remove type annotations
        builder.addReplacement(
          SourceRange(parameters.offset, parameters.length),
          (edit) {
            edit.write('(context, props)');
          },
        );
      }

      // Wrap return statement in a function and replace instance member access
      final body = method.body;

      // Get instance members of the class
      final instanceMembers = <Element>{
        ...clazz.fields.where((e) => !e.isStatic),
        ...clazz.getters.where((e) => !e.isStatic),
        ...clazz.methods.where((e) => !e.isStatic),
        ...clazz.setters.where((e) => !e.isStatic),
      };

      if (body is BlockFunctionBody) {
        // Replace instance member access in the method body
        final visitor = AddPropsReplacerVisitor(instanceMembers, clazz);
        body.accept(visitor);

        // Apply all replacements collected by visitor
        AddPropsReplacerVisitor.applyReplacements(builder, visitor);

        final statements = body.block.statements;
        if (statements.isNotEmpty) {
          // Find the return statement
          ReturnStatement? returnStatement;
          for (final stmt in statements) {
            if (stmt is ReturnStatement) {
              returnStatement = stmt;
              break;
            }
          }

          if (returnStatement != null) {
            final returnExpression = returnStatement.expression;
            if (returnExpression != null) {
              // Replace return Widget with return () => Widget
              // Insert "() => " after "return" keyword
              final returnKeyword = returnStatement.returnKeyword;
              builder.addSimpleInsertion(returnKeyword.end, ' () =>');
            }
          } else {
            // No return statement found, wrap the entire body
            // build(context) { ... } -> setup(context, props) { return () { ... }; }
            builder.addInsertion(body.block.leftBracket.offset, (edit) {
              edit.writeln('{');
              edit.write(edit.getIndent(2));
              edit.write('return () ');
            });

            builder.addInsertion(body.block.rightBracket.end, (edit) {
              edit.writeln(';');
              edit.write(edit.getIndent(1));
              edit.write('}');
            });

            // Increase indentation for all lines inside the block
            addIndentToLines(
              unitResult,
              builder,
              startOffset: body.block.beginToken.offset,
              endOffset: body.block.endToken.offset,
              indent: 1,
            );
          }
        }
      } else if (body is ExpressionFunctionBody) {
        // Replace instance member access in expression body
        final visitor = AddPropsReplacerVisitor(instanceMembers, clazz);
        body.accept(visitor);

        // Apply all replacements collected by visitor
        AddPropsReplacerVisitor.applyReplacements(builder, visitor);

        // Handle expression body: Widget build(BuildContext context) => Widget()
        // Convert ExpressionFunctionBody to BlockFunctionBody with wrapped return
        // build(context) => Widget -> setup(context, props) { return () => Widget; }
        final expression = body.expression;
        // Delete "=>" part: from body.offset to expression.offset
        if (expression.offset > body.offset) {
          builder.addSimpleReplacement(
            SourceRange(body.offset, expression.offset - body.offset),
            '',
          );
        }

        builder.addInsertion(expression.offset, (edit) {
          edit.writeln('{');
          edit.write(edit.getIndent(2));
          edit.write('return () => ');
        });

        // Insert "; }" after expression, but need to handle the original semicolon
        // ExpressionFunctionBody has structure: '=>' [Expression] ';'
        // We need to replace the original semicolon with "; }"
        final contentAfterExpression = unitResult.content.substring(
          expression.end,
          body.end,
        );
        if (contentAfterExpression.trim().startsWith(';')) {
          // Replace the original semicolon with "; }"
          final semicolonOffset =
              expression.end + contentAfterExpression.indexOf(';');
          builder.addSimpleReplacement(SourceRange(semicolonOffset, 1), ';');
          builder.addInsertion(semicolonOffset + 1, (edit) {
            edit.writeln();
            edit.write(edit.getIndent(1));
            edit.write('}');
          });
        } else {
          // No semicolon found, just insert "; }"
          builder.addInsertion(expression.end, (edit) {
            edit.writeln(';');
            edit.write(edit.getIndent(1));
            edit.write('}');
          });
        }
      }
    });
  }
}
