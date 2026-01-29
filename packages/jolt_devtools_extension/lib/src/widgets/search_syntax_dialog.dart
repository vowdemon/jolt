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
                      'Default Fuzzy Search',
                      'When entering plain text, fuzzy matching is performed in the following fields:',
                      [
                        '• label: node label',
                        '• type: node type (Signal, Computed, Effect, etc.)',
                        '• debugType: debug type',
                        '• id: node ID',
                      ],
                      [
                        'signal        # matches all nodes containing "signal"',
                        'counter       # matches nodes with "counter" in label, type, or ID',
                        '123           # matches nodes with ID 123 or containing "123"',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Advanced Conditional Search',
                      'Use key:value format for filtering:',
                      [],
                      [
                        'type:Signal              # exact match for Signal type',
                        'label:counter            # fuzzy match for label containing "counter" (default)',
                        'debug:test               # fuzzy match for debugType containing "test" (default)',
                        'has:value                # Signal and Computed only (nodes with readable value)',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Field Matching Mode',
                      '',
                      [
                        '• type: exact match only',
                        '• label: fuzzy match by default, can use operators to switch modes',
                        '• debug: fuzzy match by default, can use operators to switch modes',
                      ],
                      [],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'label and debug Field Operators',
                      'label and debug fields use fuzzy matching by default. Use the following operators to switch modes:',
                      [],
                      [
                        'label:text               # fuzzy match (default)',
                        'label:==exact            # exact match',
                        'label:^=prefix          # match prefix',
                        'label:\$=suffix          # match suffix',
                        '',
                        'debug:text               # fuzzy match (default)',
                        'debug:==exact            # exact match',
                        'debug:^=prefix          # match prefix',
                        'debug:\$=suffix          # match suffix',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Numeric Comparison',
                      'id, deps, and subs fields support numeric comparison:',
                      [],
                      [
                        'id=123                   # exact match for ID',
                        'id>=100                  # ID greater than or equal to 100',
                        'id<50                    # ID less than 50',
                        'deps>5                   # dependency count greater than 5',
                        'subs<=10                 # subscriber count less than or equal to 10',
                        'count>=3                  # Count: readable = 1+updates, Effect = run count',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Updated (time since last update)',
                      'updated: filters by how long ago the node was last updated. Default : is >=. Units: ms, s, m, h, d.',
                      [],
                      [
                        'updated:10s               # updated at least 10s ago (>=)',
                        'updated:>=100ms           # updated at least 100ms ago',
                        'updated:<=5m              # updated at most 5 minutes ago',
                        'updated:<=1h              # updated at most 1 hour ago',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Created (time since creation)',
                      'created: filters by how long ago the node was created. Default : is >=. Units: ms, s, m, h, d.',
                      [],
                      [
                        'created:10s               # created at least 10s ago (>=)',
                        'created:>=100ms           # created at least 100ms ago',
                        'created:<=5m              # created at most 5 minutes ago',
                        'created:<=1h              # created at most 1 hour ago',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Negation',
                      'Add a - prefix before a condition to exclude matching nodes:',
                      [],
                      [
                        '-type:Signal             # exclude all Signal types',
                        '-deps>5                  # exclude nodes with dependency count greater than 5',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'AND Logic (Default)',
                      'Separate multiple conditions with spaces. All conditions must be satisfied:',
                      [],
                      [
                        'type:Signal deps>3      # Signal type and dependency count greater than 3',
                        'id>=100 -type:Effect    # ID greater than or equal to 100 and not Effect type',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'OR Logic',
                      'Use | or OR keyword to connect conditions. Any condition can be satisfied:',
                      [],
                      [
                        'type:Signal | type:Computed        # Signal or Computed type',
                        'deps>5 | subs>10                   # dependency count greater than 5 or subscriber count greater than 10',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Parentheses Logic',
                      'Use parentheses () to change the priority and combination of conditions:',
                      [],
                      [
                        '(type:Signal | type:Computed) deps>3    # (Signal or Computed) and dependency count greater than 3',
                        'type:Signal (deps>3 | subs>5)          # Signal type and (dependency count greater than 3 or subscriber count greater than 5)',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Supported Fields',
                      '',
                      [
                        '• type: node type (exact match only)',
                        '• label: node label (fuzzy match by default, supports ==, ^=, \$= operators)',
                        '• debug: debug type (fuzzy match by default, supports ==, ^=, \$= operators)',
                        '• id: node ID (numeric comparison)',
                        '• deps: dependency count (numeric comparison, Effect/EffectScope only)',
                        '• subs: subscriber count (numeric comparison)',
                        '• count: readable = 1+updates, Effect = run count (numeric comparison)',
                        '• updated: time since last update (>=, <=; default : is >=; units ms, s, m, h, d)',
                        '• created: time since creation (>=, <=; default : is >=; units ms, s, m, h, d)',
                        '• has: check property existence (has:label, has:value to filter Signal/Computed)',
                        '• value: node value (fuzzy match, Signal/Computed only)',
                      ],
                      [],
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
                              'All search conditions are case-insensitive',
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
