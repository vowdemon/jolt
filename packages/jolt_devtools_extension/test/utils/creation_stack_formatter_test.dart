import 'package:jolt_devtools_extension/src/utils/creation_stack_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCreationStackForDisplay', () {
    test('returns original stack when no jolt frame is present', () {
      const rawStack = '''
#0      new AppState (package:example/main.dart:36:20)
#1      mount (package:flutter/src/widgets/framework.dart:7118:14)
''';

      expect(formatCreationStackForDisplay(rawStack), rawStack);
    });

    test('hides everything through the first contiguous jolt block', () {
      const rawStack = '''
#0      get current (dart-sdk/lib/_internal/js_dev_runtime/patch/core_patch.dart:749:28)
#1      handleNodeLifecycle (package:jolt/src/core/debug.dart:403:35)
#2      create (package:jolt/src/core/debug.dart:172:18)
#3      bootstrap (package:jolt_setup/src/bootstrap.dart:10:1)
#4      new AppState (package:example/main.dart:36:20)
#5      mount (package:flutter/src/widgets/framework.dart:7118:14)
''';

      expect(
        formatCreationStackForDisplay(rawStack),
        '''
#3      bootstrap (package:jolt_setup/src/bootstrap.dart:10:1)
#4      new AppState (package:example/main.dart:36:20)
#5      mount (package:flutter/src/widgets/framework.dart:7118:14)
'''
            .trim(),
      );
    });

    test('keeps non-jolt package frames after the first jolt block', () {
      const rawStack = '''
#0      get current (dart-sdk/lib/_internal/js_dev_runtime/patch/core_patch.dart:749:28)
#1      handleNodeLifecycle (package:jolt/src/core/debug.dart:403:35)
#2      bootstrap (package:jolt_setup/src/bootstrap.dart:10:1)
''';

      expect(
        formatCreationStackForDisplay(rawStack),
        '#2      bootstrap (package:jolt_setup/src/bootstrap.dart:10:1)',
      );
    });
  });
}
