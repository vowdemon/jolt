import "dart:async";
import "dart:convert";
import "dart:developer" as developer;

import "package:jolt/core.dart";
import "package:meta/meta.dart";

/// Debug lifecycle operations emitted for reactive nodes.
enum DebugNodeOperationType {
  /// A reactive node was created.
  create,

  /// A reactive node was disposed.
  dispose,

  /// A reactive node's value was read.
  get,

  /// A reactive node's value was written.
  set,

  /// A reactive node notified subscribers without necessarily changing value.
  notify,

  /// An effect body finished a run.
  effect,
}

/// A debug callback for reactive node operations.
///
/// The [type] argument identifies the lifecycle event. The [node] argument is
/// the affected reactive node.
typedef JoltDebugFn = void Function(
    DebugNodeOperationType type, ReactiveNode node);

/// Debug metadata for labeling and instrumenting reactive nodes.
///
/// Pass instances to node constructors or combine options with
/// [JoltDebugOption.merge]. In debug builds, labels and types appear in
/// DevTools; [onDebug] receives per-node lifecycle callbacks.
final class JoltDebugOption {
  /// DevTools label shown for this node, if any.
  final String? debugLabel;

  /// DevTools category shown for this node, if any.
  final String? debugType;

  /// Callback invoked for each debug lifecycle event, if any.
  final JoltDebugFn? onDebug;

  const JoltDebugOption._({this.debugLabel, this.debugType, this.onDebug});

  /// Creates a debug option with only a debug type.
  ///
  /// The [debugType] is used to categorize nodes in DevTools.
  const JoltDebugOption.type(this.debugType)
      : debugLabel = null,
        onDebug = null;

  /// Creates a debug option with a label and/or custom debug callback.
  ///
  /// The optional [debugLabel] is shown in DevTools. The optional [onDebug]
  /// callback runs when debug operations occur for this node.
  const JoltDebugOption.of(this.debugLabel, this.onDebug) : debugType = null;

  /// Creates a debug option with only a label.
  ///
  /// The [debugLabel] is displayed in DevTools to help identify the node.
  const JoltDebugOption.label(this.debugLabel)
      : debugType = null,
        onDebug = null;

  /// Creates a debug option with only a custom debug callback.
  ///
  /// The [onDebug] callback will be invoked whenever a debug operation
  /// occurs for the node.
  const JoltDebugOption.fn(this.onDebug)
      : debugLabel = null,
        debugType = null;

  /// Merges two debug options, with [other] taking precedence over [base].
  ///
  /// Returns `null` when DevTools is disabled or both options are `null`.
  /// Otherwise, fields from [other] override the corresponding fields from
  /// [base].
  ///
  /// Example:
  /// ```dart
  /// final merged = JoltDebugOption.merge(
  ///   JoltDebugOption.label('count'),
  ///   JoltDebugOption.type('Signal'),
  /// );
  /// ```
  static JoltDebugOption? merge(JoltDebugOption? base, JoltDebugOption? other) {
    if (!JoltDevTools._enabled) return null;
    if (base == null && other == null) return null;
    return JoltDebugOption._(
      debugLabel: other?.debugLabel ?? base?.debugLabel,
      debugType: other?.debugType ?? base?.debugType,
      onDebug: other?.onDebug ?? base?.onDebug,
    );
  }
}

/// Debug entrypoints for Jolt DevTools integration.
///
/// Call [init] in debug builds to register the DevTools extensions used by the
/// reactive graph.
abstract final class JoltDebug {
  /// Initializes Jolt DevTools support.
  ///
  /// Call this function at app startup to enable DevTools inspection
  /// features. This function only has effect in debug mode and is
  /// a no-op in release mode.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   JoltDebug.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void init() {
    assert(() {
      developer.log('[Jolt DevTools] Initializing...');
      JoltDevTools._register();
      developer.log('[Jolt DevTools] Registration complete.');
      return true;
    }());
  }
}

final class _DebugInfo {
  _DebugInfo({
    required this.id,
    this.label,
    this.type,
    this.creationStack,
    required this.createdAt,
  });

  final int id;
  final String? label;
  final String? type;
  final StackTrace? creationStack;
  final int createdAt;
  int count = 0;
  int? updatedAt;
}

final Expando<_DebugInfo> _debugInfo = Expando<_DebugInfo>();

/// VM service extension hooks used by Jolt DevTools.
///
/// Most members on this type are internal. The public class exists so core
/// debugging support can expose a stable type from `package:jolt/core.dart`.
abstract final class JoltDevTools {
  static final Map<int, WeakReference<ReactiveNode>> _debugNodes = {};

  static int _nextNodeId = 0;

  static final _nodeFinalizer = Finalizer<int>((nodeId) {
    _notifyNodeDisposed(nodeId);
    _debugNodes.remove(nodeId);
  });

  static final _updateController =
      StreamController<Map<String, dynamic>>.broadcast();
  static bool _enabled = false;

  static void _register() {
    if (_enabled) return;
    _enabled = true;

    _updateController.stream.listen((update) {
      developer.postEvent('jolt.nodeUpdate', update);
    });

    developer.registerExtension(
      'ext.jolt.getNodes',
      (method, parameters) async {
        final nodes = _collectNodes();
        return developer.ServiceExtensionResponse.result(
          json.encode({'nodes': nodes}),
        );
      },
    );

    developer.registerExtension(
      'ext.jolt.getNodeDetails',
      (method, parameters) async {
        final nodeId = int.parse(parameters['nodeId']!);
        final details = _getNodeDetails(nodeId);
        return developer.ServiceExtensionResponse.result(
          json.encode(details),
        );
      },
    );

    developer.registerExtension(
      'ext.jolt.triggerEffect',
      (method, parameters) async {
        final nodeId = int.parse(parameters['nodeId']!);
        _triggerEffect(nodeId);
        return developer.ServiceExtensionResponse.result('{"success": true}');
      },
    );

    developer.registerExtension(
      'ext.jolt.streamUpdates',
      (method, parameters) async {
        return developer.ServiceExtensionResponse.result('{"streaming": true}');
      },
    );
  }

  @visibleForTesting
  @internal
  static List<Map<String, dynamic>> collectNodesForTesting() => _collectNodes();

  @visibleForTesting
  @internal
  static Stream<Map<String, dynamic>> get updatesForTesting =>
      _updateController.stream;

  @visibleForTesting
  @internal
  static Object? readRootValue(int nodeId) {
    final node = _debugNodes[nodeId]?.target;
    if (node == null) return null;

    return switch (node) {
      SignalNode() => node.pendingValue,
      ComputedNode() => node.peek(),
      _ => null,
    };
  }

  @visibleForTesting
  @internal
  static bool writeSignalValue(int nodeId, Object? value) {
    final node = _debugNodes[nodeId]?.target;
    if (node is! SignalNode) {
      return false;
    }
    node.set(value);
    return true;
  }

  /// Notifies DevTools about a node update.
  @internal
  static void notifyUpdate(int nodeId, String operation, dynamic value,
      [String? valueType, int? count, int? updatedAt]) {
    _updateController.add({
      'nodeId': nodeId,
      'operation': operation,
      'value': _serializeValue(value),
      ...valueType == null ? {} : {'valueType': valueType},
      ...count == null ? {} : {'count': count},
      'timestamp': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  @internal
  static void notifyLinkUpdate(
      String operation, ReactiveNode? dep, ReactiveNode? sub) {
    if (!_enabled || dep == null || sub == null) return;

    final depId = _debugInfo[dep]?.id;
    final subId = _debugInfo[sub]?.id;
    if (depId == null || subId == null) return;

    _updateController.add({
      'operation': operation,
      'depId': depId,
      'subId': subId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Handle node lifecycle events
  static void _handleNodeLifecycle(
      DebugNodeOperationType type, ReactiveNode node,
      {String? debugLabel, String? debugType}) {
    if (!_enabled) return;
    if (type == DebugNodeOperationType.create) {
      final int nodeId = _nextNodeId++;

      _debugNodes[nodeId] = WeakReference(node);

      // Use runtimeType as default debugType if not provided
      final effectiveDebugType = debugType ?? node.runtimeType.toString();

      final createdAt = DateTime.now().millisecondsSinceEpoch;
      _debugInfo[node] = _DebugInfo(
        id: nodeId,
        label: debugLabel,
        type: effectiveDebugType,
        creationStack: StackTrace.current,
        createdAt: createdAt,
      );

      _notifyNodeCreated(node, nodeId, createdAt);
      _nodeFinalizer.attach(node, nodeId, detach: node);
      return;
    }

    final info = _debugInfo[node];
    if (info == null) {
      return;
    }
    final nodeId = info.id;

    switch (type) {
      case DebugNodeOperationType.set:
        {
          final now = DateTime.now().millisecondsSinceEpoch;
          info.count++;
          info.updatedAt = now;
          notifyUpdate(nodeId, 'set', _getNodeValue(node),
              _getNodeValueType(node), info.count, now);
          break;
        }
      case DebugNodeOperationType.notify:
        {
          final now = DateTime.now().millisecondsSinceEpoch;
          info.count++;
          info.updatedAt = now;
          notifyUpdate(nodeId, 'notify', _getNodeValue(node),
              _getNodeValueType(node), info.count, now);
          break;
        }
      case DebugNodeOperationType.effect:
        {
          final now = DateTime.now().millisecondsSinceEpoch;
          info.count++;
          info.updatedAt = now;
          notifyUpdate(
              nodeId, 'effect', _getNodeValue(node), null, info.count, now);
          break;
        }
      case DebugNodeOperationType.dispose:
        _nodeFinalizer.detach(node);
        _notifyNodeDisposed(nodeId);
        _debugNodes.remove(nodeId);
        break;

      default:
    }
  }

  static void _notifyNodeCreated(ReactiveNode node, int nodeId, int createdAt) {
    _updateController.add({
      'operation': 'nodeCreated',
      'node': {
        'id': nodeId,
        'nodeType': _getNodeType(node),
        'label': _debugInfo[node]?.label ?? 'Unnamed',
        'type': _debugInfo[node]?.type ?? node.runtimeType.toString(),
        'flags': node.flags,
        'isDisposed': _isDisposed(node),
        'value': _getNodeValue(node),
        'valueType': _getNodeValueType(node),
        'dependencies': _getNodeDeps(node),
        'subscribers': _getNodeSubs(node),
        'createdAt': createdAt,
        'count': _debugInfo[node]!.count,
        'updatedAt': createdAt,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static void _notifyNodeDisposed(int nodeId) {
    _updateController.add({
      'operation': 'nodeDisposed',
      'nodeId': nodeId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Collect all nodes from debug registry
  static List<Map<String, dynamic>> _collectNodes() {
    final result = <Map<String, dynamic>>[];

    for (final entry in _debugNodes.entries) {
      final node = entry.value.target;
      if (node == null) continue; // Already GC'd

      final nodeType = _getNodeType(node);

      final info = _debugInfo[node];
      result.add({
        'id': entry.key,
        'nodeType': nodeType, // Use 'nodeType' instead of 'type'
        'label': info?.label ?? 'Unnamed',
        'type': info?.type ??
            node.runtimeType
                .toString(), // debugType (user-defined category, fallback to runtimeType)
        'flags': node.flags,
        'isDisposed': _isDisposed(node),
        'value': _getNodeValue(node),
        'valueType': _getNodeValueType(node),
        'dependencies': _getNodeDeps(node),
        'subscribers': _getNodeSubs(node),
        if (info != null) 'createdAt': info.createdAt,
        if (info != null) 'count': info.count,
        if (info != null) 'updatedAt': info.updatedAt ?? info.createdAt,
      });
    }

    return result;
  }

  static String _getNodeType(ReactiveNode node) {
    if (node is SignalNode) return 'Signal';
    if (node is ComputedNode) return 'Computed';
    if (node is EffectNode) return 'Effect';
    if (node is EffectScopeNode) return 'EffectScope';
    return 'Unknown';
  }

  static bool _isDisposed(ReactiveNode node) {
    return switch (node) {
      SignalNode() => node.isDisposed,
      ComputedNode() => node.isDisposed,
      EffectNode() => node.isDisposed,
      EffectScopeNode() => node.isDisposed,
      BaseEffectNode() => node.flags == ReactiveFlags.none,
      _ => node.flags == ReactiveFlags.none,
    };
  }

  static dynamic _getNodeValue(ReactiveNode node) {
    try {
      if (node is SignalNode) {
        return _serializeValue(node.pendingValue);
      } else if (node is ComputedNode) {
        return _serializeValue(node.value);
      }
      return null;
    } catch (e) {
      return '<error: $e>';
    }
  }

  static String _getNodeValueType(ReactiveNode node) {
    try {
      if (node is SignalNode) {
        return node.pendingValue.runtimeType.toString();
      } else if (node is ComputedNode) {
        return node.value.runtimeType.toString();
      }
      return 'Unknown';
    } catch (e) {
      return '<error: $e>';
    }
  }

  static Map<String, dynamic> _getNodeDetails(int nodeId) {
    final node = _debugNodes[nodeId]?.target;
    if (node == null) return {'error': 'Node not found or disposed'};

    return {
      'id': nodeId,
      'creationStack': _debugInfo[node]?.creationStack?.toString(),
    };
  }

  static List<int> _getNodeDeps(ReactiveNode node) {
    final deps = <int>{};
    var link = node.deps;
    while (link != null) {
      final dep = link.dep;
      final depId = dep != null ? _debugInfo[dep]?.id : null;
      if (depId != null) {
        deps.add(depId);
      }
      link = link.nextDep;
    }
    return deps.toList();
  }

  static List<int> _getNodeSubs(ReactiveNode node) {
    final subs = <int>{};
    var link = node.subs;
    while (link != null) {
      final sub = link.sub;
      final subId = sub != null ? _debugInfo[sub]?.id : null;
      if (subId != null) {
        subs.add(subId);
      }
      link = link.nextSub;
    }
    return subs.toList();
  }

  static void _triggerEffect(int nodeId) {
    final node = _debugNodes[nodeId]?.target;
    if (node == null) return;

    if (node is EffectNode) {
      node.run();
    } else {
      developer.log('Node $nodeId is not an Effect');
    }
  }

  static const int _maxSerializedValueLength = 500;

  static dynamic _serializeValue(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    if (value is List) {
      return value.map(_serializeValue).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _serializeValue(v)));
    }
    // For complex objects: type + truncated toString
    final s = value.toString();
    final truncated = s.length > _maxSerializedValueLength
        ? '${s.substring(0, _maxSerializedValueLength)}...'
        : s;
    return {'type': value.runtimeType.toString(), 'value': truncated};
  }

  static final _joltDebugFns = Expando<JoltDebugFn>();

  /// Sets a custom debug function for a specific target object.
  ///
  /// The [fn] callback will be invoked whenever a debug operation occurs
  /// for the [target] node. This allows per-node debugging customization.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void setDebug(Object target, JoltDebugFn? fn) {
    _joltDebugFns[target] = fn;
  }

  /// Gets the custom debug function for a specific target object.
  ///
  /// Returns `null` if no custom debug function has been set for [target].
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static JoltDebugFn? _getDebug(Object target) => _joltDebugFns[target];

  /// Notifies the debug system that a reactive node was created.
  ///
  /// This method should be called when a new reactive node is created.
  /// The [option] parameter can provide debug metadata such as labels,
  /// types, or custom debug callbacks.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void create(ReactiveNode target, JoltDebugOption? option) {
    // Call per-node debug function if provided
    if (option?.onDebug != null) {
      setDebug(target, option!.onDebug!);
      option.onDebug!.call(DebugNodeOperationType.create, target);
    }

    // Call global hook if available (for DevTools)
    JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.create, target,
        debugLabel: option?.debugLabel, debugType: option?.debugType);
  }

  /// Notifies the debug system that a reactive node was disposed.
  ///
  /// This method should be called when a reactive node is being disposed
  /// or cleaned up.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void dispose(ReactiveNode target) {
    _getDebug(target)?.call(DebugNodeOperationType.dispose, target);
    JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.dispose, target);
  }

  /// Notifies the debug system that a reactive node's value was accessed (get operation).
  ///
  /// This method should be called when the value of [target] is read.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void get(ReactiveNode target) {
    assert(() {
      _getDebug(target)?.call(DebugNodeOperationType.get, target);
      JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.get, target);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node's value was set (set operation).
  ///
  /// This method should be called when the value of [target] is written to.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void set(ReactiveNode target) {
    _getDebug(target)?.call(DebugNodeOperationType.set, target);
    JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.set, target);
  }

  /// Notifies the debug system that a reactive node notified its subscribers.
  ///
  /// This method should be called when [target] notifies its subscribers
  /// about a value change.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void notify(ReactiveNode target) {
    _getDebug(target)?.call(DebugNodeOperationType.notify, target);
    JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.notify, target);
  }

  /// Notifies the debug system that an effect was executed.
  ///
  /// This method should be called when an effect node [target] is executed.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void effect(ReactiveNode target) {
    _getDebug(target)?.call(DebugNodeOperationType.effect, target);
    JoltDevTools._handleNodeLifecycle(DebugNodeOperationType.effect, target);
  }
}
