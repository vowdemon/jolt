import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:jolt_lint/src/assists/convert_from_signal.dart';
import 'package:jolt_lint/src/assists/convert_to_signal.dart';
import 'package:jolt_lint/src/assists/wrap_builder.dart';
import 'package:jolt_lint/src/fixes/fix_setup_this.dart';
import 'package:jolt_lint/src/rules/no_setup_this.dart';
import 'package:jolt_lint/src/shared.dart';

/// JoltLint plugin instance.
final plugin = JoltLintPlugin();

/// JoltLint plugin implementation.
class JoltLintPlugin extends Plugin {
  @override
  void register(PluginRegistry registry) {
    // Register diagnostics, quick fixes, and assists.
    registry.registerWarningRule(NoSetupThisRule());
    registry.registerFixForRule(
      JoltCode.setupThisExplict,
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
    registry.registerAssist(WrapBuilderAssist.joltProvider);
    registry.registerAssist(WrapBuilderAssist.joltSelector);
    registry.registerAssist(WrapBuilderAssist.setupBuilder);

    registry.registerAssist(ConvertToSignalAssist.new);
    registry.registerAssist(ConvertFromSignalAssist.new);
  }

  @override
  String get name => 'JoltLint';
}
