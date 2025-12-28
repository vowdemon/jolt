import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:jolt_lint/src/shared.dart';

class FixSetupThis extends ResolvedCorrectionProducer {
  FixSetupThis({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThis;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind? get multiFixKind => JoltFix.setupThisMulti;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    switch (node) {
      case PropertyAccess() || MethodInvocation():
        await builder.addDartFileEdit(file, (builder) {
          final target = getTargetExpression(node);
          final propsName = ensureSetupPropsName(node, builder);

          builder.addSimpleReplacement(
            SourceRange(target.offset, target.length),
            '$propsName()',
          );
        });

      case SimpleIdentifier():
        await builder.addDartFileEdit(file, (builder) {
          final parent = node.parent;
          final propsName = ensureSetupPropsName(node, builder);
          if (parent is InterpolationExpression) {
            builder.addSimpleReplacement(
              SourceRange(node.offset, node.length),
              '{$propsName().${node.toSource()}}',
            );
          } else {
            builder.addSimpleInsertion(node.offset, '$propsName().');
          }
        });

      case AssignmentExpression():
        await builder.addDartFileEdit(file, (builder) {
          final propsName = ensureSetupPropsName(node, builder);
          final assignment = node as AssignmentExpression;
          final leftHandSide = assignment.leftHandSide;
          final rightHandSide = assignment.rightHandSide;

          if (rightHandSide is ThisExpression) {
            // Assigning this to something: var x = this;
            builder.addSimpleReplacement(
              SourceRange(rightHandSide.offset, rightHandSide.length),
              '$propsName()',
            );
          } else if (leftHandSide is SimpleIdentifier) {
            // Assigning to an instance member setter: field = value;
            final element = leftHandSide.element;
            if (element == null) {
              builder.addSimpleInsertion(leftHandSide.offset, '$propsName().');
            }
          }
        });

      case VariableDeclaration():
        await builder.addDartFileEdit(file, (builder) {
          final propsName = ensureSetupPropsName(node, builder);
          final variable = node as VariableDeclaration;
          final initializer = variable.initializer;
          if (initializer == null) return;
          builder.addSimpleReplacement(
            SourceRange(initializer.offset, initializer.length),
            '$propsName()',
          );
        });
    }
  }
}
