import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:jolt_lint/src/shared.dart';

class ConvertToSignalAssist extends ResolvedCorrectionProducer {
  ConvertToSignalAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertToSignal;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (node is! VariableDeclaration) return;
    final readonlyNode = await sessionHelper.getClass(joltUri, 'ReadonlyNode');
    if (readonlyNode == null) return;
    final variable = node as VariableDeclaration;
    final initializer = variable.initializer;
    final declList = variable.parent as VariableDeclarationList;
    TypeAnnotation? type = declList.type;

    final typeDartType = type?.type;
    final initializerDartType = initializer?.staticType;
    if ((typeDartType != null &&
            typeDartType.asInstanceOf(readonlyNode) != null) ||
        (initializerDartType != null &&
            initializerDartType.asInstanceOf(readonlyNode) != null)) {
      return;
    }

    final keyword = declList.keyword;
    if (keyword != null && keyword.keyword == Keyword.CONST) {
      await builder.addDartFileEdit(file, (builder) async {
        builder.addSimpleReplacement(
          SourceRange(keyword.offset, keyword.length),
          Keyword.FINAL.lexeme,
        );
      });
    }

    if (type != null) {
      final typeText = type.toSource();
      await builder.addDartFileEdit(file, (builder) async {
        builder.addReplacement(
          SourceRange(type.offset, type.length),
          (eb) => eb.write('Signal<$typeText>'),
        );
      });
    } else {
      if (initializer == null) {
        await builder.addDartFileEdit(file, (builder) async {
          builder.addInsertion(
            keyword!.end,
            (edit) => edit.write(' Signal<dynamic>'),
          );
        });
      }
    }

    if (initializer != null) {
      final initText = initializer.toSource();
      await builder.addDartFileEdit(file, (builder) async {
        builder.addReplacement(
          SourceRange(initializer.offset, initializer.length),
          (edit) => edit.write('Signal($initText)'),
        );
      });
    }

    AstNode? scope = node.root;

    final visitor = _ScopeVisitor(variable.declaredFragment!.element);
    scope.accept(visitor);

    for (final edit in visitor.edits) {
      await builder.addDartFileEdit(file, (builder) async {
        builder.addSimpleReplacement(
          SourceRange(edit.offset, edit.length),
          '${edit.name}.value',
        );
      });
    }
  }
}

class _ScopeVisitor extends RecursiveAstVisitor<void> {
  final VariableElement target;

  final List<SimpleIdentifier> edits = [];

  _ScopeVisitor(this.target);

  @override
  Future<void> visitSimpleIdentifier(SimpleIdentifier node) async {
    final element = node.element;

    if (element == target) {
      edits.add(node);
    }

    super.visitSimpleIdentifier(node);
  }
}
