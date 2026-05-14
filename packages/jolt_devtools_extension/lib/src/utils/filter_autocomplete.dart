import 'package:jolt_devtools_extension/src/models/filter_autocomplete.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

const _fieldNames = [
  'type',
  'debug',
  'label',
  'valuetype',
  'id',
  'deps',
  'subs',
  'count',
  'has',
  'value',
  'updated',
  'created',
  'dep',
  'sub',
];

const _stringOperatorFields = {'label', 'debug', 'valuetype'};
const _numericFields = {'id', 'deps', 'subs', 'count'};
const _stringOperators = ['==', '^=', r'$='];
const _numericOperators = [':', '=', '>', '>=', '<', '<='];
const _timeSnippets = ['<=1s', '<=5s', '<=10s', '<=1m', '>=10s', '>=1m'];
const _relationInnerFieldNames = [
  'id',
  'type',
  'debug',
  'label',
  'valuetype',
  'deps',
  'subs',
  'count',
  'has',
  'value',
  'updated',
  'created',
];

List<FilterAutocompleteSuggestion> buildFilterAutocompleteSuggestions({
  required String input,
  required int caretOffset,
  required Iterable<JoltNode> nodes,
}) {
  final context = _tokenContext(input, caretOffset);
  if (context == null) return const [];

  final relationContext = _relationInnerContext(context, caretOffset);
  if (relationContext != null) {
    return _relationInnerSuggestions(
      context: relationContext,
      nodes: nodes,
    );
  }

  final token = context.token;
  if (token.isEmpty || !token.contains(':')) {
    return _fieldSuggestions(token, context);
  }

  final colonIndex = token.indexOf(':');
  final rawKey = token.substring(0, colonIndex);
  final isNegated = rawKey.startsWith('-');
  final key = (isNegated ? rawKey.substring(1) : rawKey).toLowerCase();
  final valuePrefix = token.substring(colonIndex + 1);

  if (key == 'dep' || key == 'sub') {
    return _relationSuggestions(
      key: key,
      isNegated: isNegated,
      valuePrefix: valuePrefix,
      replacementStart: context.start,
      replacementEnd: context.end,
    );
  }

  return _valueSuggestions(
    key: key,
    valuePrefix: valuePrefix,
    replacementStart: context.start + colonIndex + 1,
    replacementEnd: context.end,
    nodes: nodes,
  );
}

List<FilterAutocompleteSuggestion> _fieldSuggestions(
  String token,
  _TokenContext context, {
  List<String> fieldNames = _fieldNames,
}) {
  final suggestions = <FilterAutocompleteSuggestion>[];
  final isNegated = token.startsWith('-');
  final typed = isNegated ? token.substring(1) : token;

  if (fieldNames.contains(typed.toLowerCase())) {
    return _fieldOperatorSuggestions(
      key: typed.toLowerCase(),
      replacementStart: context.end,
      replacementEnd: context.end,
    );
  }

  for (final field in fieldNames) {
    if (!_matchesCandidate(field, typed)) continue;
    final insertText = isNegated ? '-$field' : field;
    suggestions.add(
      FilterAutocompleteSuggestion(
        label: insertText,
        insertText: insertText,
        kind: FilterAutocompleteSuggestionKind.field,
        replacementStart: context.start,
        replacementEnd: context.end,
      ),
    );
  }
  return suggestions..sort(_compareSuggestions(token));
}

List<FilterAutocompleteSuggestion> _fieldOperatorSuggestions({
  required String key,
  required int replacementStart,
  required int replacementEnd,
}) {
  final operators = _numericFields.contains(key) ? _numericOperators : [':'];
  return operators
      .map(
        (operator) => FilterAutocompleteSuggestion(
          label: operator,
          insertText: operator,
          kind: FilterAutocompleteSuggestionKind.operator,
          replacementStart: replacementStart,
          replacementEnd: replacementEnd,
        ),
      )
      .toList()
    ..sort(_compareSuggestions(''));
}

List<FilterAutocompleteSuggestion> _stringOperatorSuggestions({
  required String valuePrefix,
  required int replacementStart,
  required int replacementEnd,
}) {
  return _stringOperators
      .where((operator) => _matchesCandidate(operator, valuePrefix))
      .map((operator) {
    return FilterAutocompleteSuggestion(
      label: operator,
      insertText: operator,
      kind: FilterAutocompleteSuggestionKind.operator,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
    );
  }).toList()
    ..sort(_compareSuggestions(valuePrefix));
}

({String operator, String prefix})? _completeStringOperator(
    String valuePrefix) {
  for (final operator in _stringOperators) {
    if (valuePrefix.startsWith(operator)) {
      return (
        operator: operator,
        prefix: valuePrefix.substring(operator.length)
      );
    }
  }
  return null;
}

bool _isPartialStringOperator(String valuePrefix) {
  if (valuePrefix.isEmpty) return true;
  return _stringOperators.any((operator) {
    return operator.startsWith(valuePrefix) && operator != valuePrefix;
  });
}

List<FilterAutocompleteSuggestion> _stringValueSuggestions({
  required String key,
  required String valuePrefix,
  required int replacementStart,
  required int replacementEnd,
  required Iterable<JoltNode> nodes,
}) {
  if (_isPartialStringOperator(valuePrefix)) {
    return _stringOperatorSuggestions(
      valuePrefix: valuePrefix,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
    );
  }

  final completeOperator = _completeStringOperator(valuePrefix);
  final effectivePrefix = completeOperator?.prefix ?? valuePrefix;
  final effectiveReplacementStart =
      replacementStart + (completeOperator?.operator.length ?? 0);

  final values = switch (key) {
    'debug' => _nodeDebugTypes(nodes),
    'valuetype' => _nodeValueTypes(nodes),
    'label' => _nodeLabels(nodes),
    _ => const <String>[],
  };

  return values.where((value) {
    return _matchesCandidate(value, effectivePrefix);
  }).map((value) {
    return FilterAutocompleteSuggestion(
      label: value,
      insertText: value,
      kind: FilterAutocompleteSuggestionKind.value,
      replacementStart: effectiveReplacementStart,
      replacementEnd: replacementEnd,
      appendSpace: true,
    );
  }).toList()
    ..sort(_compareSuggestions(effectivePrefix));
}

List<FilterAutocompleteSuggestion> _nonStringValueSuggestions({
  required String key,
  required String valuePrefix,
  required int replacementStart,
  required int replacementEnd,
  required Iterable<JoltNode> nodes,
  bool relationInner = false,
  int? relationInnerPostInsertOffset,
}) {
  final values = switch (key) {
    'type' => _nodeTypes(nodes),
    'id' => _nodeIds(nodes),
    'has' => const ['label', 'value'],
    'updated' || 'created' => _timeSnippets,
    'value' => const <String>[],
    _ => const <String>[],
  };

  return values.where((value) {
    return _matchesCandidate(value, valuePrefix);
  }).map((value) {
    return FilterAutocompleteSuggestion(
      label: value,
      insertText: value,
      kind: _isSyntaxValue(key)
          ? FilterAutocompleteSuggestionKind.snippet
          : FilterAutocompleteSuggestionKind.value,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
      appendSpace: !relationInner,
      postInsertText: relationInner ? ' ' : '',
      postInsertOffset: relationInner ? relationInnerPostInsertOffset : null,
    );
  }).toList()
    ..sort(_compareSuggestions(valuePrefix));
}

List<FilterAutocompleteSuggestion> _valueSuggestions({
  required String key,
  required String valuePrefix,
  required int replacementStart,
  required int replacementEnd,
  required Iterable<JoltNode> nodes,
}) {
  if (_stringOperatorFields.contains(key)) {
    return _stringValueSuggestions(
      key: key,
      valuePrefix: valuePrefix,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
      nodes: nodes,
    );
  }

  return _nonStringValueSuggestions(
    key: key,
    valuePrefix: valuePrefix,
    replacementStart: replacementStart,
    replacementEnd: replacementEnd,
    nodes: nodes,
  );
}

List<FilterAutocompleteSuggestion> _relationSuggestions({
  required String key,
  required bool isNegated,
  required String valuePrefix,
  required int replacementStart,
  required int replacementEnd,
}) {
  final tokenPrefix = isNegated ? '-$key' : key;
  final snippets = [
    '$tokenPrefix:{id:}',
    '$tokenPrefix:{type:}',
    '$tokenPrefix:{debug:}',
  ];
  final matchStart = tokenPrefix.length + 1;
  return snippets.where((snippet) {
    return valuePrefix.isEmpty ||
        _matchesCandidate(snippet.substring(matchStart), valuePrefix);
  }).map((snippet) {
    return FilterAutocompleteSuggestion(
      label: snippet,
      insertText: snippet,
      kind: FilterAutocompleteSuggestionKind.snippet,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
      caretOffset: replacementStart + snippet.length - 1,
    );
  }).toList()
    ..sort(_compareSuggestions(valuePrefix));
}

List<FilterAutocompleteSuggestion> _relationInnerSuggestions({
  required _RelationInnerContext context,
  required Iterable<JoltNode> nodes,
}) {
  final innerToken = context.innerToken;
  final innerContext = _TokenContext(
    start: context.innerStart,
    end: context.innerEnd,
    token: innerToken,
  );

  if (innerToken.isEmpty || !innerToken.contains(':')) {
    return _fieldSuggestions(
      innerToken,
      innerContext,
      fieldNames: _relationInnerFieldNames,
    ).map((suggestion) {
      return FilterAutocompleteSuggestion(
        label: suggestion.label,
        insertText: suggestion.insertText,
        kind: suggestion.kind,
        replacementStart: suggestion.replacementStart,
        replacementEnd: suggestion.replacementEnd,
        caretOffset: suggestion.caretOffsetAfterApply(),
      );
    }).toList();
  }

  final colonIndex = innerToken.indexOf(':');
  final key = innerToken.substring(0, colonIndex).toLowerCase();
  final valuePrefix = innerToken.substring(colonIndex + 1);
  final valueStart = context.innerStart + colonIndex + 1;

  if (_stringOperatorFields.contains(key)) {
    if (_isPartialStringOperator(valuePrefix)) {
      return _stringOperatorSuggestions(
        valuePrefix: valuePrefix,
        replacementStart: valueStart,
        replacementEnd: context.innerEnd,
      ).map((suggestion) {
        return FilterAutocompleteSuggestion(
          label: suggestion.label,
          insertText: suggestion.insertText,
          kind: suggestion.kind,
          replacementStart: suggestion.replacementStart,
          replacementEnd: suggestion.replacementEnd,
          caretOffset: suggestion.caretOffsetAfterApply(),
        );
      }).toList();
    }

    final completeOperator = _completeStringOperator(valuePrefix);
    final effectivePrefix = completeOperator?.prefix ?? valuePrefix;
    final effectiveReplacementStart =
        valueStart + (completeOperator?.operator.length ?? 0);
    final values = switch (key) {
      'debug' => _nodeDebugTypes(nodes),
      'valuetype' => _nodeValueTypes(nodes),
      'label' => _nodeLabels(nodes),
      _ => const <String>[],
    };

    return values.where((value) {
      return _matchesCandidate(value, effectivePrefix);
    }).map((value) {
      return FilterAutocompleteSuggestion(
        label: value,
        insertText: value,
        kind: FilterAutocompleteSuggestionKind.value,
        replacementStart: effectiveReplacementStart,
        replacementEnd: context.innerEnd,
        postInsertText: ' ',
        postInsertOffset: context.closingBrace + 1,
      );
    }).toList()
      ..sort(_compareSuggestions(effectivePrefix));
  }

  return _nonStringValueSuggestions(
    key: key,
    valuePrefix: valuePrefix,
    replacementStart: valueStart,
    replacementEnd: context.innerEnd,
    nodes: nodes,
    relationInner: true,
    relationInnerPostInsertOffset: context.closingBrace + 1,
  );
}

bool _isSyntaxValue(String key) {
  return key == 'has' || key == 'updated' || key == 'created';
}

List<String> _nodeTypes(Iterable<JoltNode> nodes) {
  return _sortedUnique([
    'Signal',
    'Computed',
    'Effect',
    ...nodes.map((node) => node.type),
  ]);
}

List<String> _nodeIds(Iterable<JoltNode> nodes) {
  return _sortedUnique(nodes.map((node) => node.id.toString()));
}

List<String> _nodeDebugTypes(Iterable<JoltNode> nodes) {
  return _sortedUnique(nodes.map((node) => node.debugType));
}

List<String> _nodeValueTypes(Iterable<JoltNode> nodes) {
  return _sortedUnique(nodes.map((node) => node.valueType.value));
}

List<String> _nodeLabels(Iterable<JoltNode> nodes) {
  return _sortedUnique(
    nodes
        .map((node) => node.label)
        .where((label) => label.isNotEmpty && label != 'Unnamed'),
  );
}

List<String> _sortedUnique(Iterable<String> values) {
  final set = <String>{};
  for (final value in values) {
    if (value.trim().isNotEmpty) {
      set.add(value);
    }
  }
  return set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

bool _matchesCandidate(String candidate, String typed) {
  if (typed.isEmpty) return true;
  final lowerCandidate = candidate.toLowerCase();
  final lowerTyped = typed.toLowerCase();
  return lowerCandidate.contains(lowerTyped);
}

int Function(FilterAutocompleteSuggestion, FilterAutocompleteSuggestion)
    _compareSuggestions(String typed) {
  return (a, b) {
    final aRank = _matchRank(a.label, typed);
    final bRank = _matchRank(b.label, typed);
    if (aRank != bRank) return aRank.compareTo(bRank);
    final aKindRank = _kindRank(a.kind);
    final bKindRank = _kindRank(b.kind);
    if (aKindRank != bKindRank) return aKindRank.compareTo(bKindRank);
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  };
}

int _kindRank(FilterAutocompleteSuggestionKind kind) {
  return switch (kind) {
    FilterAutocompleteSuggestionKind.field => 0,
    FilterAutocompleteSuggestionKind.operator => 1,
    FilterAutocompleteSuggestionKind.snippet => 2,
    FilterAutocompleteSuggestionKind.value => 3,
  };
}

int _matchRank(String candidate, String typed) {
  if (typed.isEmpty) return 2;
  final lowerCandidate = candidate.toLowerCase();
  final lowerTyped = typed.toLowerCase();
  if (lowerCandidate == lowerTyped) return 0;
  if (lowerCandidate.startsWith(lowerTyped)) return 1;
  if (lowerCandidate.contains(lowerTyped)) return 2;
  return 3;
}

_TokenContext? _tokenContext(String input, int caretOffset) {
  if (caretOffset < 0 || caretOffset > input.length) return null;
  if (_isInsideQuotedText(input, caretOffset)) return null;

  var start = caretOffset;
  while (start > 0) {
    final char = input[start - 1];
    if (_isTokenBoundary(char)) break;
    start--;
  }

  var end = caretOffset;
  while (end < input.length) {
    final char = input[end];
    if (_isTokenBoundary(char)) break;
    end++;
  }

  return _TokenContext(
    start: start,
    end: end,
    token: input.substring(start, end),
  );
}

_RelationInnerContext? _relationInnerContext(
  _TokenContext context,
  int caretOffset,
) {
  final token = context.token;
  final tokenCaret = caretOffset - context.start;
  if (tokenCaret < 0 || tokenCaret > token.length) return null;

  final match = RegExp(r'^-?(dep|sub):\{').firstMatch(token);
  if (match == null) return null;

  final openBrace = match.end - 1;
  final closingBrace = token.indexOf('}', openBrace + 1);
  if (closingBrace == -1) return null;
  if (tokenCaret <= openBrace || tokenCaret > closingBrace) return null;

  var innerStart = tokenCaret;
  while (innerStart > openBrace + 1) {
    final char = token[innerStart - 1];
    if (_isRelationInnerBoundary(char)) break;
    innerStart--;
  }

  var innerEnd = tokenCaret;
  while (innerEnd < closingBrace) {
    final char = token[innerEnd];
    if (_isRelationInnerBoundary(char)) break;
    innerEnd++;
  }

  return _RelationInnerContext(
    innerStart: context.start + innerStart,
    innerEnd: context.start + innerEnd,
    innerToken: token.substring(innerStart, innerEnd),
    closingBrace: context.start + closingBrace,
  );
}

bool _isRelationInnerBoundary(String char) {
  return char.trim().isEmpty || char == '(' || char == ')' || char == '|';
}

bool _isTokenBoundary(String char) {
  return char.trim().isEmpty || char == '(' || char == ')' || char == '|';
}

bool _isInsideQuotedText(String input, int caretOffset) {
  String? quote;
  var escaped = false;
  for (var i = 0; i < caretOffset; i++) {
    final char = input[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (quote != null) {
      if (char == quote) quote = null;
      continue;
    }
    if (char == '"' || char == "'") quote = char;
  }
  return quote != null;
}

class _TokenContext {
  final int start;
  final int end;
  final String token;

  const _TokenContext({
    required this.start,
    required this.end,
    required this.token,
  });
}

class _RelationInnerContext {
  final int innerStart;
  final int innerEnd;
  final String innerToken;
  final int closingBrace;

  const _RelationInnerContext({
    required this.innerStart,
    required this.innerEnd,
    required this.innerToken,
    required this.closingBrace,
  });
}
