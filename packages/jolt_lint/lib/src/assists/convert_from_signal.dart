import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:jolt_lint/src/shared.dart';

class ConvertFromSignalAssist extends ResolvedCorrectionProducer {
  ConvertFromSignalAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertFromSignal;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (node is! VariableDeclaration) return;
    final signalClass = await sessionHelper.getClass(joltUri, 'Signal');
    if (signalClass == null) return;

    final variable = node as VariableDeclaration;
    final initializer = variable.initializer;
    final declList = variable.parent as VariableDeclarationList;
    TypeAnnotation? type = declList.type;

    // Check if the type is Signal<T>
    InterfaceType? signalType;
    final typeDartType = type?.type;
    if (typeDartType is InterfaceType &&
        (signalType = typeDartType.asInstanceOf(signalClass)) != null) {
      // Type is Signal<T>
    } else if (initializer?.staticType is InterfaceType &&
        (signalType = (initializer!.staticType as InterfaceType).asInstanceOf(
              signalClass,
            )) !=
            null) {
      // Initializer is Signal<T>()
    } else {
      return; // Not a signal, skip
    }

    final T = signalType!.typeArguments.first;

    // Step 1: Change type from Signal<T> to T
    if (type != null) {
      await builder.addDartFileEdit(file, (builder) async {
        builder.addSimpleReplacement(
          SourceRange(type.offset, type.length),
          T.getDisplayString(),
        );
      });
    }

    // Step 2: Change initializer from Signal(x) to x
    if (initializer != null) {
      Expression? inner = _extractSignalArg(initializer);
      if (inner != null) {
        await builder.addDartFileEdit(file, (builder) async {
          builder.addReplacement(
            SourceRange(initializer.offset, initializer.length),
            (eb) => eb.write(inner.toSource()),
          );
        });
      }
    }

    // Step 3: Update references in scope: xxx.value → xxx
    AstNode scope = node.root;
    final visitor = _UnwrapScopeVisitor(
      variable.declaredFragment!.element,
      builder,
      file,
    );
    scope.accept(visitor);

    // The visitor directly performs replacements on the builder
  }

  /// Signal(expr) → expr
  Expression? _extractSignalArg(Expression initializer) {
    if (initializer is InstanceCreationExpression) {
      if (initializer.argumentList.arguments.length == 1) {
        return initializer.argumentList.arguments.first;
      }
    }
    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'Signal') {
      if (initializer.argumentList.arguments.length == 1) {
        return initializer.argumentList.arguments.first;
      }
    }
    return null;
  }
}

class _UnwrapScopeVisitor extends RecursiveAstVisitor<void> {
  final VariableElement target;
  final ChangeBuilder builder;
  final String file;

  _UnwrapScopeVisitor(this.target, this.builder, this.file);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Replace s1.value with s1
    if (node.identifier.name == 'value' && node.prefix.element == target) {
      builder.addDartFileEdit(file, (editBuilder) {
        editBuilder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          node.prefix.name, // Replace entire 's1.value' with 's1'
        );
      });
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Replace s1.value with s1
    if (node.propertyName.name == 'value' &&
        node.target is SimpleIdentifier &&
        (node.target as SimpleIdentifier).element == target) {
      builder.addDartFileEdit(file, (editBuilder) {
        editBuilder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          (node.target as SimpleIdentifier).name,
        );
      });
    }
    super.visitPropertyAccess(node);
  }
}
