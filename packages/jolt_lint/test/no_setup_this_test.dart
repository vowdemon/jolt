// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:jolt_lint/src/rules/no_setup_this.dart';
import 'package:jolt_lint/src/shared.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoSetupThisRuleTest);
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
      'name: jolt_setup\nversion: 0.0.1\n',
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
  }

  void _configurePackageConfig() {
    final config = PackageConfigFileBuilder()
      ..add(name: 'jolt_setup', rootPath: convertPath(_joltSetupRoot));

    writeTestPackageConfig(config);

    newPubspecYamlFile(testPackageRootPath, pubspecYamlContent(name: 'test'));
  }
}

@reflectiveTest
class NoSetupThisRuleTest extends JoltRuleTestBase {
  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(NoSetupThisRule());
    super.setUp();
  }

  @override
  String get analysisRule => 'no_setup_this';

  // ---- Report: bare instance field reference in setup ----
  Future<void> test_reports_instance_member() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  final int count = 0;

  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return count;
  }
}
''';
    final offset = code.indexOf('count;', code.indexOf('return'));
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, 'count'.length),
    ]);
  }

  // ---- Allow: local variables and props in setup ----
  Future<void> test_allows_local_and_props() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    final local = 1;
    final typedProps = props as Props;
    return local + typedProps.value;
  }
}

class Props {
  final int value;
  const Props(this.value);
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Report: this.field in setup ----
  Future<void> test_reports_this_property_access() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  final int count = 0;

  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return this.count;
  }
}
''';
    final offset = code.indexOf('this.count');
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, 'this.count'.length),
    ]);
  }

  // ---- Report: this.method() in setup ----
  Future<void> test_reports_this_method_invocation() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  int getValue() => 1;

  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return this.getValue();
  }
}
''';
    final offset = code.indexOf('this.getValue()');
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, 'this.getValue()'.length),
    ]);
  }

  // ---- Report: variable initialized with this ----
  Future<void> test_reports_variable_initialized_with_this() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    var that = this;
    return null;
  }
}
''';
    final target = 'that = this';
    final offset = code.indexOf(target);
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, target.length),
    ]);
  }

  // ---- Report: assignment with this on RHS ----
  Future<void> test_reports_assignment_with_this_rhs() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    Object? o;
    o = this;
    return null;
  }
}
''';
    const target = 'o = this';
    final offset = code.indexOf(target);
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, target.length),
    ]);
  }

  // ---- Ignore: class does not extend SetupWidget ----
  Future<void> test_ignores_non_setup_widget_class() async {
    final code = r'''
class Plain {
  final int count = 0;

  dynamic setup(dynamic context, dynamic props) {
    return count;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Allow: props parameter usage ----
  Future<void> test_allows_props_parameter() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return props;
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Report: instance getter reference in setup ----
  Future<void> test_reports_instance_getter() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  int get value => 0;

  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    return value;
  }
}
''';
    final offset = code.indexOf('value;', code.indexOf('return'));
    await assertDiagnostics(code, [
      error(JoltCode.setupThis, offset, 'value'.length),
    ]);
  }

  // ---- Allow: setup method with no instance member usage ----
  Future<void> test_allows_setup_with_only_locals() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class Counter extends SetupWidget {
  @override
  dynamic setup([BuildContext? context, dynamic props]) {
    final a = 1;
    final b = 2;
    return a + b;
  }
}
''';
    await assertNoDiagnostics(code);
  }
}
