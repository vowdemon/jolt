import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/setup_usage_visitor.dart';

class SetupFinder extends SimpleAstVisitor<void> {
  final MultiAnalysisRule rule;

  final RuleContext context;

  SetupFinder(this.rule, this.context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.declaredFragment == null) return;
    final classFragment = node.declaredFragment!;
    final classElement = classFragment.element;
    if (!isSubtypeOfSetupWidget(classElement)) return;

    final instanceMembers = <Element>{
      ...classElement.fields.where((e) => !e.isStatic),
      ...classElement.getters.where((e) => !e.isStatic),
      ...classElement.methods.where((e) => !e.isStatic),
      ...classElement.setters.where((e) => !e.isStatic),
      ...classElement.constructors.where((e) => !e.isStatic),
    };
    MethodDeclaration? setupMethod;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        if (!member.isStatic && member.declaredFragment != null) {
          final method = member.declaredFragment!.element;
          if (method.name == 'setup') {
            setupMethod = member;
            break;
          }
        }
      }
    }

    if (instanceMembers.isEmpty || setupMethod == null) return;
    // final propsParameter = setupMethod.parameters?.parameterFragments
    //     .elementAtOrNull(1);
    // if (propsParameter == null) return;
    // final propsName = propsParameter.element.displayName;
    setupMethod.visitChildren(
      SetupUsageVisitor(
        instanceMembers: instanceMembers,
        classNode: node.declaredFragment!.element,
        rule: rule,
      ),
    );
  }
}
