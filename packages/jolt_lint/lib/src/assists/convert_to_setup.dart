// import 'dart:async';

// import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
// import 'package:analyzer/dart/analysis/results.dart';
// import 'package:analyzer/dart/ast/ast.dart';
// import 'package:analyzer/dart/element/type.dart';
// import 'package:analyzer/source/source_range.dart';
// import 'package:analyzer_plugin/utilities/assist/assist.dart';
// import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
// import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
// import 'package:jolt_lint/src/shared.dart';

// class ConvertStatelessWidgetToSetupAssist extends ResolvedCorrectionProducer {
//   ConvertStatelessWidgetToSetupAssist({required super.context});

//   @override
//   AssistKind get assistKind => JoltAssist.convertStatelessWidgetToSetup;

//   @override
//   CorrectionApplicability get applicability =>
//       CorrectionApplicability.singleLocation;

//   @override
//   Future<void> compute(ChangeBuilder builder) async {
//     if (node is! ClassDeclaration) return;

//     final clazzDeclaration = node as ClassDeclaration;
//     final clazz = clazzDeclaration.declaredFragment?.element;
//     if (clazz == null) return;

//     final statelessWidget = await sessionHelper.getFlutterClass(
//       'StatelessWidget',
//     );
//     if (statelessWidget == null) return;

//     if (!typeSystem.isSubtypeOf(clazz.thisType, statelessWidget.thisType)) {
//       return;
//     }
//   }
// }
