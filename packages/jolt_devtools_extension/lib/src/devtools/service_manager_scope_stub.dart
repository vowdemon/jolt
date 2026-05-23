import 'package:devtools_app_shared/service.dart';

/// Unavailable on the VM test runner; DevTools globals exist only on web.
ServiceManager<Object?> get devtoolsServiceManager => throw StateError(
      'DevTools serviceManager is only available in the DevTools extension (web).',
    );
