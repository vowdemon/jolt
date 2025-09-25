import 'dart:convert';
import 'dart:developer' as developer;

import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

import 'jolt/observer.dart';

class DebugJoltObserver implements IJoltObserver {
  DebugJoltObserver() {
    initDeveloper();
  }

  static final _nodes = <String, Map<String, dynamic>>{};
  static final _nodesRefs = <String, WeakReference<Object?>>{};

  void initDeveloper() {
    developer.registerExtension(
      'ext.jolt.getAllNodes',
      (method, parameters) async {
        return developer.ServiceExtensionResponse.result(jsonEncode(_nodes));
      },
    );
  }

  String _getType(Object node) {
    if (node is EffectBaseNode) {
      if (node is Effect) {
        return 'Effect()';
      }
      if (node is Watcher) {
        return 'Watcher()';
      }
      if (node is EffectScope) {
        return 'EffectScope()';
      }
      return 'UnknownEffect()';
    }
    if (node is WritableComputed) {
      return 'WritableComputed()';
    }
    if (node is Computed) {
      return 'Computed()';
    }
    if (node is Signal) {
      return 'Signal()';
    }
    if (node is ReadonlySignal) {
      return 'ReadonlySignal()';
    }
    return 'Unknown()';
  }

  void _createNode(ReactiveNode obj) {
    final ref = WeakReference(obj);
    _nodesRefs[ref.hashCode.toString()] = ref;
    _nodes[ref.hashCode.toString()] = {
      "readonly": obj is! JWritableValue,
      "type": _getType(obj),
      "runtimeType": obj.runtimeType.toString(),
      "value": obj is JReadonlyValue ? obj.value.toString() : 'null',
      "deps": [],
      "subs": [],
    };
  }

  void _updateNode(ReactiveNode obj) {
    final node = _nodes[obj.hashCode.toString()];
    node!['value'] = obj is JReadonlyValue ? obj.value.toString() : 'null';
    final deps = [];
    final subs = [];
    var dep = obj.deps;
    if (obj.deps != null) {}
    while (dep != null) {
      deps.add(dep.hashCode.toString());
      dep = dep.nextDep;
    }
    var sub = obj.subs;
    if (obj.subs != null) {
      while (sub != null) {
        subs.add(sub.hashCode.toString());
        sub = sub.nextSub;
      }
    }
    node['deps'] = deps;
    node['subs'] = subs;

    if (developer.extensionStreamHasListener) {
      developer.postEvent('ext.jolt.updateNode', {
        'node': node,
      });
    }
  }

  @override
  void onComputedCreated(Computed source) {
    print('Computed created: ${source.value}');
    _createNode(source);
  }

  @override
  void onComputedUpdated(Computed source, Object? newValue, Object? oldValue) {
    print('Computed updated: $oldValue -> $newValue');
  }

  @override
  void onComputedNotified(Computed source) {
    print('Computed notified: ${source.value}');
  }

  @override
  void onComputedDisposed(Computed source) {
    print('Computed disposed: ${source.value}');
  }

  @override
  void onEffectCreated(Effect source) {
    print('Effect created: ${source.runtimeType}');
    _createNode(source);
  }

  @override
  void onEffectTriggered(Effect source) {
    print('Effect triggered: ${source.runtimeType}');
  }

  @override
  void onEffectDisposed(Effect source) {
    print('Effect disposed: ${source.runtimeType}');
  }

  @override
  void onEffectScopeCreated(EffectScope source) {
    print('Effect scope created: ${source.runtimeType}');
    _createNode(source);
  }

  @override
  void onEffectScopeDisposed(EffectScope source) {
    print('Effect scope disposed: ${source.runtimeType}');
  }

  @override
  void onSignalCreated(Signal source) {
    print('Signal created: ${source.value}');
    _createNode(source);
  }

  @override
  void onSignalUpdated(Signal source, Object? newValue, Object? oldValue) {
    print('Signal updated: $oldValue -> $newValue');
  }

  @override
  void onSignalNotified(Signal source) {
    print('Signal notified: ${source.value}');
  }

  @override
  void onSignalDisposed(Signal source) {
    print('Signal disposed: ${source.value}');
  }

  @override
  void onWatcherCreated(Watcher source) {
    print('Watcher created: ${source.runtimeType}');
    _createNode(source);
  }

  @override
  void onWatcherTriggered(Watcher source) {
    print('Watcher triggered: ${source.runtimeType}');
  }

  @override
  void onWatcherDisposed(Watcher source) {
    print('Watcher disposed: ${source.runtimeType}');
  }
}
