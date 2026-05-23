// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:jolt_lint/src/rules/no_mutable_collection_value_operation.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoMutableCollectionValueOperationRuleTest);
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

mixin ListSignalMixin {}
mixin MapSignalMixin {}
mixin SetSignalMixin {}
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
class NoMutableCollectionValueOperationRuleTest extends JoltRuleTestBase {
  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(
      NoMutableCollectionValueOperationRule(),
    );
    super.setUp();
  }

  @override
  String get analysisRule => 'no_mutable_collection_value_operation';

  Future<void> test_reports_method_on_value() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> with ListSignalMixin {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  void run() {
    mutable.value.add(1);
  }
}
''';
    const target = 'mutable.value.add(1)';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  Future<void> test_reports_map_mixin() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> with MapSignalMixin {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<Map<String, int>>(<String, int>{});

  int get size => mutable.value.length;
}
''';
    const target = 'mutable.value.length';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  Future<void> test_reports_set_mixin() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> with SetSignalMixin {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<Set<int>>({});

  int get size => mutable.value.length;
}
''';
    const target = 'mutable.value.length';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  Future<void> test_ignores_non_mutable_collection_type() async {
    final code = r'''
class PlainContainer<T> {
  PlainContainer(this.value);
  T value;
}

class Example {
  final container = PlainContainer<List<int>>([]);

  void run() {
    container.value.add(1);
  }
}
''';
    await assertNoDiagnostics(code);
  }
}
