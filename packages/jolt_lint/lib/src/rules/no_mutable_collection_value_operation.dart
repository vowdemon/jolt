import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:jolt_lint/src/shared.dart';

class NoMutableCollectionValueOperationRule extends MultiAnalysisRule {
  NoMutableCollectionValueOperationRule()
    : super(
        name: 'no_mutable_collection_value_operation',
        description: 'No mutable collection value operation',
      );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _MutableCollectionValueVisitor(this, context);
    registry.addPropertyAccess(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }

  @override
  List<DiagnosticCode> get diagnosticCodes => [
    JoltCode.mutableCollectionValueOperation,
  ];
}

class _MutableCollectionValueVisitor extends SimpleAstVisitor<void> {
  final MultiAnalysisRule rule;
  final RuleContext context;

  _MutableCollectionValueVisitor(this.rule, this.context);

  bool _checkIsMutable(InterfaceType type) {
    final isMutable = type.allSupertypes.any(
      (interface) => interface.element.displayName == 'IMutableCollection',
    );
    if (!isMutable) {
      return false;
    }
    return true;
  }

  bool _isTargetNotThisOrSuper(Expression target) {
    return target is! ThisExpression && target is! SuperExpression;
  }

  void _checkTargetIsMutable(AstNode node, Expression target) {
    final toCheckType = switch (target) {
      PropertyAccess(:final realTarget, :final propertyName) =>
        (realTarget.staticType is InterfaceType &&
                propertyName.name == 'value' &&
                _isTargetNotThisOrSuper(realTarget))
            ? realTarget.staticType
            : null,
      PrefixedIdentifier(:final prefix, :final identifier) =>
        (prefix.staticType is InterfaceType &&
                identifier.name == 'value' &&
                _isTargetNotThisOrSuper(prefix))
            ? prefix.staticType
            : null,
      MethodInvocation(:final target, :final methodName) =>
        (target?.staticType is InterfaceType &&
                methodName.name == 'get' &&
                target != null &&
                _isTargetNotThisOrSuper(target))
            ? target.staticType
            : null,
      FunctionExpressionInvocation(:final function) =>
        (function.staticType is InterfaceType &&
                _isTargetNotThisOrSuper(function))
            ? function.staticType
            : null,
      _ => null,
    };

    if (toCheckType == null || toCheckType is! InterfaceType) return;
    if (_checkIsMutable(toCheckType)) {
      rule.reportAtNode(
        node,
        diagnosticCode: JoltCode.mutableCollectionValueOperation,
      );
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _checkTargetIsMutable(node, node.realTarget);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.realTarget == null) return;
    _checkTargetIsMutable(node, node.realTarget!);
  }
}
