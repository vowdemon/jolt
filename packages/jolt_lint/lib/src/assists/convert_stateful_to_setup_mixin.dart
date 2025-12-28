import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:jolt_lint/src/shared.dart';

class ConvertStatefulToSetupMixinAssist extends ResolvedCorrectionProducer {
  ConvertStatefulToSetupMixinAssist({required super.context});

  @override
  AssistKind get assistKind => JoltAssist.convertStatefulToSetupMixin;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final statefullDeclaration = getStatefullDeclaration(node, unit);
    if (statefullDeclaration == null) return;
    final stateClassDeclaration = statefullDeclaration.stateClassDeclaration;
    final widgetClssDeclaration = statefullDeclaration.widgetClassDeclaration;

    if (isWithSetupMixin(widgetClssDeclaration.declaredFragment!.element)) {
      return;
    }

    final widgetClassName = widgetClssDeclaration.name.lexeme;

    // Find the build method
    final buildMethod = getMethodDeclarationByNameAndParametersCount(
      stateClassDeclaration,
      name: 'build',
      parametersCount: 1,
      isAsync: false,
    );
    if (buildMethod == null) return;

    // Convert build method to setup method and add SetupMixin
    await builder.addDartFileEdit(file, (builder) {
      // 1. Add import for SetupMixin
      importSetup(builder);

      // 2. Add SetupMixin to the class
      addMixinClass(
        builder,
        stateClassDeclaration,
        'SetupMixin<$widgetClassName>',
      );

      // 3. Convert build method to setup method in SetupMixin
      convertBuildToSetupInSetupMixin(unitResult, builder, buildMethod);
    });
  }
}

void convertBuildToSetupInSetupMixin(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
  MethodDeclaration buildMethod,
) {
  final methodName = buildMethod.name;

  builder.addSimpleReplacement(
    SourceRange(methodName.offset, methodName.length),
    'setup',
  );
  if (buildMethod.returnType != null) {
    builder.addSimpleReplacement(
      SourceRange(
        buildMethod.returnType!.offset,
        buildMethod.returnType!.length + 1,
      ),
      '',
    );
  }

  convertBuildBodyToSetupBody(unitResult, builder, buildMethod);
}

void convertBuildBodyToSetupBody(
  ParsedUnitResult unitResult,
  DartFileEditBuilder builder,
  MethodDeclaration buildMethod,
) {
  final body = buildMethod.body;
  if (body is BlockFunctionBody) {
    // fn(...) { return Widget; } -> fn(...) { return () { return Widget; }; }
    final blockBody = body;

    builder.addInsertion(blockBody.block.leftBracket.offset, (edit) {
      edit.writeln('{');
      edit.write(edit.getIndent(2));
      edit.write('return () ');
    });

    builder.addInsertion(blockBody.block.rightBracket.end, (edit) {
      edit.writeln(';');
      edit.write(edit.getIndent(1));
      edit.write('}');
    });

    addIndentToLines(
      unitResult,
      builder,
      startOffset: blockBody.block.beginToken.offset,
      endOffset: blockBody.block.endToken.offset,
      indent: 1,
    );

    // builder.addSimpleInsertion(blockBody.block.rightBracket.offset, '};\n');
  } else if (body is ExpressionFunctionBody) {
    // fn(...) => Widget; -> fn(...) { return ()=> Widget; }
    final expressionBody = body;

    builder.addInsertion(expressionBody.beginToken.offset, (edit) {
      edit.writeln('{');
      edit.write(edit.getIndent(2));
      edit.write('return () ');
    });

    builder.addInsertion(expressionBody.endToken.end, (edit) {
      edit.writeln();
      edit.write(edit.getIndent(1));
      edit.write('}');
    });
  }
}

ReturnStatement? getBlockFunctionBodyReturnStatement(BlockFunctionBody body) {
  final statements = body.block.statements;
  for (final statement in statements) {
    if (statement is ReturnStatement) {
      return statement;
    }
  }
  return null;
}
