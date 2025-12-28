import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

class RemovePropsMixinReplacerVisitor extends RecursiveAstVisitor<void> {
  final InterfaceType widgetType;

  final List<AstNode> toReplaceWithWidget = [];
  final List<AstNode> toRemove = [];

  RemovePropsMixinReplacerVisitor(this.widgetType);

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.realTarget;
    final staticType = _getStaticType(target);

    if (staticType == widgetType) {
      // props.xxx -> widget.xxx
      // Replace "props" with "widget"
      if (target is SimpleIdentifier && target.name == 'props') {
        toReplaceWithWidget.add(target);
        return;
      }
      // props.value.xxx -> widget.xxx
      // props.peek.xxx -> widget.xxx
      if (target is PropertyAccess) {
        final targetTarget = target.realTarget;
        if (targetTarget is SimpleIdentifier &&
            targetTarget.name == 'props' &&
            (target.propertyName.name == 'value' ||
                target.propertyName.name == 'peek')) {
          // Remove "props.value" or "props.peek"
          toRemove.add(target);
          return;
        }
      }
    }

    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;
    final staticType = _getStaticType(target);

    if (staticType == widgetType) {
      // props.get() -> widget
      if (target is SimpleIdentifier &&
          target.name == 'props' &&
          node.methodName.name == 'get') {
        // Replace "props.get()" with "widget"
        toReplaceWithWidget.add(node);
        return;
      }
      // props.value.xxx() -> widget.xxx()
      // props.peek.xxx() -> widget.xxx()
      if (target is PropertyAccess) {
        final targetTarget = target.realTarget;
        if (targetTarget is SimpleIdentifier &&
            targetTarget.name == 'props' &&
            (target.propertyName.name == 'value' ||
                target.propertyName.name == 'peek')) {
          // Remove "props.value" or "props.peek"
          toRemove.add(target);
          return;
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Handle standalone props (not in property access or method invocation)
    // This handles cases like: props (as a variable reference)
    if (node.name == 'props') {
      final staticType = node.staticType;
      if (staticType == widgetType) {
        // props -> widget
        toReplaceWithWidget.add(node);
        return;
      }
    }

    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final staticType = node.staticType;

    if (staticType == widgetType) {
      // props.value -> widget
      // props.peek -> widget
      if (node.prefix.name == 'props' &&
          (node.identifier.name == 'value' || node.identifier.name == 'peek')) {
        toReplaceWithWidget.add(node);
        return;
      }
    }

    super.visitPrefixedIdentifier(node);
  }

  DartType? _getStaticType(AstNode? node) {
    if (node == null) return null;
    return switch (node) {
      SimpleIdentifier() => node.staticType,
      PrefixedIdentifier() => node.staticType,
      PropertyAccess() => node.staticType,
      MethodInvocation() => node.staticType,
      _ => null,
    };
  }

  static void applyReplacements(
    DartFileEditBuilder builder,
    List<AstNode> toRemove,
    List<AstNode> toReplaceWithWidget,
  ) {
    // Remove nodes (like "props.value" or "props.peek")
    for (final node in toRemove) {
      builder.addSimpleReplacement(SourceRange(node.offset, node.length), '');
    }

    // Replace nodes with "widget"
    for (final node in toReplaceWithWidget) {
      if (node is MethodInvocation) {
        // props.get() -> widget
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          'widget',
        );
      } else if (node is PrefixedIdentifier) {
        // props.value -> widget
        // props.peek -> widget
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          'widget',
        );
      } else {
        // props -> widget
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          'widget',
        );
      }
    }
  }
}
