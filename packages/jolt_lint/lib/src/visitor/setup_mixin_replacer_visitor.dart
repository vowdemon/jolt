import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';

/// Visitor to replace instance member access in build method for SetupMixin conversion
/// - Instance properties: field -> props.field
/// - Instance methods: method() -> widget.method()
/// - Static members: keep as is (ClassName.staticMember)
class SetupMixinReplacerVisitor extends RecursiveAstVisitor<void> {
  final Set<Element> instanceFields;
  final Set<Element> instanceMethods;
  final Set<Element> staticMembers;
  final ClassElement classElement;
  final String className;

  // Nodes to replace with "props.field"
  final List<AstNode> toReplaceWithProps = [];
  // Nodes to insert "widget." before (instance methods)
  final List<AstNode> toInsertWidgetBefore = [];
  // Nodes to replace with "props.${name}" (for string interpolation)
  final Map<AstNode, String> toReplaceWithPropsPrefix = {};

  SetupMixinReplacerVisitor(
    this.instanceFields,
    this.instanceMethods,
    this.staticMembers,
    this.classElement,
    this.className,
  );

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Handle this.field or this.method
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      final target = getTargetExpression(node);
      final propertyName = node.propertyName;
      final element = propertyName.element?.baseElement;

      if (element != null) {
        if (instanceFields.contains(element)) {
          // this.field -> props.field
          toReplaceWithProps.add(target);
        } else if (instanceMethods.contains(element)) {
          // this.method -> widget.method
          toInsertWidgetBefore.add(propertyName);
        }
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element?.baseElement;

    // Check if it's an explicit this.method() call
    if (node.target is ThisExpression || node.realTarget is ThisExpression) {
      final target = getTargetExpression(node);
      if (element != null && instanceMethods.contains(element)) {
        // this.method() -> widget.method()
        toInsertWidgetBefore.add(node.methodName);
        toReplaceWithProps.add(target);
      }
    } else if (element != null &&
        element.enclosingElement == classElement &&
        instanceMethods.contains(element)) {
      // Implicit method call: method() -> widget.method()
      toInsertWidgetBefore.add(node.methodName);
    }
    // Static methods are kept as is (ClassName.staticMethod())

    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Handle implicit field access: field -> props.field
    if (node.inDeclarationContext()) {
      super.visitSimpleIdentifier(node);
      return;
    }

    if (node.isQualified) {
      super.visitSimpleIdentifier(node);
      return;
    }

    // Skip if this identifier is a method name in a MethodInvocation
    final parent = node.parent;
    if (parent is MethodInvocation && parent.methodName == node) {
      super.visitSimpleIdentifier(node);
      return;
    }

    final element = node.element?.baseElement;
    if (element is LocalElement) {
      super.visitSimpleIdentifier(node);
      return;
    }

    // Check if it's an instance field
    if (element != null && instanceFields.contains(element)) {
      // Similar to fix_setup_this.dart: handle InterpolationExpression specially
      if (parent is InterpolationExpression) {
        // In string interpolation: ${field} -> ${props.field}
        toReplaceWithPropsPrefix[node] = 'props.${node.name}';
      } else {
        // Regular case: insert props. before the identifier
        toReplaceWithProps.add(node);
      }
    }
    // Static members are kept as is

    super.visitSimpleIdentifier(node);
  }

  /// Apply all replacements to the builder
  static void applyReplacements(
    DartFileEditBuilder builder,
    SetupMixinReplacerVisitor visitor,
  ) {
    // Replace nodes with "props" (for instance fields)
    for (final node in visitor.toReplaceWithProps) {
      if (node is SimpleIdentifier) {
        // Insert "props." before the identifier
        builder.addSimpleInsertion(node.offset, 'props.');
      } else {
        // Replace this with props
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          'props',
        );
      }
    }

    // Insert "widget." before instance methods
    for (final node in visitor.toInsertWidgetBefore) {
      builder.addSimpleInsertion(node.offset, 'widget.');
    }

    // Replace nodes with "props.${name}" (for string interpolation)
    for (final entry in visitor.toReplaceWithPropsPrefix.entries) {
      builder.addSimpleReplacement(
        SourceRange(entry.key.offset, entry.key.length),
        entry.value,
      );
    }
  }
}
