import "dart:async";
import "dart:convert";
import "dart:developer" as developer;

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:meta/meta.dart";

/// Types of operations that can be debugged in the reactive system.
///
/// This enum defines the different lifecycle events and operations
/// that can be tracked for debugging reactive nodes.
enum DebugNodeOperationType {
  /// Node was created.
  create,

  /// Node was disposed.
  dispose,

  /// Node was linked to a dependency.
  linked,

  /// Node was unlinked from a dependency.
  unlinked,

  /// Node value was accessed (get operation).
  get,

  /// Node value was set (set operation).
  set,

  /// Node notified its subscribers.
  notify,

  /// Effect was executed.
  effect,
}

/// Function type for debugging reactive system operations.
///
/// This callback is invoked whenever a debug operation occurs,
/// allowing you to track the lifecycle and behavior of reactive nodes.
///
/// Parameters:
/// - [type]: The type of operation that occurred
/// - [node]: The reactive node involved in the operation
/// - [link]: Optional link information, provided when the operation
///   is related to dependency linking/unlinking
typedef JoltDebugFn = void Function(
    DebugNodeOperationType type, ReactiveNode node, Link? link);

/// Debug options for reactive nodes.
///
/// This class provides various ways to configure debugging behavior
/// for reactive nodes, including labels, types, and custom debug callbacks.
final class JoltDebugOption {
  final String? debugLabel;
  final String? debugType;
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
  /// - [debugLabel]: An optional label for the node in DevTools
  /// - [onDebug]: An optional callback function that will be called
  ///   when debug operations occur for this node
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
  /// Returns `null` if DevTools is not enabled or both options are `null`.
  /// When merging, values from [other] are preferred over [base].
  static JoltDebugOption? merge(JoltDebugOption? base, JoltDebugOption? other) {
    if (!JoltDevTools.enabled) return null;
    if (base == null && other == null) return null;
    return JoltDebugOption._(
      debugLabel: other?.debugLabel ?? base?.debugLabel,
      debugType: other?.debugType ?? base?.debugType,
      onDebug: other?.onDebug ?? base?.onDebug,
    );
  }
}

/// Static utility class for debugging reactive nodes.
///
/// This class provides methods to track and debug the lifecycle and
/// operations of reactive nodes in the Jolt reactive system.
/// All methods are no-ops in release mode and only active in debug mode.
abstract final class JoltDebug {
  static final joltDebugFns = Expando<JoltDebugFn>();

  /// Sets a custom debug function for a specific target object.
  ///
  /// The [fn] callback will be invoked whenever a debug operation occurs
  /// for the [target] node. This allows per-node debugging customization.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void setDebug(Object target, JoltDebugFn fn) {
    joltDebugFns[target] = fn;
  }

  /// Gets the custom debug function for a specific target object.
  ///
  /// Returns `null` if no custom debug function has been set for [target].
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static JoltDebugFn? getDebug(Object target) => joltDebugFns[target];

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
      JoltDevTools.register();
      developer.log('[Jolt DevTools] Registration complete.');
      return true;
    }());
  }

  /// Notifies the debug system that a reactive node was created.
  ///
  /// This method should be called when a new reactive node is created.
  /// The [option] parameter can provide debug metadata such as labels,
  /// types, or custom debug callbacks.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void create(ReactiveNode target, JoltDebugOption? option) {
    assert(() {
      // Call per-node debug function if provided
      if (option?.onDebug != null) {
        setDebug(target, option!.onDebug!);
        option.onDebug!.call(DebugNodeOperationType.create, target, null);
      }

      // Call global hook if available (for DevTools)
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.create, target,
          debugLabel: option?.debugLabel, debugType: option?.debugType);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node was disposed.
  ///
  /// This method should be called when a reactive node is being disposed
  /// or cleaned up.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void dispose(ReactiveNode target) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.dispose, target, null);
      // Also call global hook if available
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.dispose, target);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node was linked to a dependency.
  ///
  /// This method should be called when a dependency relationship is established
  /// between [target] and another node via [link].
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void linked(ReactiveNode target, Link link) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.linked, target, link);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.linked, target,
          link: link);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node was unlinked from a dependency.
  ///
  /// This method should be called when a dependency relationship is removed
  /// between [target] and another node via [link].
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void unlinked(ReactiveNode target, Link link) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.unlinked, target, link);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.unlinked, target,
          link: link);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node's value was accessed (get operation).
  ///
  /// This method should be called when the value of [target] is read.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void get(ReactiveNode target) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.get, target, null);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.get, target);
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
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.set, target, null);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.set, target);
      return true;
    }(), "");
  }

  /// Notifies the debug system that a reactive node notified its subscribers.
  ///
  /// This method should be called when [target] notifies its subscribers
  /// about a value change.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void notify(ReactiveNode target) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.notify, target, null);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.notify, target);
      return true;
    }(), "");
  }

  /// Notifies the debug system that an effect was executed.
  ///
  /// This method should be called when an effect node [target] is executed.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static void effect(ReactiveNode target) {
    assert(() {
      getDebug(target)?.call(DebugNodeOperationType.effect, target, null);
      JoltDevTools.handleNodeLifecycle(DebugNodeOperationType.effect, target);
      return true;
    }(), "");
  }
}

/// Global registry of all reactive nodes for DevTools inspection.
/// Only active in debug mode. Uses WeakReference to avoid memory leaks.
@internal
final Map<int, WeakReference<ReactiveNode>> debugNodes = {};

/// Monotonically increasing ID counter for reactive nodes.
@internal
int nextNodeId = 0;

/// Debug information for a reactive node.
///
/// Stores debugging metadata for reactive nodes, including a unique ID,
/// optional label and type, and the stack trace from when the node was created.
@internal
final class DebugInfo {
  DebugInfo({
    required this.id,
    this.label,
    this.type,
    this.creationStack,
    required this.createdAt,
    this.count = 0,
    this.updatedAt,
  });

  /// Unique identifier for the node.
  final int id;

  /// Optional user-defined label for the node.
  final String? label;

  /// Optional user-defined type/category for the node.
  final String? type;

  /// Stack trace from when the node was created.
  final StackTrace? creationStack;

  /// When the node was created (ms since epoch).
  final int createdAt;

  /// For Signal/Computed = number of set/notify; for Effect = run count.
  int count;

  /// When the node was last updated (set/notify/effect), ms since epoch.
  int? updatedAt;
}

/// Expando for storing node debug information.
@internal
final Expando<DebugInfo> debugInfo = Expando<DebugInfo>();

/// Service extension for DevTools integration.
///
/// This class registers VM Service extensions that allow DevTools
/// to inspect and debug reactive nodes in a Jolt application.
@internal
abstract final class JoltDevTools {
  static final _updateController =
      StreamController<Map<String, dynamic>>.broadcast();
  static bool _enabled = false;
  static bool get enabled => _enabled;

  static void register() {
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

  // Handle node lifecycle events
  static void handleNodeLifecycle(
      DebugNodeOperationType type, ReactiveNode node,
      {String? debugLabel, String? debugType, Link? link}) {
    if (!_enabled) return;
    if (type == DebugNodeOperationType.create) {
      final int nodeId = nextNodeId++;

      debugNodes[nodeId] = WeakReference(node);

      // Use runtimeType as default debugType if not provided
      final effectiveDebugType = debugType ?? node.runtimeType.toString();

      final createdAt = DateTime.now().millisecondsSinceEpoch;
      debugInfo[node] = DebugInfo(
        id: nodeId,
        label: debugLabel,
        type: effectiveDebugType,
        creationStack: StackTrace.current,
        createdAt: createdAt,
      );

      _notifyNodeCreated(node, nodeId, createdAt);
      JFinalizer.attachToJoltAttachments(node, () {
        _notifyNodeDisposed(nodeId);
        debugNodes.remove(nodeId);
      });
      return;
    }

    final info = debugInfo[node];
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
        _notifyNodeDisposed(nodeId);
        break;
      case DebugNodeOperationType.linked:
        if (link != null) {
          _notifyLinkUpdate(link, 'link');
        }
        break;
      case DebugNodeOperationType.unlinked:
        if (link != null) {
          _notifyLinkUpdate(link, 'unlink');
        }
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
        'label': debugInfo[node]?.label ?? 'Unnamed',
        'type': debugInfo[node]?.type ?? node.runtimeType.toString(),
        'flags': node.flags,
        'isDisposed': _isDisposed(node),
        'value': _getNodeValue(node),
        'valueType': _getNodeValueType(node),
        'dependencies': _getNodeDeps(node),
        'subscribers': _getNodeSubs(node),
        'createdAt': createdAt,
        'count': debugInfo[node]!.count,
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

  static void _notifyLinkUpdate(Link link, String operation) {
    // Get IDs for both nodes involved in the link
    final depInfo = debugInfo[link.dep];
    final subInfo = debugInfo[link.sub];

    final depId = depInfo?.id;
    final subId = subInfo?.id;

    _updateController.add({
      'operation': operation,
      'depId': depId,
      'subId': subId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Collect all nodes from debug registry
  static List<Map<String, dynamic>> _collectNodes() {
    final result = <Map<String, dynamic>>[];

    for (final entry in debugNodes.entries) {
      final node = entry.value.target;
      if (node == null) continue; // Already GC'd

      final nodeType = _getNodeType(node);

      final info = debugInfo[node];
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
    if (node is WritableNode) return 'Signal';
    if (node is ReadableNode) return 'Computed';
    if (node is Watcher) return 'Watcher';
    if (node is Effect) return 'Effect';
    if (node is EffectScope) return 'EffectScope';
    if (node is EffectNode) return 'Effect';
    return 'Unknown';
  }

  static bool _isDisposed(ReactiveNode node) {
    try {
      // Check if node has isDisposed property (duck typing)
      return (node as dynamic).isDisposed == true;
    } catch (e) {
      return false;
    }
  }

  static dynamic _getNodeValue(ReactiveNode node) {
    try {
      if (node is SignalReactiveNode) {
        return _serializeValue(node.pendingValue);
      } else if (node is ComputedReactiveNode) {
        return _serializeValue(node.pendingValue);
      }
      return null;
    } catch (e) {
      return '<error: $e>';
    }
  }

  static String _getNodeValueType(ReactiveNode node) {
    try {
      if (node is SignalReactiveNode) {
        return node.pendingValue.runtimeType.toString();
      } else if (node is ComputedReactiveNode) {
        return node.pendingValue.runtimeType.toString();
      }
      return 'Unknown';
    } catch (e) {
      return '<error: $e>';
    }
  }

  static Map<String, dynamic> _getNodeDetails(int nodeId) {
    final node = debugNodes[nodeId]?.target;
    if (node == null) return {'error': 'Node not found or disposed'};

    return {
      'id': nodeId,
      'creationStack': debugInfo[node]?.creationStack?.toString(),
    };
  }

  static List<int> _getNodeDeps(ReactiveNode node) {
    final deps = <int>{};
    var link = node.deps;
    while (link != null) {
      final depId = debugInfo[link.dep]?.id;
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
      final subId = debugInfo[link.sub]?.id;
      if (subId != null) {
        subs.add(subId);
      }
      link = link.nextSub;
    }
    return subs.toList();
  }

  static void _triggerEffect(int nodeId) {
    final node = debugNodes[nodeId]?.target;
    if (node == null) return;

    if (node is! EffectNode) {
      developer.log('Node $nodeId is not an Effect');
    }

    switch (node) {
      case Effect effect:
        effect.run();
        break;
      case Watcher watcher:
        watcher.run();
        break;
      default:
        try {
          (node as dynamic).trigger();
        } catch (_) {
          try {
            (node as dynamic).run();
          } catch (_) {
            developer.log('Error triggering effect: $node');
          }
        }
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
}
