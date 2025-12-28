import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/scope.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

class RemovePropsReplacerVisitor extends RecursiveAstVisitor<void> {
  final InterfaceType classType;

  final List<AstNode> toReplace = [];
  final List<AstNode> toRemove = [];
  StringBuffer debugBuffer = StringBuffer();

  RemovePropsReplacerVisitor(this.classType);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (node.staticType == classType) {
      // props()
      _replaceThis(node);
      return;
    }

    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is ThisExpression ||
        node.realTarget is ThisExpression ||
        node.realTarget == null) {
      return;
    }

    if (node.staticType == classType) {
      // props.get()
      _replaceThis(node);
      return;
    }

    final identifier = node.methodName;
    final element = identifier.element?.nonSynthetic;
    final scope = _getScope(node);
    final AstNode target = node.realTarget!;
    final staticType = _getStaticType(target);

    if (staticType == null) {
      return;
    }

    if (staticType == classType) {
      final r = scope?.lookup(identifier.name);
      final baseElement = r?.getter?.nonSynthetic ?? r?.setter?.nonSynthetic;

      if (baseElement != null) {
        // props().a()
        if (baseElement is MethodElement || baseElement == element) {
          _removeThis(target);
        } else {
          _replaceThis(target);
        }
        return;
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      return;
    }

    if (node.staticType == classType) {
      // props.value
      _replaceThis(node);
      return;
    }

    final identifier = node.propertyName;
    final element = identifier.element?.nonSynthetic;
    final scope = _getScope(node);
    final AstNode target = node.realTarget;
    final staticType = _getStaticType(target);

    if (staticType == null) {
      return;
    }

    if (staticType == classType) {
      final r = scope?.lookup(identifier.name);
      final baseElement = r?.getter?.nonSynthetic ?? r?.setter?.nonSynthetic;

      if (baseElement != null) {
        // props.value.xxx
        // props().xxx
        if (baseElement is FieldElement || baseElement == element) {
          _removeThis(target);
        } else {
          _replaceThis(target);
        }
        return;
      }
    }

    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.staticType == classType) {
      // props.value
      _replaceThis(node);
      return;
    }

    super.visitPrefixedIdentifier(node);
  }

  void _removeThis(AstNode target) {
    toRemove.add(target);
  }

  void _replaceThis(AstNode target) {
    toReplace.add(target);
  }

  Scope? _getScope(AstNode node) {
    Scope? scope;
    for (AstNode? context = node; context != null; context = context.parent) {
      scope = ScopeResolverVisitor.getNodeNameScope(context);
      if (scope != null) {
        break;
      }
    }
    return scope;
  }

  DartType? _getStaticType(AstNode node) {
    return switch (node) {
      SimpleIdentifier() => node.staticType,
      PrefixedIdentifier() => node.staticType,
      PropertyAccess() => node.staticType,
      FunctionExpressionInvocation() => node.staticType,
      MethodInvocation() => node.staticType,
      _ => null,
    };
  }

  static void removeThis(DartFileEditBuilder builder, List<AstNode> toRemove) {
    for (final node in toRemove) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length + 1),
        '',
      );
    }
  }

  static void replaceThis(
    DartFileEditBuilder builder,
    List<AstNode> toReplace,
  ) {
    for (final node in toReplace) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'this',
      );
    }
  }

  static void applyReplacements(
    DartFileEditBuilder builder,
    List<AstNode> toRemove,
    List<AstNode> toReplace,
  ) {
    removeThis(builder, toRemove);
    replaceThis(builder, toReplace);
  }
}
