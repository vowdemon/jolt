/// Jolt lint tool for reactive state management.
///
/// This package provides lint rules, quick fixes, and code assists
/// for the Jolt reactive state management ecosystem.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:jolt_lint/src/assists/convert_stateless_from_setup_widget.dart';
import 'package:jolt_lint/src/assists/convert_from_signal.dart';
import 'package:jolt_lint/src/assists/convert_stateful_to_setup_mixin.dart';
import 'package:jolt_lint/src/assists/convert_stateful_from_setup_mixin.dart';
import 'package:jolt_lint/src/assists/convert_stateless_to_setup_widget.dart';
import 'package:jolt_lint/src/assists/convert_to_signal.dart';
import 'package:jolt_lint/src/assists/wrap_builder.dart';
import 'package:jolt_lint/src/fixes/fix_setup_this.dart';
import 'package:jolt_lint/src/rules/no_mutable_collection_value_operation.dart';
import 'package:jolt_lint/src/rules/no_setup_this.dart';
import 'package:jolt_lint/src/shared.dart';

/// JoltLint plugin instance.
///
/// This is the main entry point for the Jolt lint tool. The analyzer
/// will automatically discover and use this plugin when the package
/// is added to `analysis_options.yaml`.
final plugin = JoltLintPlugin();

/// JoltLint plugin implementation.
///
/// Provides lint rules, quick fixes, and code assists for the Jolt
/// reactive state management ecosystem.
class JoltLintPlugin extends Plugin {
  /// Registers all lint rules, fixes, and assists with the analyzer.
  ///
  /// This method is called automatically by the analyzer when the plugin
  /// is loaded. It registers:
  /// - The `no_setup_this` rule to prevent accessing instance members
  ///   directly in setup methods
  /// - Quick fixes for setup method violations
  /// - Code assists for wrapping widgets and converting signals
  @override
  void register(PluginRegistry registry) {
    // Register diagnostics, quick fixes, and assists.
    registry.registerWarningRule(NoSetupThisRule());
    registry.registerWarningRule(NoMutableCollectionValueOperationRule());
    registry.registerFixForRule(
      JoltCode.setupThisExplicit,
      FixSetupThisExplicit.new,
    );
    registry.registerFixForRule(
      JoltCode.setupThisImplicit,
      FixSetupThisImplicit.new,
    );
    registry.registerFixForRule(
      JoltCode.setupThisAssign,
      FixSetupThisAssign.new,
    );
    registry.registerFixForRule(
      JoltCode.setupThisAssignable,
      FixSetupThisAssignable.new,
    );

    registry.registerAssist(WrapBuilderAssist.joltBuilder);
    registry.registerAssist(WrapBuilderAssist.joltSelector);
    registry.registerAssist(WrapBuilderAssist.setupBuilder);

    registry.registerAssist(ConvertToSignalAssist.new);
    registry.registerAssist(ConvertFromSignalAssist.new);
    registry.registerAssist(ConvertStatelessWidgetToSetupWidgetAssist.new);
    registry.registerAssist(ConvertStatelessWidgetFromSetupWidgetAssist.new);
    registry.registerAssist(ConvertStatefulToSetupMixinAssist.new);
    registry.registerAssist(ConvertStatefulFromSetupMixinAssist.new);
  }

  /// The name of this plugin.
  ///
  /// Used by the analyzer to identify this plugin in diagnostics and logs.
  @override
  String get name => 'JoltLint';
}
