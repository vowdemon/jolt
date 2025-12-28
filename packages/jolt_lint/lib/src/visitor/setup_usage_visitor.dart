import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:jolt_lint/src/shared.dart';

class SetupUsageVisitor extends RecursiveAstVisitor<void> {
  final Set<Element> instanceMembers;
  final MultiAnalysisRule rule;
  final ClassElement classNode;

  SetupUsageVisitor({
    required this.instanceMembers,
    required this.rule,
    required this.classNode,
  });

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // this.xxx, (this..xx).xx

    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // this.xxx(), (this..xx).xx()
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // xxx, xxx()
    // xxx = xxx;

    final element = node.element;

    if (node.inDeclarationContext()) return;
    if (element is LocalElement) return;

    if (node.isQualified) {
      super.visitSimpleIdentifier(node);
      return;
    }
    if (element == null) {
      if (node.isAssignable &&
          instanceMembers.any((e) => e.name == node.name)) {
        rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
      }
      super.visitSimpleIdentifier(node);
    } else if (((element.enclosingElement == classNode &&
            instanceMembers.any((e) => e.name == element.name)) ||
        instanceMembers.contains(element))) {
      rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
    }

    super.visitSimpleIdentifier(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // var that1 = that2 = this;
    final right = node.rightHandSide;
    if (right is ThisExpression) {
      rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
    }

    // [this.]setter = xxx;
    // implicit => simpleIdentifier
    // explicit => propertyAccess

    super.visitAssignmentExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // var that = this;
    final initializer = node.initializer;
    if (initializer is ThisExpression) {
      rule.reportAtNode(node, diagnosticCode: JoltCode.setupThis);
    }
    super.visitVariableDeclaration(node);
  }
}
