import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/filter_autocomplete.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';

import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';
import 'package:provider/provider.dart';

/// Widget that displays a list of nodes with filtering capabilities.
class NodesListPanel extends StatefulWidget {
  const NodesListPanel({
    super.key,
  });

  @override
  State<NodesListPanel> createState() => _NodesListPanelState();
}

class _NodesListPanelState extends State<NodesListPanel>
    with SetupMixin<NodesListPanel> {
  late JoltInspectorController controller;

  // @override
  // void didUpdateWidget(covariant NodesListPanel oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (controller.searchQuery != _searchController.text) {
  //     _searchController.text = controller.searchQuery;
  //     _searchController.selection = TextSelection.collapsed(
  //       offset: _searchController.text.length,
  //     );
  //   }
  // }

  @override
  setup(BuildContext context) {
    controller = context.read<JoltInspectorController>();
    final searchController =
        useTextEditingController(text: controller.$searchQuery.value);
    final autocompleteOpen = useSignal(false);
    final highlightedSuggestionIndex = useSignal(0);
    useWatcher(
      () => [
        controller.$globalFilterEnabled.value,
        controller.$globalFilterQuery.value,
      ],
      (_, __) => setState(() {}),
    );

    int caretOffset() {
      final offset = searchController.selection.baseOffset;
      if (offset < 0 || offset > searchController.text.length) {
        return searchController.text.length;
      }
      return offset;
    }

    List<FilterAutocompleteSuggestion> currentSuggestions() {
      return controller.filterAutocompleteSuggestions(
        searchController.text,
        caretOffset(),
      );
    }

    void applySuggestion(FilterAutocompleteSuggestion suggestion) {
      final nextText = suggestion.applyTo(searchController.text);
      final nextOffset = suggestion.caretOffsetAfterApply();
      searchController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextOffset),
      );
      controller.setSearchQuery(nextText);
      highlightedSuggestionIndex.value = 0;
      autocompleteOpen.value = controller
          .filterAutocompleteSuggestions(nextText, nextOffset)
          .isNotEmpty;
    }

    KeyEventResult handleAutocompleteKey(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      final suggestions = currentSuggestions();
      final hasSuggestions = suggestions.isNotEmpty;
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.escape && autocompleteOpen.value) {
        autocompleteOpen.value = false;
        highlightedSuggestionIndex.value = 0;
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.tab) {
        if (!hasSuggestions) {
          return KeyEventResult.handled;
        }
        final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftLeft) ||
            HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftRight);
        if (autocompleteOpen.value) {
          highlightedSuggestionIndex.value = isShiftPressed
              ? (highlightedSuggestionIndex.value - 1 + suggestions.length) %
                  suggestions.length
              : (highlightedSuggestionIndex.value + 1) % suggestions.length;
        } else {
          autocompleteOpen.value = true;
          highlightedSuggestionIndex.value =
              isShiftPressed ? suggestions.length - 1 : 0;
        }
        return KeyEventResult.handled;
      }

      if (!hasSuggestions) {
        return KeyEventResult.ignored;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        if (autocompleteOpen.value) {
          highlightedSuggestionIndex.value =
              (highlightedSuggestionIndex.value + 1) % suggestions.length;
        } else {
          autocompleteOpen.value = true;
          highlightedSuggestionIndex.value = 0;
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        if (autocompleteOpen.value) {
          highlightedSuggestionIndex.value =
              (highlightedSuggestionIndex.value - 1 + suggestions.length) %
                  suggestions.length;
        } else {
          autocompleteOpen.value = true;
          highlightedSuggestionIndex.value = suggestions.length - 1;
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter && autocompleteOpen.value) {
        final index = _clampSuggestionIndex(
          highlightedSuggestionIndex.value,
          suggestions.length,
        );
        applySuggestion(suggestions[index]);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    final searchFocusNode = useFocusNode(onKeyEvent: handleAutocompleteKey);

    return () {
      if (controller.$isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final filteredNodes = controller.filteredNodes;
      final List<FilterAutocompleteSuggestion> suggestions =
          autocompleteOpen.value
              ? currentSuggestions()
              : const <FilterAutocompleteSuggestion>[];
      final highlightedIndex = suggestions.isEmpty
          ? 0
          : _clampSuggestionIndex(
              highlightedSuggestionIndex.value,
              suggestions.length,
            );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFieldTapRegion(
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Filter',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      suffixIcon: JoltBuilder(builder: (context) {
                        return Visibility(
                          visible: searchController.text.isNotEmpty,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: const Icon(Icons.clear),
                              iconSize: 14,
                              onPressed: () {
                                searchController.clear();
                                controller.setSearchQuery('');
                                autocompleteOpen.value = false;
                                highlightedSuggestionIndex.value = 0;
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    onChanged: (value) {
                      controller.setSearchQuery(value);
                      highlightedSuggestionIndex.value = 0;
                      autocompleteOpen.value = value.isNotEmpty;
                    },
                    onTap: () {
                      autocompleteOpen.value = searchController.text.isNotEmpty;
                    },
                    onTapOutside: (_) {
                      autocompleteOpen.value = false;
                      highlightedSuggestionIndex.value = 0;
                      searchFocusNode.unfocus();
                    },
                  ),
                  if (suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = suggestions[index];
                              final isHighlighted = index == highlightedIndex;
                              return InkWell(
                                onTap: () => applySuggestion(suggestion),
                                onHover: (hovered) {
                                  if (hovered) {
                                    highlightedSuggestionIndex.value = index;
                                  }
                                },
                                child: Container(
                                  color: isHighlighted
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(36)
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(suggestion.label)),
                                      const SizedBox(width: 12),
                                      Text(
                                        suggestion.kind.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Matched ${filteredNodes.length} / ${controller.globalFilteredNodeCount} nodes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredNodes.isEmpty
                ? Center(
                    child: Text(
                      controller.$nodes.isEmpty
                          ? 'No reactive nodes found'
                          : 'No nodes match the filter',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView(
                    children: List.generate(filteredNodes.length,
                        (index) => _NodeTile(node: filteredNodes[index])),
                  ),
          ),
        ],
      );
    };
  }
}

int _clampSuggestionIndex(int index, int length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}

class _NodeTile extends StatefulWidget {
  final JoltNode node;

  const _NodeTile({
    required this.node,
  });

  @override
  State<_NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends State<_NodeTile> with SetupMixin<_NodeTile> {
  @override
  setup(BuildContext context) {
    final controller = context.read<JoltInspectorController>();
    final isSelected =
        useComputed(() => controller.$selectedNodeId.value == widget.node.id);

    final color = useComputed(
        () => isSelected.value ? Colors.blue.shade900.withAlpha(72) : null);

    return () => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: color.value,
          child: ListTile(
            dense: true,
            selected: isSelected.value,
            leading: NodeIcon(type: widget.node.type),
            title: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              children: [
                Text(
                  (widget.node.label.isNotEmpty &&
                          widget.node.label != 'Unnamed')
                      ? widget.node.label
                      : '${widget.node.type}(${widget.node.id})',
                  style: TextStyle(
                    fontWeight: isSelected.value ? FontWeight.bold : null,
                    decoration: widget.node.isDisposed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700.withAlpha(36),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.blue.shade700.withAlpha(128),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.node.debugType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildBadge('deps: ${widget.node.dependencies.length}'),
                  _buildBadge('subs: ${widget.node.subscribers.length}'),
                  if (widget.node.isReadable)
                    _buildBadge(
                      'value: ${widget.node.valueType.value}',
                      maxWidth: 150,
                    )
                ],
              ),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [],
            ),
            onTap: () => controller.selectNode(
              widget.node.id,
              reason: SelectionReason.listClick,
            ),
          ),
        );
  }

  Widget _buildBadge(String text, {double? maxWidth}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth)
          : const BoxConstraints(),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade300,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
