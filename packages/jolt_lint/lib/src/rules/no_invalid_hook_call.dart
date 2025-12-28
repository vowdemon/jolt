import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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
      if (!_isHookName(identifier.name) &&
          !_isLifecycleHookName(identifier.name)) {
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
    if (!_isHookCall(node) && !_isLifecycleHookName(node.methodName.name)) {
      return;
    }

    if (_isValidCallInFunctionBody(node)) {
      return;
    }

    rule.reportAtNode(node, diagnosticCode: JoltCode.invalidHookCall);
  }

  bool _isHookCall(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (_isHookName(methodName)) {
      return true;
    }
    if (node.realTarget != null && node.realTarget is SimpleIdentifier) {
      return _isHookName((node.realTarget as SimpleIdentifier).name);
    }
    return false;
  }

  bool _isHookName(String name) {
    return (name.startsWith('use') &&
        name.length > 3 &&
        name[3].toUpperCase() == name[3]);
  }

  static const _lifecycleHookNames = {
    'onMounted',
    'onUnmounted',
    'onDidUpdateWidget',
    'onDidUpdateWidgetAt',
    'onDidChangeDependencies',
    'onActivated',
    'onDeactivated',
  };

  bool _isLifecycleHookName(String name) {
    return (name.startsWith('on') && _lifecycleHookNames.contains(name));
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

  // TODO: check setup is in SetupBuilder
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
        if (_isHookName(current.name.lexeme) ||
            _isValidCallInSetupMethod(current, node)) {
          return true;
        }
      } else if (current is FunctionDeclaration) {
        if (_isHookName(current.name.lexeme)) {
          return true;
        }
      } else if (current is FunctionExpression) {
        if (current.parent is VariableDeclaration) {
          final variableDeclaration = current.parent as VariableDeclaration;
          if (_isHookName(variableDeclaration.name.lexeme)) {
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
