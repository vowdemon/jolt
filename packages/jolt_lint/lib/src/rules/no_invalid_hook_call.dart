import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:jolt_lint/src/shared.dart';

class NoInvalidHookCallRule extends MultiAnalysisRule {
  NoInvalidHookCallRule()
    : super(name: 'no_invalid_hook_call', description: 'No invalid hook call');

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _HookCallVisitor(this, context);
    registry.addMethodInvocation(this, visitor);
    registry.addFunctionExpressionInvocation(this, visitor);
  }

  @override
  List<DiagnosticCode> get diagnosticCodes => [JoltCode.invalidHookCall];
}

class _HookCallVisitor extends SimpleAstVisitor<void> {
  final MultiAnalysisRule rule;
  final RuleContext context;

  _HookCallVisitor(this.rule, this.context);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // useXXX() - method call()
    if (node.function is SimpleIdentifier) {
      final identifier = node.function as SimpleIdentifier;
      if (!_checkAnnotation(identifier.element)) {
        return;
      }

      if (_isValidCallInFunctionBody(node)) {
        return;
      }

      rule.reportAtNode(node, diagnosticCode: JoltCode.invalidHookCall);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check if this is a hook call
    // useXXX() - function call, check method name
    // useXXX.yyy() - method call, check target
    if (!_checkAnnotation(node.methodName.element)) {
      return;
    }

    if (_isValidCallInFunctionBody(node)) {
      return;
    }

    rule.reportAtNode(node, diagnosticCode: JoltCode.invalidHookCall);
  }

  bool _checkAnnotation(Element? element) {
    if (element == null) return false;
    final annotations = element.metadata.annotations;
    for (var annotation in annotations) {
      final annotationElement = annotation
          .computeConstantValue()
          ?.type
          ?.element;
      if (annotationElement != null) {
        if (annotationElement.displayName == 'DefineHook' &&
            annotationElement.library?.identifier == joltDefineHookUri) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isValidCallInSetupMethod(MethodDeclaration method, AstNode node) {
    if (method.name.lexeme != 'setup') return false;
    final setupReturnExpression = getReturnExpression(
      method.body,
    )?.returnExpression;
    if (setupReturnExpression != null) {
      for (
        AstNode? current = node.parent;
        current != null;
        current = current.parent
      ) {
        if (current == setupReturnExpression) {
          return false;
        }
      }
    }
    return true;
  }

  bool _isValidCallInSetupArgument(
    FunctionExpression functionExpression,
    AstNode node,
  ) {
    if (functionExpression.parent is NamedExpression) {
      final namedExpression = functionExpression.parent as NamedExpression;
      if (namedExpression.name.label.name == 'setup') {
        final returnExpression = getReturnExpression(
          functionExpression.body,
        )?.returnExpression;
        if (returnExpression != null) {
          for (
            AstNode? current = node.parent;
            current != null;
            current = current.parent
          ) {
            if (current == returnExpression) {
              return false;
            }
          }
          return true;
        }
      }
    }

    return false;
  }

  bool _isValidCallInFunctionBody(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is MethodDeclaration) {
        if ((_checkAnnotation(current.declaredFragment?.element)) ||
            _isValidCallInSetupMethod(current, node)) {
          return true;
        }
      } else if (current is FunctionDeclaration) {
        if (_checkAnnotation(current.declaredFragment?.element)) {
          return true;
        }
      } else if (current is FunctionExpression) {
        if (current.parent is VariableDeclaration) {
          final variableDeclaration = current.parent as VariableDeclaration;
          if (_checkAnnotation(variableDeclaration.declaredFragment?.element)) {
            return true;
          }
        } else if (_isValidCallInSetupArgument(current, node)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}
