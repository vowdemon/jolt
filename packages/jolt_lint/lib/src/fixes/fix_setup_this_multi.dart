import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/add_props_replacer_visitor.dart';

class FixSetupThisMulti extends ResolvedCorrectionProducer {
  FixSetupThisMulti({required super.context});

  @override
  FixKind get fixKind => JoltFix.setupThisMulti;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Get the setup method from the current node
    final setupMethod = getAncestorSetupMethod(node);
    if (setupMethod == null) return;

    // Get the class element and instance members
    final classDeclaration = setupMethod
        .thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration == null) return;

    final classFragment = classDeclaration.declaredFragment;
    if (classFragment == null) return;

    final classElement = classFragment.element;
    final instanceMembers = <Element>{
      ...classElement.fields.where((e) => !e.isStatic),
      ...classElement.getters.where((e) => !e.isStatic),
      ...classElement.methods.where((e) => !e.isStatic),
      ...classElement.setters.where((e) => !e.isStatic),
      ...classElement.constructors.where((e) => !e.isStatic),
    };

    // Get the setup method body
    final body = setupMethod.body;

    // Use AddPropsReplacerVisitor to collect all nodes that need to be fixed
    final visitor = AddPropsReplacerVisitor(instanceMembers, classElement);
    body.accept(visitor);

    // Check if there are any fixes to apply (only show this fix when there are more than 1)
    final totalFixes =
        visitor.toReplaceWithProps.length +
        visitor.toInsertPropsBefore.length +
        visitor.toReplaceWithPropsPrefix.length;
    if (totalFixes <= 1) return;

    // Apply all fixes
    await builder.addDartFileEdit(file, (fileBuilder) {
      final propsName = _ensureSetupPropsName(setupMethod, fileBuilder);

      // Use AddPropsReplacerVisitor.applyReplacements to apply all fixes
      AddPropsReplacerVisitor.applyReplacements(
        fileBuilder,
        visitor,
        props: propsName,
      );
    });
  }

  String _ensureSetupPropsName(
    MethodDeclaration setupMethod,
    DartFileEditBuilder builder,
  ) {
    final propsParamName = setupMethod.parameters!.parameters[1].name!;
    var propsName = propsParamName.lexeme;

    if (propsName == '_') {
      builder.addSimpleReplacement(
        SourceRange(propsParamName.offset, propsParamName.length),
        'props',
      );
      propsName = 'props';
    }

    return propsName;
  }
}
