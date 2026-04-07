import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_inspector_policy.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_child.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_inspector_service.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_value_tree.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class JoltValueInspectorRoot extends StatefulWidget {
  const JoltValueInspectorRoot({
    super.key,
    required this.node,
    required this.service,
  });

  final JoltNode node;
  final JoltValueInspectorService service;

  @override
  State<JoltValueInspectorRoot> createState() => _JoltValueInspectorRootState();
}

class _JoltValueInspectorRootState extends State<JoltValueInspectorRoot> {
  late JoltValuePath _rootPath;
  JoltInspectedValue? _rootValue;
  String? _rootError;
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  int _reloadGeneration = 0;
  JoltValueInspectorPolicy _policy = const JoltValueInspectorPolicy();
  final Set<JoltValuePath> _expandedPaths = {};
  final Map<JoltValuePath, List<JoltValueChild>> _childrenByPath = {};
  JoltValuePath? _editingPath;
  FlutterEffect? _effect;

  @override
  void initState() {
    super.initState();
    _rootPath = JoltValuePath.root(nodeId: widget.node.id);
    _expandedPaths.add(_rootPath);
    _bindNodeEffect();
  }

  @override
  void didUpdateWidget(covariant JoltValueInspectorRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id ||
        !identical(oldWidget.node, widget.node)) {
      _rootPath = JoltValuePath.root(nodeId: widget.node.id);
      _expandedPaths
        ..clear()
        ..add(_rootPath);
      _childrenByPath.clear();
      _editingPath = null;
      _effect?.dispose();
      _bindNodeEffect();
      _reloadAll(showLoading: true);
    }
  }

  @override
  void dispose() {
    _effect?.dispose();
    _effect = null;
    super.dispose();
  }

  void _bindNodeEffect() {
    _effect = FlutterEffect(() {
      widget.node.value.value;
      widget.node.updatedAt.value;
      widget.node.count.value;
      _reloadAll(showLoading: !_hasLoadedOnce);
    });
  }

  Future<void> _reloadAll({bool showLoading = false}) async {
    final generation = ++_reloadGeneration;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _rootError = null;
      });
    } else if (_rootError != null) {
      setState(() {
        _rootError = null;
      });
    }

    try {
      final resolution = await widget.service.inspectRoot(
        widget.node,
        policy: _policy,
      );
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      final rootValue = resolution?.value;
      setState(() {
        _rootValue = rootValue;
        _rootError = null;
        _hasLoadedOnce = true;
      });
      final refreshResult = await _loadExpandedChildren(
        generation: generation,
        rootValue: rootValue,
      );
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _rootValue = rootValue;
        _rootError = null;
        _childrenByPath
          ..clear()
          ..addAll(refreshResult.childrenByPath);
        _expandedPaths
          ..clear()
          ..addAll(refreshResult.expandedPaths);
        _hasLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      if (_rootValue == null) {
        setState(() {
          _rootError = error.toString();
        });
      }
    } finally {
      if (showLoading && mounted && generation == _reloadGeneration) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<_RefreshTreeResult> _loadExpandedChildren({
    required int generation,
    required JoltInspectedValue? rootValue,
  }) async {
    final nextChildren = <JoltValuePath, List<JoltValueChild>>{};
    final nextExpandedPaths = <JoltValuePath>{_rootPath};
    if (_canKeepExpandedPath(rootValue)) {
      await _refreshExpandedBranch(
        path: _rootPath,
        value: rootValue!,
        generation: generation,
        childrenByPath: nextChildren,
        expandedPaths: nextExpandedPaths,
        isRoot: true,
      );
    }
    return _RefreshTreeResult(
      childrenByPath: nextChildren,
      expandedPaths: nextExpandedPaths,
    );
  }

  Future<bool> _refreshExpandedBranch({
    required JoltValuePath path,
    required JoltInspectedValue value,
    required int generation,
    required Map<JoltValuePath, List<JoltValueChild>> childrenByPath,
    required Set<JoltValuePath> expandedPaths,
    bool isRoot = false,
  }) async {
    if (!mounted || generation != _reloadGeneration) {
      return false;
    }

    if (!_canKeepExpandedPath(value)) {
      return false;
    }

    final rows = await _safeListChildren(path);
    if (!mounted || generation != _reloadGeneration) {
      return false;
    }
    if (rows == null) {
      return false;
    }
    if (!isRoot && _shouldFallbackFromChildren(rows)) {
      return false;
    }

    childrenByPath[path] = rows;
    expandedPaths.add(path);

    for (final row in rows) {
      if (!_expandedPaths.contains(row.path)) {
        continue;
      }

      final childValue = await _safeInspect(row.path);
      if (!mounted || generation != _reloadGeneration) {
        return false;
      }
      if (childValue == null) {
        continue;
      }

      _patchChildValue(
        parentPath: path,
        childPath: row.path,
        nextValue: childValue,
        childrenByPath: childrenByPath,
      );

      if (!_canKeepExpandedPath(childValue)) {
        continue;
      }

      await _refreshExpandedBranch(
        path: row.path,
        value: childValue,
        generation: generation,
        childrenByPath: childrenByPath,
        expandedPaths: expandedPaths,
      );
    }

    return true;
  }

  bool _canKeepExpandedPath(JoltInspectedValue? value) {
    return value != null &&
        value.isExpandable &&
        value.state == JoltInspectedValueState.available;
  }

  bool _shouldFallbackFromChildren(List<JoltValueChild> rows) {
    if (rows.isEmpty) {
      return false;
    }
    return rows.every(
      (row) => row.value.state != JoltInspectedValueState.available,
    );
  }

  Future<List<JoltValueChild>?> _safeListChildren(JoltValuePath path) async {
    try {
      return await widget.service.listChildren(path, policy: _policy);
    } catch (_) {
      return null;
    }
  }

  Future<JoltInspectedValue?> _safeInspect(JoltValuePath path) async {
    try {
      return await widget.service.inspect(path, policy: _policy);
    } catch (_) {
      return null;
    }
  }

  void _patchChildValue({
    required JoltValuePath parentPath,
    required JoltValuePath childPath,
    required JoltInspectedValue nextValue,
    required Map<JoltValuePath, List<JoltValueChild>> childrenByPath,
  }) {
    final rows = childrenByPath[parentPath];
    if (rows == null) {
      return;
    }
    childrenByPath[parentPath] = [
      for (final row in rows)
        if (row.path == childPath) row.copyWithValue(nextValue) else row,
    ];
  }

  Future<void> _toggleExpanded(JoltValuePath path) async {
    if (_editingPath == path) {
      setState(() {
        _editingPath = null;
      });
      return;
    }

    if (_expandedPaths.contains(path)) {
      setState(() {
        _expandedPaths.remove(path);
      });
      return;
    }

    setState(() {
      _expandedPaths.add(path);
    });
    final rows = await widget.service.listChildren(path, policy: _policy);
    if (!mounted) {
      return;
    }
    setState(() {
      _childrenByPath[path] = rows;
    });
  }

  Future<void> _refresh() async {
    await widget.service.refreshRoot(_rootPath);
    await _reloadAll(showLoading: false);
  }

  Future<void> _refreshPath(JoltValuePath path) async {
    await widget.service.refreshRoot(path);
    await _reloadAll(showLoading: false);
  }

  Future<void> _submitEdit(String value) async {
    if (_editingPath == null) {
      return;
    }
    await widget.service.writeValue(widget.node, _editingPath!, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _editingPath = null;
    });
    await _reloadAll(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final rootValue = _rootValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Info'),
              selected: _policy.showObjectProperties,
              onSelected: (selected) async {
                setState(() {
                  _policy = JoltValueInspectorPolicy(
                    showPrivateMembers: _policy.showPrivateMembers,
                    showGetters: _policy.showGetters,
                    showObjectProperties: selected,
                    showHashCodeAndRuntimeType:
                        _policy.showHashCodeAndRuntimeType,
                  );
                });
                await _reloadAll(showLoading: false);
              },
            ),
            FilterChip(
              label: const Text('Private'),
              selected: _policy.showPrivateMembers,
              onSelected: (selected) async {
                setState(() {
                  _policy = JoltValueInspectorPolicy(
                    showPrivateMembers: selected,
                    showGetters: _policy.showGetters,
                    showObjectProperties: _policy.showObjectProperties,
                    showHashCodeAndRuntimeType:
                        _policy.showHashCodeAndRuntimeType,
                  );
                });
                await _reloadAll(showLoading: false);
              },
            ),
            FilterChip(
              label: const Text('Getter'),
              selected: _policy.showGetters,
              onSelected: (selected) async {
                setState(() {
                  _policy = JoltValueInspectorPolicy(
                    showPrivateMembers: _policy.showPrivateMembers,
                    showGetters: selected,
                    showObjectProperties: _policy.showObjectProperties,
                    showHashCodeAndRuntimeType:
                        _policy.showHashCodeAndRuntimeType,
                  );
                });
                await _reloadAll(showLoading: false);
              },
            ),
            FilterChip(
              label: const Text('Object'),
              selected: _policy.showHashCodeAndRuntimeType,
              onSelected: (selected) async {
                setState(() {
                  _policy = JoltValueInspectorPolicy(
                    showPrivateMembers: _policy.showPrivateMembers,
                    showGetters: _policy.showGetters,
                    showObjectProperties: _policy.showObjectProperties,
                    showHashCodeAndRuntimeType: selected,
                  );
                });
                await _reloadAll(showLoading: false);
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh VM value',
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Loading...'),
          )
        else if (_rootError != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _rootError!,
              style: TextStyle(color: Colors.red.shade300),
            ),
          )
        else if (rootValue != null)
          JoltValueTree(
            path: _rootPath,
            label: null,
            value: rootValue,
            depth: 0,
            expandedPaths: _expandedPaths,
            childrenByPath: _childrenByPath,
            onToggle: (path) => _toggleExpanded(path),
            onRefreshPath: (path) => _refreshPath(path),
            onEdit: rootValue.setter != null
                ? () {
                    setState(() {
                      _editingPath =
                          _editingPath == _rootPath ? null : _rootPath;
                    });
                  }
                : null,
            onSubmitEdit: rootValue.setter != null ? _submitEdit : null,
            editingPath: _editingPath,
            showObjectProperties: _policy.showObjectProperties,
          )
        else
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Unavailable'),
          ),
      ],
    );
  }
}

class _RefreshTreeResult {
  const _RefreshTreeResult({
    required this.childrenByPath,
    required this.expandedPaths,
  });

  final Map<JoltValuePath, List<JoltValueChild>> childrenByPath;
  final Set<JoltValuePath> expandedPaths;
}
