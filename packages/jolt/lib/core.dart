/// Core reactive system APIs for advanced usage.
///
/// This library exposes the low-level reactive system APIs including
/// reactive nodes, dependency tracking, and the global reactive system.
/// These APIs are typically used by framework implementers or for
/// advanced reactive programming scenarios.
library;

export 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

export 'src/core/reactive.dart';
export 'src/core/interface.dart';
export 'src/core/node.dart';
export 'src/core/debug.dart';
export 'src/core/utils.dart';

export "src/jolt/impl/effect.dart";
export "src/jolt/impl/effect_scope.dart";
export "src/jolt/impl/watcher.dart";
export "src/jolt/impl/signal.dart";
export "src/jolt/impl/readonly.dart";
export "src/jolt/impl/computed.dart";
export "src/jolt/impl/async.dart";
