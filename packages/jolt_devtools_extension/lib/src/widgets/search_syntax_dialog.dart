import 'package:flutter/material.dart';

/// Dialog that displays search syntax help
class SearchSyntaxDialog extends StatelessWidget {
  const SearchSyntaxDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Search Syntax Help',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 16,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'Quick Search',
                      'Plain text matches label, type, debug type, or ID. All matching is case-insensitive.',
                      [
                        '• Empty search shows all nodes.',
                        '• Unknown fields fall back to plain text matching.',
                        '• Quoted strings are not supported in V1.',
                      ],
                      [
                        'counter        # label/type/debug/id contains counter',
                        'signal         # label/type/debug/id contains signal',
                        '123            # id contains 123',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Fields',
                      'Use field:value to search one field.',
                      [
                        '• type: exact node type',
                        '• label, debug, valuetype: text fields',
                        '• id, deps, subs, count: numbers',
                        '• updated, created: age filters',
                        '• has: label or value',
                        '• value: readable value summary',
                        '• dep, sub: one-level relationship filters',
                      ],
                      [
                        'type:Signal     # Signal nodes',
                        'label:counter   # label contains counter',
                        'debug:Jolt      # debug type contains Jolt',
                        'has:value       # nodes with readable values',
                        'value:ready     # value summary contains ready',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Text Operators',
                      'label, debug, and valuetype contain text by default. Add an operator for exact, prefix, or suffix matching.',
                      [
                        '• == exact',
                        '• ^= starts with',
                        '• \$= ends with',
                      ],
                      [
                        'label:counter      # contains counter',
                        'label:==counter    # exactly counter',
                        'debug:^=Jolt       # starts with Jolt',
                        'valuetype:\$=State # ends with State',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Numbers',
                      'id, deps, subs, and count support exact and comparison filters.',
                      [
                        '• : and = mean exact match',
                        '• >, >=, <, <= compare numbers',
                        '• Invalid numbers match nothing',
                      ],
                      [
                        'id:42          # id is 42',
                        'deps>0         # has dependencies',
                        'subs<=3        # at most 3 subscribers',
                        'count>=2       # updated or ran at least twice',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Time',
                      'updated and created filter by age. Units: ms, s, m, h, d. No operator means >=.',
                      [
                        '• updated:10s means updated at least 10s ago',
                        '• <= means within the age window',
                        '• Missing timestamps match nothing',
                      ],
                      [
                        'updated:<=5s    # updated within 5 seconds',
                        'updated:>=1m    # last updated at least 1 minute ago',
                        'created:10s     # created at least 10 seconds ago',
                        'created:<=1h    # created within 1 hour',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Relationships',
                      'dep and sub match nodes by one dependency or subscriber. The inner query supports one condition only.',
                      [
                        '• dep:{...}: any dependency matches',
                        '• sub:{...}: any subscriber matches',
                        '• No nested dep/sub and no inner AND/OR in V1',
                      ],
                      [
                        'dep:{type:Signal}       # depends on a Signal',
                        'dep:{id:42}             # depends on node 42',
                        'sub:{debug:JoltBuilder} # has a JoltBuilder subscriber',
                        'sub:{count>=2}          # subscriber count is at least 2',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Combine Conditions',
                      'Spaces mean AND. Use | or or for OR. Use parentheses to group. Prefix a condition with - to exclude it.',
                      [
                        '• AND is the default.',
                        '• AND has higher priority than OR.',
                        '• Incomplete conditions are ignored while you edit.',
                      ],
                      [
                        'type:Signal has:value              # Signal with value',
                        'type:Signal | type:Computed        # Signal or Computed',
                        '(type:Signal | type:Computed) deps>0',
                        '-debug:JoltBuilder type:Signal     # exclude builders',
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Global Filter uses the same syntax and is combined with this search using AND.',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String description,
    List<String> bulletPoints,
    List<String> examples,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
        if (bulletPoints.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  point,
                  style: const TextStyle(fontSize: 13),
                ),
              )),
        ],
        if (examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: examples.map((example) {
                if (example.isEmpty) {
                  return const SizedBox(height: 4);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    example,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
