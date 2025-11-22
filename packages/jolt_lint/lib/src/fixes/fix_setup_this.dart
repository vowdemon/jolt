import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:jolt_lint/src/shared.dart';

class FixSetupThisExplicit extends ResolvedCorrectionProducer
    with FixableSetupThis {
  FixSetupThisExplicit({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThisExplict;
}

class FixSetupThisImplicit extends ResolvedCorrectionProducer
    with FixableSetupThis {
  FixSetupThisImplicit({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThisImplicit;
}

class FixSetupThisAssign extends ResolvedCorrectionProducer
    with FixableSetupThis {
  FixSetupThisAssign({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThisAssign;
}

class FixSetupThisAssignable extends ResolvedCorrectionProducer
    with FixableSetupThis {
  FixSetupThisAssignable({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThisAssignable;
}

mixin FixableSetupThis on ResolvedCorrectionProducer {
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

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
          if (this is FixSetupThisAssign) {
            final rightHandSide = (node as AssignmentExpression).rightHandSide;
            builder.addSimpleReplacement(
              SourceRange(rightHandSide.offset, rightHandSide.length),
              '$propsName()',
            );
          } else if (this is FixSetupThisAssignable) {
            final leftHandSide = (node as AssignmentExpression).leftHandSide;
            builder.addSimpleInsertion(leftHandSide.offset, '$propsName()');
          }
        });

      case VariableDeclaration():
        await builder.addDartFileEdit(file, (builder) {
          final propsName = ensureSetupPropsName(node, builder);
          final initializer = (node as VariableDeclaration).initializer;
          if (initializer == null) return;
          builder.addSimpleReplacement(
            SourceRange(initializer.offset, initializer.length),
            '$propsName()',
          );
        });
    }
  }
}
