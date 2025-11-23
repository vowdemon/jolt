import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import 'package:jolt_lint/src/shared.dart';
import 'package:jolt_lint/src/visitor/setup_finder_visitor.dart';

class NoSetupThisRule extends MultiAnalysisRule {
  NoSetupThisRule()
    : super(name: 'no_setup_this', description: 'No setup this');

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var finder = SetupFinder(this, context);

    registry.addClassDeclaration(this, finder);
  }

  @override
  List<DiagnosticCode> get diagnosticCodes => [
    JoltCode.setupThisExplicit,
    JoltCode.setupThisImplicit,
    JoltCode.setupThisAssign,
    JoltCode.setupThisAssignable,
  ];
}
