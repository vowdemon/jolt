// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:jolt_lint/src/rules/no_invalid_hook_call.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoInvalidHookCallRuleTest);
  });
}

abstract class JoltRuleTestBase extends AnalysisRuleTest {
  late final String _joltSetupRoot;

  @override
  void setUp() {
    super.setUp();
    _writeJoltSetupPackage();
    _configurePackageConfig();
  }

  void _writeJoltSetupPackage() {
    final path = resourceProvider.pathContext;
    _joltSetupRoot = path.join(path.dirname(testPackageRootPath), 'jolt_setup');

    newFile(
      path.join(_joltSetupRoot, 'pubspec.yaml'),
      'name: jolt_setup\nversion: ^0.0.1\n',
    );

    newFile(
      path.join(_joltSetupRoot, 'lib', 'src', 'setup', 'framework.dart'),
      r'''
library jolt_setup.src.setup.framework;

class BuildContext {}

class SetupWidget {
  const SetupWidget();
  dynamic setup([BuildContext? context, dynamic props]) => null;
}

mixin SetupMixin {}
''',
    );

    newFile(path.join(_joltSetupRoot, 'lib', 'src', 'annotation.dart'), r'''
library jolt_setup.src.annotation;

class DefineHook {
  const DefineHook();
}
''');
  }

  void _configurePackageConfig() {
    final config = PackageConfigFileBuilder()
      ..add(name: 'jolt_setup', rootPath: convertPath(_joltSetupRoot));

    writeTestPackageConfig(config);

    newPubspecYamlFile(testPackageRootPath, pubspecYamlContent(name: 'test'));
  }
}

@reflectiveTest
class NoInvalidHookCallRuleTest extends JoltRuleTestBase {
  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NoInvalidHookCallRule());
    super.setUp();
  }

  @override
  String get analysisRule => 'no_invalid_hook_call';

  // ---- Non-hook calls are ignored (no @DefineHook, not treated as hook) ----
  Future<void> test_ignores_non_hook_function_call() async {
    final code = r'''
void useCount() {}

void main() {
  useCount();
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Reject hook calls in invalid places: top-level / main ----
  Future<void> test_rejects_top_level_call() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
void useCount() {}

void main() {
  useCount();
}
''';
    final offset = code.indexOf('useCount();', code.indexOf('main'));
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  // ---- Allow inside setup method body (not in return expression) ----
  Future<void> test_allows_inside_setup_method_body() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    useCount();
    return null;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Reject inside setup return expression ----
  Future<void> test_rejects_inside_setup_return_expression() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
int useCount() => 0;

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return useCount();
  }
}
''';
    final offset = code.indexOf('return useCount()') + 'return '.length;
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  Future<void> test_rejects_inside_setup_arrow_return_expression() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
int useCount() => 0;

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) => useCount();
}
''';
    final offset = code.indexOf('=> useCount()') + '=> '.length;
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  // ---- Reject inside regular method (not setup, no DefineHook) ----
  Future<void> test_rejects_inside_regular_method() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) => null;

  void otherMethod() {
    useCount();
  }
}
''';
    final offset = code.indexOf('useCount();', code.indexOf('otherMethod'));
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  // ---- Reject inside regular function (no DefineHook) ----
  Future<void> test_rejects_inside_regular_function() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
void useCount() {}

void regularFunction() {
  useCount();
}
''';
    final offset = code.indexOf('useCount();');
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  // ---- Allow inside @DefineHook function declaration ----
  Future<void> test_allows_inside_define_hook_function_declaration() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

@DefineHook()
void useBar() {
  useCount();
}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    useBar();
    return null;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Allow inside @DefineHook variable (function expression) ----
  Future<void> test_allows_inside_define_hook_variable_callback() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    @DefineHook()
    final useFoo = () {
      useCount();
      return 0;
    };
    useFoo();
    return null;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Allow inside setup: named argument callback body (not in return) ----
  Future<void> test_allows_inside_setup_named_argument_body() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
void useCount() {}

class Config {
  Config({required void Function() setup});
}

void main() {
  Config(
    setup: () {
      useCount();
      return;
    },
  );
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Reject inside setup: named argument return expression ----
  Future<void> test_rejects_inside_setup_named_argument_return() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
int useCount() => 0;

class Config {
  Config({required dynamic Function() setup});
}

void main() {
  Config(
    setup: () {
      return useCount();
    },
  );
}
''';
    final setupStart = code.indexOf('setup: ()');
    final offset =
        code.indexOf('return useCount()', setupStart) + 'return '.length;
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  Future<void> test_rejects_inside_setup_named_argument_arrow_return() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
int useCount() => 0;

class Config {
  Config({required dynamic Function() setup});
}

void main() {
  Config(setup: () => useCount());
}
''';
    final offset = code.indexOf('() => useCount()') + '() => '.length;
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, 'useCount()'.length),
    ]);
  }

  // ---- FunctionExpressionInvocation: (useCount)() form ----
  Future<void>
  test_rejects_function_expression_invocation_at_top_level() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';

@DefineHook()
void useCount() {}

void main() {
  (useCount)();
}
''';
    final offset = code.indexOf('(useCount)()');
    await assertDiagnostics(code, [
      error(JoltCode.invalidHookCall, offset, '(useCount)()'.length),
    ]);
  }

  Future<void> test_allows_function_expression_invocation_in_setup() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    (useCount)();
    return null;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Allow multiple hooks in setup ----
  Future<void> test_allows_multiple_hooks_in_setup() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

@DefineHook()
void useFlag() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    useCount();
    useFlag();
    return null;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- When setup has no return, entire body counts as non-return ----
  Future<void> test_allows_setup_without_return_statement() async {
    final code = r'''
import 'package:jolt_setup/src/annotation.dart';
import 'package:jolt_setup/src/setup/framework.dart';

@DefineHook()
void useCount() {}

class MyWidget extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    useCount();
  }
}
''';
    await assertNoDiagnostics(code);
  }
}
