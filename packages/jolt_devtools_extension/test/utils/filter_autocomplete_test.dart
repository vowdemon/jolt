import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/models/filter_autocomplete.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/utils/filter_autocomplete.dart';

JoltNode _node({
  required int id,
  required String type,
  required String label,
  required String debugType,
  required String valueType,
  Object? value,
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: debugType,
    isDisposed: false,
    value: value,
    flags: 0,
    valueType: valueType,
  );
}

final _nodes = [
  _node(
    id: 1,
    type: 'Signal',
    label: 'counter',
    debugType: 'store',
    valueType: 'int',
    value: 1,
  ),
  _node(
    id: 2,
    type: 'Computed',
    label: 'cartTotal',
    debugType: 'JoltBuilder',
    valueType: 'double',
    value: 12.0,
  ),
  _node(
    id: 3,
    type: 'Effect',
    label: 'Unnamed',
    debugType: 'store',
    valueType: 'void',
  ),
];

void main() {
  group('FilterAutocompleteSuggestion', () {
    test('stores display label, insert text, kind, and replacement range', () {
      const suggestion = FilterAutocompleteSuggestion(
        label: 'type:',
        insertText: 'type:',
        kind: FilterAutocompleteSuggestionKind.field,
        replacementStart: 0,
        replacementEnd: 2,
      );

      expect(suggestion.label, 'type:');
      expect(suggestion.insertText, 'type:');
      expect(suggestion.kind, FilterAutocompleteSuggestionKind.field);
      expect(suggestion.replacementStart, 0);
      expect(suggestion.replacementEnd, 2);
    });

    test('applies replacement to the configured input range', () {
      const suggestion = FilterAutocompleteSuggestion(
        label: 'type:',
        insertText: 'type:',
        kind: FilterAutocompleteSuggestionKind.field,
        replacementStart: 12,
        replacementEnd: 14,
      );

      expect(suggestion.applyTo('debug:store ty'), 'debug:store type:');
    });

    test('computes caret offset after replacement', () {
      const suggestion = FilterAutocompleteSuggestion(
        label: 'type:',
        insertText: 'type:',
        kind: FilterAutocompleteSuggestionKind.field,
        replacementStart: 12,
        replacementEnd: 14,
      );

      expect(suggestion.caretOffsetAfterApply(), 17);
    });

    test('supports custom caret offset after insertion', () {
      const suggestion = FilterAutocompleteSuggestion(
        label: 'dep:{id:}',
        insertText: 'dep:{id:}',
        kind: FilterAutocompleteSuggestionKind.snippet,
        replacementStart: 0,
        replacementEnd: 4,
        caretOffset: 8,
      );

      expect(suggestion.applyTo('dep:'), 'dep:{id:}');
      expect(suggestion.caretOffsetAfterApply(), 8);
    });
  });

  group('buildFilterAutocompleteSuggestions fields', () {
    test('suggests field name when typing a field prefix', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'ty',
        caretOffset: 2,
        nodes: const [],
      );

      expect(suggestions.map((s) => s.label), contains('type'));
      expect(suggestions.map((s) => s.label), isNot(contains('type:')));
      final typeSuggestion = suggestions.firstWhere((s) => s.label == 'type');
      expect(typeSuggestion.applyTo('ty'), 'type');
    });

    test('only replaces the current token', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'debug:store ty',
        caretOffset: 'debug:store ty'.length,
        nodes: const [],
      );

      final typeSuggestion = suggestions.firstWhere((s) => s.label == 'type');
      expect(typeSuggestion.applyTo('debug:store ty'), 'debug:store type');
    });

    test('suggests negated field names when token starts with dash', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: '-de',
        caretOffset: 3,
        nodes: const [],
      );

      final debugSuggestion =
          suggestions.firstWhere((s) => s.label == '-debug');
      expect(debugSuggestion.applyTo('-de'), '-debug');
    });

    test('suggests operators after a complete field name', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'type',
        caretOffset: 4,
        nodes: const [],
      );

      expect(suggestions.map((s) => s.label), contains(':'));
      expect(suggestions.map((s) => s.label), isNot(contains('Signal')));
    });
  });

  group('buildFilterAutocompleteSuggestions values', () {
    final nodes = _nodes;

    test('suggests node types after type colon', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'type:',
        caretOffset: 5,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, containsAll(['Signal', 'Computed', 'Effect']));
    });

    test('suggests string operators after empty debug colon', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: '-debug:',
        caretOffset: 7,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, containsAll(['==', '^=', r'$=']));
      expect(labels, isNot(contains('JoltBuilder')));
    });

    test('suggests debug types after debug value input', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: '-debug:J',
        caretOffset: 8,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, contains('JoltBuilder'));
    });

    test('suggests value types after valuetype value input', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'valuetype:i',
        caretOffset: 11,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, contains('int'));
    });

    test('suggests non-empty non-Unnamed labels after label colon', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'label:c',
        caretOffset: 7,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, containsAll(['cartTotal', 'counter']));
      expect(labels, isNot(contains('Unnamed')));
    });

    test('does not suggest runtime value summaries after value colon', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'value:',
        caretOffset: 6,
        nodes: nodes,
      ).map((s) => s.label).toList();

      expect(labels, isNot(contains('1')));
      expect(labels, isNot(contains('12.0')));
    });

    test('label candidates come from all provided nodes', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'label:counter',
        caretOffset: 'label:counter'.length,
        nodes: [
          _node(
            id: 1,
            type: 'Signal',
            label: 'visibleCounter',
            debugType: 'app',
            valueType: 'int',
          ),
          _node(
            id: 2,
            type: 'Signal',
            label: 'hiddenCounter',
            debugType: 'JoltBuilder',
            valueType: 'int',
          ),
        ],
      ).map((s) => s.label).toList();

      expect(labels, containsAll(['hiddenCounter', 'visibleCounter']));
    });
  });

  group('buildFilterAutocompleteSuggestions syntax snippets', () {
    test('suggests string operators for label field', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'label:',
        caretOffset: 6,
        nodes: const [],
      ).map((s) => s.label).toList();

      expect(labels, containsAll(['==', '^=', r'$=']));
    });

    test('does not suggest label values before string operator or value input',
        () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'label:',
        caretOffset: 6,
        nodes: [
          _node(
            id: 1,
            type: 'Signal',
            label: 'counter',
            debugType: 'store',
            valueType: 'int',
          ),
        ],
      ).map((s) => s.label).toList();

      expect(labels, isNot(contains('counter')));
    });

    test('suggests label values after string operator is complete', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'label:==',
        caretOffset: 8,
        nodes: [
          _node(
            id: 1,
            type: 'Signal',
            label: 'counter',
            debugType: 'store',
            valueType: 'int',
          ),
        ],
      );

      final counterSuggestion =
          suggestions.firstWhere((s) => s.label == 'counter');
      expect(counterSuggestion.applyTo('label:=='), 'label:==counter ');
    });

    test('value suggestions append a space and start next field flow', () {
      final valueSuggestions = buildFilterAutocompleteSuggestions(
        input: 'type:',
        caretOffset: 5,
        nodes: _nodes,
      );
      final signalSuggestion =
          valueSuggestions.firstWhere((s) => s.label == 'Signal');

      final nextInput = signalSuggestion.applyTo('type:');
      expect(nextInput, 'type:Signal ');

      final nextSuggestions = buildFilterAutocompleteSuggestions(
        input: nextInput,
        caretOffset: nextInput.length,
        nodes: _nodes,
      );
      expect(
          nextSuggestions.map((s) => s.label), containsAll(['type', 'debug']));
      expect(nextSuggestions.map((s) => s.kind).toSet(), {
        FilterAutocompleteSuggestionKind.field,
      });
    });

    test('field and operator suggestions do not append trailing spaces', () {
      final fieldSuggestion = buildFilterAutocompleteSuggestions(
        input: 'ty',
        caretOffset: 2,
        nodes: _nodes,
      ).firstWhere((s) => s.label == 'type');
      final fieldInput = fieldSuggestion.applyTo('ty');

      expect(fieldInput, 'type');

      final operatorSuggestion = buildFilterAutocompleteSuggestions(
        input: fieldInput,
        caretOffset: fieldInput.length,
        nodes: _nodes,
      ).firstWhere((s) => s.label == ':');

      expect(operatorSuggestion.applyTo(fieldInput), 'type:');
    });

    test('suggests numeric operators for count field prefix', () {
      final labels = buildFilterAutocompleteSuggestions(
        input: 'count',
        caretOffset: 5,
        nodes: const [],
      ).map((s) => s.label).toList();

      expect(labels, containsAll([':', '=', '>', '>=', '<', '<=']));
    });

    test('suggests relation snippets after dep colon', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:',
        caretOffset: 4,
        nodes: const [],
      );
      final labels = suggestions.map((s) => s.label).toList();

      expect(labels, containsAll(['dep:{id:}', 'dep:{type:}', 'dep:{debug:}']));
      expect(
        suggestions.firstWhere((s) => s.label == 'dep:{id:}').applyTo('dep:'),
        'dep:{id:}',
      );
      expect(
        suggestions
            .firstWhere((s) => s.label == 'dep:{id:}')
            .caretOffsetAfterApply(),
        'dep:{id:'.length,
      );
    });

    test('suggests inner relation fields before closing brace', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:{}',
        caretOffset: 'dep:{'.length,
        nodes: _nodes,
      );
      final labels = suggestions.map((s) => s.label).toList();

      expect(labels, containsAll(['id', 'type', 'debug', 'label']));
      expect(labels, isNot(contains('dep')));
      expect(labels, isNot(contains('sub')));
    });

    test('inner relation field completion keeps caret before closing brace',
        () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:{ty}',
        caretOffset: 'dep:{ty'.length,
        nodes: _nodes,
      );
      final typeSuggestion = suggestions.firstWhere((s) => s.label == 'type');

      expect(typeSuggestion.applyTo('dep:{ty}'), 'dep:{type}');
      expect(typeSuggestion.caretOffsetAfterApply(), 'dep:{type'.length);

      final nextSuggestions = buildFilterAutocompleteSuggestions(
        input: typeSuggestion.applyTo('dep:{ty}'),
        caretOffset: typeSuggestion.caretOffsetAfterApply(),
        nodes: _nodes,
      );
      expect(nextSuggestions.map((s) => s.label), contains(':'));
    });

    test('inner relation operator completion keeps caret before closing brace',
        () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:{type}',
        caretOffset: 'dep:{type'.length,
        nodes: _nodes,
      );
      final operatorSuggestion = suggestions.firstWhere((s) => s.label == ':');

      expect(operatorSuggestion.applyTo('dep:{type}'), 'dep:{type:}');
      expect(operatorSuggestion.caretOffsetAfterApply(), 'dep:{type:'.length);

      final nextSuggestions = buildFilterAutocompleteSuggestions(
        input: operatorSuggestion.applyTo('dep:{type}'),
        caretOffset: operatorSuggestion.caretOffsetAfterApply(),
        nodes: _nodes,
      );
      expect(
        nextSuggestions.map((s) => s.label),
        containsAll(['Signal', 'Computed', 'Effect']),
      );
    });

    test(
        'inner relation value completion closes relation and starts outer flow',
        () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:{type:}',
        caretOffset: 'dep:{type:'.length,
        nodes: _nodes,
      );
      final signalSuggestion =
          suggestions.firstWhere((s) => s.label == 'Signal');

      expect(signalSuggestion.replacementEnd, 'dep:{type:'.length);
      expect(signalSuggestion.postInsertOffset, 'dep:{type:}'.length);
      final nextInput = signalSuggestion.applyTo('dep:{type:}');
      expect(nextInput, 'dep:{type:Signal} ');
      expect(signalSuggestion.caretOffsetAfterApply(), nextInput.length);

      final nextSuggestions = buildFilterAutocompleteSuggestions(
        input: nextInput,
        caretOffset: nextInput.length,
        nodes: _nodes,
      );
      expect(
          nextSuggestions.map((s) => s.label), containsAll(['type', 'debug']));
    });

    test('inner relation id values come from current nodes', () {
      final suggestions = buildFilterAutocompleteSuggestions(
        input: 'dep:{id:}',
        caretOffset: 'dep:{id:'.length,
        nodes: _nodes,
      );
      final labels = suggestions.map((s) => s.label).toList();

      expect(labels, containsAll(['1', '2', '3']));
      final idSuggestion = suggestions.firstWhere((s) => s.label == '1');
      expect(idSuggestion.replacementEnd, 'dep:{id:'.length);
      expect(idSuggestion.postInsertOffset, 'dep:{id:}'.length);
      final nextInput = idSuggestion.applyTo('dep:{id:}');
      expect(nextInput, 'dep:{id:1} ');
      expect(idSuggestion.caretOffsetAfterApply(), nextInput.length);
    });
  });
}
