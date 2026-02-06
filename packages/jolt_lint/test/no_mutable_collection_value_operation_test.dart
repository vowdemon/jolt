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

abstract class IMutableCollection {}
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

  // ---- Report: method invocation on .value (e.g. .add, .clear) ----
  Future<void> test_reports_method_on_value() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
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

  Future<void> test_reports_clear_on_value() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  void run() {
    mutable.value.clear();
  }
}
''';
    const target = 'mutable.value.clear()';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  // ---- Report: property access on .value (e.g. .length) ----
  Future<void> test_reports_property_access_on_value() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  int get size => mutable.value.length;
}
''';
    const target = 'mutable.value.length';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  // ---- Ignore: this.value (receiver is this) ----
  Future<void> test_ignores_direct_this_value() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Example extends MutableCollection<List<int>> {
  Example() : super([]);
  void run() {
    this.value.add(1);
  }
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Ignore: type does not implement IMutableCollection ----
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

  // ---- Report: chained .value access (a.b.value.method) ----
  Future<void> test_reports_chained_value_then_method() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Holder {
  final mutable = MutableCollection<List<int>>([]);
}

class Example {
  final holder = Holder();

  void run() {
    holder.mutable.value.add(1);
  }
}
''';
    const target = 'holder.mutable.value.add(1)';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  // ---- Report: .get() then method (receiver is .get() result) ----
  Future<void> test_reports_get_then_method() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
  T get(int index) => value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  void run() {
    mutable.get(0).add(1);
  }
}
''';
    const target = 'mutable.get(0).add(1)';
    await assertDiagnostics(code, [lint(code.indexOf(target), target.length)]);
  }

  // ---- Ignore: bare .value read (no further property/method on value) ----
  Future<void> test_ignores_bare_value_read() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  List<int> get list => mutable.value;
}
''';
    await assertNoDiagnostics(code);
  }

  // ---- Multiple reports in same unit ----
  Future<void> test_reports_multiple_operations() async {
    final code = r'''
import 'package:jolt_setup/src/setup/framework.dart';

class MutableCollection<T> implements IMutableCollection {
  MutableCollection(this.value);
  T value;
}

class Example {
  final mutable = MutableCollection<List<int>>([]);

  void run() {
    mutable.value.add(1);
    mutable.value.clear();
  }
}
''';
    final addExpr = 'mutable.value.add(1)';
    final clearExpr = 'mutable.value.clear()';
    await assertDiagnostics(code, [
      lint(code.indexOf(addExpr), addExpr.length),
      lint(code.indexOf(clearExpr), clearExpr.length),
    ]);
  }
}
