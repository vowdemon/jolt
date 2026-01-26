import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/service/jolt_service.dart';
import 'package:jolt_devtools_extension/src/utils/query_parser.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class SelectionReason {
  static const String listClick = 'list_click';
  static const String depJump = 'dep_jump';
  static const String search = 'search';
}

/// Controller that manages the state of the Jolt Inspector.
class JoltInspectorController {
  final joltService = JoltService(serviceManager);
  StreamSubscription? _updateSubscription;
  VoidCallback? _connectionListener;

  final $isConnected = Signal(false);
  final $isLoading = Signal(false);
  final $searchQuery = Signal('');
  final $selectedNodeId = Signal<int?>(null);
  final $nodes = MapSignal(<int, JoltNode>{});
  late final $selectedNode = Computed(() => $nodes[$selectedNodeId.value]);

  QueryExpression? _parsedQuery;
  String _parsedQuerySource = '';

  Timer? _refreshTimer;

  JoltInspectorController() {
    _checkConnection();
  }

  List<JoltNode> get filteredNodes => _buildFilteredNodes();

  void _checkConnection() {
    // Check if we have a VM service connection
    if (serviceManager.service != null) {
      $isConnected.value = true;

      loadNodes();
      _listenToUpdates();
    }

    _connectionListener = () {
      final connected = serviceManager.connectedState.value.connected;
      if ($isConnected.value != connected) {
        $isConnected.value = connected;

        if (connected) {
          loadNodes();
          _listenToUpdates();
        } else {
          _updateSubscription?.cancel();
        }
      }
    };
    serviceManager.connectedState.addListener(_connectionListener!);
  }

  Future<void> loadNodes() async {
    if (!$isConnected.value) return;

    $isLoading.value = true;

    try {
      final nodes = await joltService.getNodes();
      // Update existing nodes or add new ones, preserving reactive signals
      for (final node in nodes) {
        final existing = $nodes[node.id];
        if (existing != null) {
          // Update existing node's reactive properties
          batch(() {
            existing.value.value = node.value;
            existing.valueType.value = node.valueType;
            existing.flags.value = node.flags;
            existing.dependencies.value = node.dependencies;
            existing.subscribers.value = node.subscribers;
          });
        } else {
          $nodes[node.id] = JoltNode.fromDebugNode(node);
        }
      }
      // Remove nodes that no longer exist
      final existingIds = $nodes.keys.toSet();
      final newIds = nodes.map((n) => n.id).toSet();
      for (final id in existingIds) {
        if (!newIds.contains(id)) {
          $nodes.remove(id);
        }
      }
    } finally {
      $isLoading.value = false;
    }
  }

  void _listenToUpdates() {
    _updateSubscription?.cancel();

    // Start streaming
    joltService.startStreaming();

    _updateSubscription = joltService.updates.listen((update) {
      if (update.operation == 'nodeCreated') {
        if (update.node != null) {
          $nodes[update.node!.id] = update.node!;
        }
      } else if (update.operation == 'nodeDisposed') {
        if (update.nodeId != null) {
          final disposedNodeId = update.nodeId!;
          final disposedNode = $nodes[disposedNodeId];

          if (disposedNode != null) {
            batch(() {
              // Clean up subscribers in all dependencies of this node
              // Remove the disposed node from each dependency node's subscribers list
              for (final depId in disposedNode.dependencies.value) {
                final depNode = $nodes[depId];
                if (depNode != null) {
                  if (depNode.subscribers.value.contains(disposedNodeId)) {
                    depNode.subscribers.value = depNode.subscribers.value
                        .where((id) => id != disposedNodeId)
                        .toList();
                  }
                }
              }

              // Clean up dependencies in all subscribers of this node
              // Remove the disposed node from each subscriber node's dependencies list
              for (final subId in disposedNode.subscribers.value) {
                final subNode = $nodes[subId];
                if (subNode != null) {
                  if (subNode.dependencies.value.contains(disposedNodeId)) {
                    subNode.dependencies.value = subNode.dependencies.value
                        .where((id) => id != disposedNodeId)
                        .toList();
                  }
                }
              }
            });

            // Remove the node itself
            $nodes.remove(disposedNodeId);

            // Clear selection if this node was selected
            if ($selectedNodeId.value == disposedNodeId) {
              $selectedNodeId.value = null;
            }

            // Invalidate VM value cache for disposed node
            joltService.invalidateVmValueCache(disposedNodeId);
          }
        }
      } else if (update.operation == 'nodeUpdated') {
        // Node update (value, flags, dependencies, subscribers)
        final node = $nodes[update.nodeId];
        if (node != null) {
          batch(() {
            if (update.value != null) {
              final data = update.value as Map<String, dynamic>?;
              if (data != null) {
                if (data.containsKey('value')) {
                  node.value.value = data['value'];
                }
                if (data.containsKey('flags')) {
                  node.flags.value = data['flags'] as int;
                }
                if (data.containsKey('dependencies')) {
                  final deps =
                      (data['dependencies'] as List?)?.cast<int>() ?? [];
                  node.dependencies.value = deps;
                }
                if (data.containsKey('subscribers')) {
                  final subs =
                      (data['subscribers'] as List?)?.cast<int>() ?? [];
                  node.subscribers.value = subs;
                }
              }
            }
            if (update.valueType != null) {
              node.valueType.value = update.valueType!;
            }
          });

          // Invalidate VM value cache when node value is updated
          if (update.nodeId != null) {
            joltService.invalidateVmValueCache(update.nodeId!);
          }
        }
      } else if (update.operation == 'link' || update.operation == 'unlink') {
        // Handle link/unlink operations for dependencies and subscribers
        // depId: the dependency node (the node being depended on)
        // subId: the subscriber node (the node that depends on depId)
        final depId = update.depId;
        final subId = update.subId;

        if (depId != null && subId != null) {
          final depNode = $nodes[depId];
          final subNode = $nodes[subId];

          if (depNode != null && subNode != null) {
            batch(() {
              if (update.operation == 'link') {
                // Link: sub depends on dep
                // Add dep to sub's dependencies
                if (!subNode.dependencies.value.contains(depId)) {
                  subNode.dependencies.value = [
                    ...subNode.dependencies.value,
                    depId
                  ];
                }
                // Add sub to dep's subscribers
                if (!depNode.subscribers.value.contains(subId)) {
                  depNode.subscribers.value = [
                    ...depNode.subscribers.value,
                    subId
                  ];
                }
              } else if (update.operation == 'unlink') {
                // Unlink: sub no longer depends on dep
                // Remove dep from sub's dependencies
                if (subNode.dependencies.value.contains(depId)) {
                  subNode.dependencies.value = subNode.dependencies.value
                      .where((id) => id != depId)
                      .toList();
                }
                // Remove sub from dep's subscribers
                if (depNode.subscribers.value.contains(subId)) {
                  depNode.subscribers.value = depNode.subscribers.value
                      .where((id) => id != subId)
                      .toList();
                }
              }
            });
          }
        }
      } else {
        // Value update (legacy)
        final node = $nodes[update.nodeId];
        if (node != null) {
          batch(() {
            node.value.value = update.value;
            if (update.valueType != null) {
              node.valueType.value = update.valueType!;
            }
            if (update.value is Map) {
              final data = update.value as Map<String, dynamic>;
              if (data.containsKey('flags')) {
                node.flags.value = data['flags'] as int;
              }
              if (data.containsKey('dependencies')) {
                final deps = (data['dependencies'] as List?)?.cast<int>() ?? [];
                node.dependencies.value = deps;
              }
              if (data.containsKey('subscribers')) {
                final subs = (data['subscribers'] as List?)?.cast<int>() ?? [];
                node.subscribers.value = subs;
              }
            }
          });
        }
      }
    });
  }

  Future<bool> selectNode(
    int nodeId, {
    String? reason,
  }) async {
    $selectedNodeId.value = nodeId;

    final node = $nodes[nodeId];
    if (node == null) {
      return false;
    }

    if (node.creationStack.value == null) {
      final creationStack = await joltService.getCreationStack(nodeId);
      node.creationStack.value = creationStack;
    }

    return true;
  }

  void setFilter(String value) {
    setSearchQuery(value);
  }

  void setSearchQuery(String value) {
    $searchQuery.value = value;
    _parseQuery();
  }

  void closeNodeDetails() {
    $selectedNodeId.value = null;
  }

  String formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is Map && value.containsKey('type')) {
      return value['value'].toString();
    }
    if (value is String && value.length > 50) {
      return '${value.substring(0, 50)}...';
    }
    return value.toString();
  }

  List<JoltNode> _buildFilteredNodes() {
    _parseQuery();
    final now = DateTime.now();
    final filtered = $nodes.values.where((node) {
      if (!_matchesQuery(node, now)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final comparison = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      if (comparison != 0) {
        return comparison;
      }
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  void _parseQuery() {
    if (_parsedQuerySource == $searchQuery.value) {
      return;
    }
    _parsedQuerySource = $searchQuery.value;
    _parsedQuery = _buildQueryExpression($searchQuery.value);
  }

  bool _matchesQuery(JoltNode node, DateTime now) {
    if (_parsedQuery == null) {
      return true;
    }
    return _parsedQuery!.evaluate(node, now);
  }

  QueryExpression? _buildQueryExpression(String raw) {
    return buildQueryExpression(raw, _QueryMatcherImpl(this));
  }

  bool _matchesFreeText(JoltNode node, String term) {
    final query = term.toLowerCase();
    if (node.label.toLowerCase().contains(query)) return true;
    if (node.type.toLowerCase().contains(query)) return true;
    if ((node.debugType).toLowerCase().contains(query)) return true;
    return node.id.toString().contains(query);
  }

  bool _matchesKeyPredicate(
    JoltNode node,
    DateTime now,
    String key,
    String value,
  ) {
    switch (key) {
      case 'type':
        return _matchesType(node, value);
      case 'debug':
        return _matchesDebugType(node, value);
      case 'label':
        return _matchesLabel(node, value);
      case 'valuetype':
        return _matchesValueType(node, value);
      case 'id':
        return _matchesNumeric(node.id, value);
      case 'deps':
        return _matchesNumeric(node.dependencies.length, value);
      case 'subs':
        return _matchesNumeric(node.subscribers.length, value);
      case 'has':
        return _matchesHas(node, value);
      case 'value':
        return _matchesValue(node, value);

      default:
        return _matchesFreeText(node, '$key:$value');
    }
  }

  bool _matchesType(JoltNode node, String value) {
    final nodeType = node.type.toLowerCase();
    return nodeType == value.toLowerCase();
  }

  /// Match string values with multiple matching modes (case-insensitive)
  /// - Default: fuzzy match (contains)
  /// - ==xxx: exact match
  /// - ^=xxx: match prefix (startsWith)
  /// - $=xxx: match suffix (endsWith)
  bool _matchesString(String target, String value) {
    if (target.isEmpty) {
      return false;
    }

    final lowerTarget = target.toLowerCase();
    final lowerValue = value.toLowerCase();

    // Exact match: ==xxx
    if (value.startsWith('==')) {
      final exactValue = value.substring(2);
      return lowerTarget == exactValue.toLowerCase();
    }

    // Match prefix: ^=xxx
    if (value.startsWith('^=')) {
      final prefix = value.substring(2);
      return lowerTarget.startsWith(prefix.toLowerCase());
    }

    // Match suffix: $=xxx
    if (value.startsWith(r'$=')) {
      final suffix = value.substring(2);
      return lowerTarget.endsWith(suffix.toLowerCase());
    }

    // Default fuzzy match (contains)
    return lowerTarget.contains(lowerValue);
  }

  bool _matchesDebugType(JoltNode node, String value) {
    final debugType = node.debugType;
    if (debugType.isEmpty) {
      return false;
    }
    return _matchesString(debugType, value);
  }

  bool _matchesValueType(JoltNode node, String value) {
    final valueType = node.valueType.value;
    if (valueType.isEmpty) {
      return false;
    }
    return _matchesString(valueType, value);
  }

  bool _matchesLabel(JoltNode node, String value) {
    return _matchesString(node.label, value);
  }

  bool _matchesNumeric(int actual, String value) {
    final match = RegExp(r'^(<=|>=|<|>)(\d+)$').firstMatch(value);
    if (match != null) {
      final op = match.group(1)!;
      final target = int.tryParse(match.group(2) ?? '');
      if (target == null) {
        return false;
      }
      switch (op) {
        case '<':
          return actual < target;
        case '>':
          return actual > target;
        case '<=':
          return actual <= target;
        case '>=':
          return actual >= target;
        default:
          return false;
      }
    }
    final target = int.tryParse(value);
    if (target == null) {
      return false;
    }
    return actual == target;
  }

  bool _matchesHas(JoltNode node, String value) {
    if (value.toLowerCase() == 'label') {
      return node.label.isNotEmpty && node.label != 'Unnamed';
    }
    return false;
  }

  bool _matchesValue(JoltNode node, String value) {
    final val = node.value.value;
    if (val == null) {
      return false;
    }
    final raw = val.toString();
    return raw.toLowerCase().contains(value.toLowerCase());
  }

  bool _matchesDep(JoltNode node, String condition) {
    if (node.dependencies.isEmpty) {
      return false;
    }

    // Get dependencies directly from node (real-time)
    final deps = node.dependencies.value;
    if (deps.isEmpty) {
      return false;
    }

    // Parse condition like "id:2" or "id=2"
    final parts = condition.split(':');
    if (parts.length != 2) {
      // Try numeric format like "id=2"
      final numericMatch =
          RegExp(r'^([a-zA-Z_]+)([<>=]+)(.+)$').firstMatch(condition);
      if (numericMatch != null) {
        final field = numericMatch.group(1)!.toLowerCase();
        final op = numericMatch.group(2)!;
        final valueStr = numericMatch.group(3)!;
        if (field == 'id') {
          final targetId = int.tryParse(valueStr);
          if (targetId == null) return false;
          if (op == '=') {
            return deps.contains(targetId);
          }
          // For other operators, check if any dependency matches
          return deps.any((depId) {
            final depNode = $nodes[depId];
            return depNode != null &&
                _matchesNumeric(depNode.id, '$op$valueStr');
          });
        }
      }
      return false;
    }

    final field = parts[0].toLowerCase();
    final value = parts[1];

    if (field == 'id') {
      final targetId = int.tryParse(value);
      if (targetId == null) return false;
      return deps.contains(targetId);
    }

    // For other fields, check if any dependency matches
    return deps.any((depId) {
      final depNode = $nodes[depId];
      if (depNode == null) return false;
      return _matchesKeyPredicate(depNode, DateTime.now(), field, value);
    });
  }

  bool _matchesSub(JoltNode node, String condition) {
    if (node.subscribers.isEmpty) {
      return false;
    }

    // Get subscribers directly from node (real-time)
    final subs = node.subscribers.value;
    if (subs.isEmpty) {
      return false;
    }

    // Parse condition like "id:2" or "id=2"
    final parts = condition.split(':');
    if (parts.length != 2) {
      // Try numeric format like "id=2"
      final numericMatch =
          RegExp(r'^([a-zA-Z_]+)([<>=]+)(.+)$').firstMatch(condition);
      if (numericMatch != null) {
        final field = numericMatch.group(1)!.toLowerCase();
        final op = numericMatch.group(2)!;
        final valueStr = numericMatch.group(3)!;
        if (field == 'id') {
          final targetId = int.tryParse(valueStr);
          if (targetId == null) return false;
          if (op == '=') {
            return subs.contains(targetId);
          }
          // For other operators, check if any subscriber matches
          return subs.any((subId) {
            final subNode = $nodes[subId];
            return subNode != null &&
                _matchesNumeric(subNode.id, '$op$valueStr');
          });
        }
      }
      return false;
    }

    final field = parts[0].toLowerCase();
    final value = parts[1];

    if (field == 'id') {
      final targetId = int.tryParse(value);
      if (targetId == null) return false;
      return subs.contains(targetId);
    }

    // For other fields, check if any subscriber matches
    return subs.any((subId) {
      final subNode = $nodes[subId];
      if (subNode == null) return false;
      return _matchesKeyPredicate(subNode, DateTime.now(), field, value);
    });
  }

  void dispose() {
    _updateSubscription?.cancel();
    _refreshTimer?.cancel();
    if (_connectionListener != null) {
      serviceManager.connectedState.removeListener(_connectionListener!);
    }
  }
}

/// Implementation of QueryMatcher for JoltInspectorController
class _QueryMatcherImpl implements QueryMatcher {
  final JoltInspectorController controller;

  _QueryMatcherImpl(this.controller);

  @override
  bool matchesFreeText(JoltNode node, String term) {
    return controller._matchesFreeText(node, term);
  }

  @override
  bool matchesKeyPredicate(
      JoltNode node, DateTime now, String key, String value) {
    return controller._matchesKeyPredicate(node, now, key, value);
  }

  @override
  bool matchesNumeric(int actual, String value) {
    return controller._matchesNumeric(actual, value);
  }

  @override
  bool matchesDep(JoltNode node, String condition) {
    return controller._matchesDep(node, condition);
  }

  @override
  bool matchesSub(JoltNode node, String condition) {
    return controller._matchesSub(node, condition);
  }
}
