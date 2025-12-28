import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';

class AddPropsReplacerVisitor extends RecursiveAstVisitor<void> {
  final Set<Element> instanceMembers;
  final ClassElement classElement;

  // Nodes to replace with "props()"
  final List<AstNode> toReplaceWithProps = [];
  // Nodes to insert "props()." before
  final List<AstNode> toInsertPropsBefore = [];
  // Nodes to replace with "props().${name}" (for string interpolation)
  final Map<AstNode, String> toReplaceWithPropsPrefix = {};

  AddPropsReplacerVisitor(this.instanceMembers, this.classElement);

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Handle assignment: var that = this; or this.field = value;
    final right = node.rightHandSide;
    if (right is ThisExpression) {
      // Similar to fix_setup_this.dart: replace this with props()
      toReplaceWithProps.add(right);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Handle: var that = this;
    final initializer = node.initializer;
    if (initializer is ThisExpression) {
      // Similar to fix_setup_this.dart: replace this with props()
      toReplaceWithProps.add(initializer);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Handle this.field or this.method
    // Similar to fix_setup_this.dart: replace the target (this) with props()
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      final target = getTargetExpression(node);
      toReplaceWithProps.add(target);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Handle this.method() or method() (implicit)
    final element = node.methodName.element;

    // Check if it's an explicit this.method() call
    // Similar to fix_setup_this.dart: replace the target (this) with props()
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      final target = getTargetExpression(node);
      toReplaceWithProps.add(target);
    } else if (element != null &&
        element.enclosingElement == classElement &&
        instanceMembers.contains(element)) {
      // Implicit method call: method() -> props().method()
      // Similar to fix_setup_this.dart: insert props(). before the method name
      toInsertPropsBefore.add(node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Handle implicit field access: field -> props().field
    // Similar to setup_usage_visitor.dart and fix_setup_this.dart
    if (node.inDeclarationContext()) {
      super.visitSimpleIdentifier(node);
      return;
    }

    if (node.isQualified) {
      super.visitSimpleIdentifier(node);
      return;
    }

    // Skip if this identifier is a method name in a MethodInvocation
    // (MethodInvocation is already handled in visitMethodInvocation)
    final parent = node.parent;
    if (parent is MethodInvocation && parent.methodName == node) {
      super.visitSimpleIdentifier(node);
      return;
    }

    final element = node.element;
    if (element is LocalElement) {
      super.visitSimpleIdentifier(node);
      return;
    }

    // Check if it's an instance member
    // Similar to setup_usage_visitor.dart logic
    if (element == null) {
      // Check if it's an assignable instance member
      if (node.isAssignable &&
          instanceMembers.any((e) => e.name == node.name)) {
        // Similar to fix_setup_this.dart: insert props(). before the identifier
        toInsertPropsBefore.add(node);
      }
    } else if (((element.enclosingElement == classElement &&
            instanceMembers.any((e) => e.name == element.name)) ||
        instanceMembers.contains(element))) {
      // Similar to fix_setup_this.dart: handle InterpolationExpression specially
      if (parent is InterpolationExpression) {
        // In string interpolation: ${field} -> ${props().field}
        toReplaceWithPropsPrefix[node] = 'props().${node.name}';
      } else {
        // Regular case: insert props(). before the identifier
        toInsertPropsBefore.add(node);
      }
    }

    super.visitSimpleIdentifier(node);
  }

  /// Apply all replacements to the builder
  static void applyReplacements(
    DartFileEditBuilder builder,
    AddPropsReplacerVisitor visitor, {
    bool useCall = true,
  }) {
    final propsName = useCall ? 'props()' : 'props';
    // Replace nodes with "props()"
    for (final node in visitor.toReplaceWithProps) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        propsName,
      );
    }

    // Insert "props()." before nodes
    for (final node in visitor.toInsertPropsBefore) {
      builder.addSimpleInsertion(node.offset, '$propsName.');
    }

    // Replace nodes with "props().${name}" (for string interpolation)
    for (final entry in visitor.toReplaceWithPropsPrefix.entries) {
      builder.addSimpleReplacement(
        SourceRange(entry.key.offset, entry.key.length),
        entry.value,
      );
    }
  }
}
