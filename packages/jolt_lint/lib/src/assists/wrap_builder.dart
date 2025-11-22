import 'dart:async';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';

class WrapBuilderAssist extends ResolvedCorrectionProducer {
  WrapBuilderAssist({
    required super.context,
    required this.builder,
    required this.assistKind,
  });

  final FutureOr<void> Function(
    DartFileEditBuilder,
    AstNode,
    ResolvedUnitResult,
  ) builder;

  @override
  final AssistKind assistKind;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final expression = findFullChainExpression(node);
    if (expression != null && isSubtypeOfWidgetByType(expression.staticType)) {
      await builder.addDartFileEdit(file, (builder) {
        this.builder(builder, expression, unitResult);
      });
      return;
    }

    final switchExpression = node.thisOrAncestorOfType<SwitchExpression>();
    if (switchExpression != null &&
        isSubtypeOfWidgetByType(switchExpression.staticType)) {
      await builder.addDartFileEdit(file, (builder) {
        this.builder(builder, switchExpression, unitResult);
      });
      return;
    }

    // [Obj.widget(...)], [(){ return widget}(...)], [widget(...)]
    final invocation = node.thisOrAncestorOfType<InvocationExpression>();
    if (invocation != null) {
      final invokeType = invocation.staticInvokeType;
      if (invokeType is FunctionType &&
          isSubtypeOfWidgetByType(invokeType.returnType)) {
        if (isSubtypeOfWidgetByType((invokeType.returnType))) {
          await builder.addDartFileEdit(file, (builder) {
            this.builder(builder, invocation, unitResult);
          });
        }
      }
      return;
    }

    // [Widget(...)]
    final instanceCreation =
        node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (instanceCreation != null) {
      final clazz = instanceCreation.constructorName.element?.enclosingElement;
      if (clazz != null) {
        if (!isSubtypeOfWidget(clazz)) return;
        await builder.addDartFileEdit(file, (builder) {
          this.builder(builder, instanceCreation, unitResult);
        });
      }
      return;
    }
  }

  factory WrapBuilderAssist.joltBuilder({
    required CorrectionProducerContext context,
  }) =>
      WrapBuilderAssist(
        context: context,
        builder: _wrapJoltBuilder,
        assistKind: JoltAssist.wrapJoltBuilder,
      );

  factory WrapBuilderAssist.joltProvider({
    required CorrectionProducerContext context,
  }) =>
      WrapBuilderAssist(
        context: context,
        builder: _wrapJoltProviderBuilder,
        assistKind: JoltAssist.wrapJoltProvider,
      );

  factory WrapBuilderAssist.joltSelector({
    required CorrectionProducerContext context,
  }) =>
      WrapBuilderAssist(
        context: context,
        builder: _wrapJoltSelectorBuilder,
        assistKind: JoltAssist.wrapJoltSelector,
      );

  factory WrapBuilderAssist.setupBuilder({
    required CorrectionProducerContext context,
  }) =>
      WrapBuilderAssist(
        context: context,
        builder: _wrapSetupBuilder,
        assistKind: JoltAssist.wrapSetupBuilder,
      );
}

void _wrapJoltBuilder(
  DartFileEditBuilder builder,
  AstNode node,
  ResolvedUnitResult unitResult,
) {
  final content = unitResult.content.substring(node.offset, node.end);
  builder.importLibrary(Uri.parse(joltFlutterUri));
  builder.addSimpleReplacement(
    SourceRange(node.offset, node.length),
    'JoltBuilder(builder: (context) => $content)',
  );
}

void _wrapJoltProviderBuilder(
  DartFileEditBuilder builder,
  AstNode node,
  ResolvedUnitResult unitResult,
) {
  final content = unitResult.content.substring(node.offset, node.end);
  builder.importLibrary(Uri.parse(joltFlutterUri));
  builder.addReplacement(SourceRange(node.offset, node.length), (edit) {
    edit.write('JoltProvider(');
    edit.write('create: (context) => ');
    edit.addSimpleLinkedEdit('CREATE_EXPR', 'null');
    edit.write(', ');
    edit.write('builder: (context, ');
    edit.addSimpleLinkedEdit('STATE_NAME', 'provider');
    edit.write(') => $content');
    edit.write(')');
  });
}

void _wrapJoltSelectorBuilder(
  DartFileEditBuilder builder,
  AstNode node,
  ResolvedUnitResult unitResult,
) {
  final content = unitResult.content.substring(node.offset, node.end);
  builder.importLibrary(Uri.parse(joltFlutterUri));
  builder.addReplacement(SourceRange(node.offset, node.length), (edit) {
    edit.write('JoltSelector(');
    edit.write('selector: (prev) => ');
    edit.addSimpleLinkedEdit('SELECTOR_EXPR', 'null');

    edit.write(', ');

    edit.write('builder: (context, ');
    edit.addSimpleLinkedEdit('STATE_NAME', 'state');
    edit.write(') => ');
    edit.write(content);
    edit.write(')');
  });
}

void _wrapSetupBuilder(
  DartFileEditBuilder builder,
  AstNode node,
  ResolvedUnitResult unitResult,
) {
  final content = unitResult.content.substring(node.offset, node.end);
  builder.importLibrary(Uri.parse(joltFlutterSetupUri));
  builder.addSimpleReplacement(
    SourceRange(node.offset, node.length),
    'SetupBuilder(setup: (context) { return ()=> $content})',
  );
}
