import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/models/filter_autocomplete.dart';

void main() {
  testWidgets('方向键移动候选高亮，Enter 确认候选且保持焦点', (tester) async {
    await _pumpAutocompleteHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('type'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(_fieldText(tester), 'debug');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text(':'), findsOneWidget);
  });

  testWidgets('Tab 只向下循环候选，不上屏也不失焦', (tester) async {
    await _pumpAutocompleteHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_fieldText(tester), 't');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'debug');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_fieldText(tester), 't');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'type');
  });

  testWidgets('Shift+Tab 只向上循环候选，不上屏也不失焦', (tester) async {
    await _pumpAutocompleteHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();

    expect(_fieldText(tester), 't');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'debug');
  });

  testWidgets('Enter 确认候选后不让过滤框失焦', (tester) async {
    await _pumpAutocompleteHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_fieldText(tester), 'type');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text(':'), findsOneWidget);
  });

  testWidgets('值候选上屏后追加空格并继续提示字段', (tester) async {
    await _pumpAutocompleteHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_fieldText(tester), 'type:Signal ');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text('type'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);
  });
}

Future<void> _pumpAutocompleteHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: _AutocompleteHarness(),
      ),
    ),
  );
}

String _fieldText(WidgetTester tester) {
  final editable = tester.widget<EditableText>(find.byType(EditableText));
  return editable.controller.text;
}

bool _fieldHasFocus(WidgetTester tester) {
  final editable = tester.widget<EditableText>(find.byType(EditableText));
  return editable.focusNode.hasFocus;
}

String _selectedSuggestionText(WidgetTester tester) {
  final selected = tester.widget<Text>(
    find.byKey(const ValueKey('selected-suggestion')),
  );
  return selected.data!;
}

class _AutocompleteHarness extends StatefulWidget {
  const _AutocompleteHarness();

  @override
  State<_AutocompleteHarness> createState() => _AutocompleteHarnessState();
}

class _AutocompleteHarnessState extends State<_AutocompleteHarness> {
  final _controller = TextEditingController(text: 't');
  final _focusNode = FocusNode();
  var _open = true;
  var _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final suggestions = _currentSuggestions();
    if (event is! KeyDownEvent || !_open || suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab && suggestions.isEmpty) {
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % suggestions.length;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex =
            (_highlightedIndex - 1 + suggestions.length) % suggestions.length;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.shiftLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.shiftRight);
      setState(() {
        _highlightedIndex = isShiftPressed
            ? (_highlightedIndex - 1 + suggestions.length) % suggestions.length
            : (_highlightedIndex + 1) % suggestions.length;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter) {
      final suggestion = suggestions[_highlightedIndex];
      final nextText = suggestion.applyTo(_controller.text);
      _controller.value = TextEditingValue(
        text: nextText,
        selection:
            TextSelection.collapsed(offset: suggestion.caretOffsetAfterApply()),
      );
      setState(() {
        _highlightedIndex = 0;
        _open = _currentSuggestions().isNotEmpty;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<FilterAutocompleteSuggestion> _currentSuggestions() {
    final text = _controller.text;
    if (text == 't') {
      return const [
        FilterAutocompleteSuggestion(
          label: 'type',
          insertText: 'type',
          kind: FilterAutocompleteSuggestionKind.field,
          replacementStart: 0,
          replacementEnd: 1,
        ),
        FilterAutocompleteSuggestion(
          label: 'debug',
          insertText: 'debug',
          kind: FilterAutocompleteSuggestionKind.field,
          replacementStart: 0,
          replacementEnd: 1,
        ),
      ];
    }
    if (text == 'type' || text == 'debug') {
      return const [
        FilterAutocompleteSuggestion(
          label: ':',
          insertText: ':',
          kind: FilterAutocompleteSuggestionKind.operator,
          replacementStart: 4,
          replacementEnd: 4,
        ),
      ];
    }
    if (text == 'type:') {
      return const [
        FilterAutocompleteSuggestion(
          label: 'Signal',
          insertText: 'Signal',
          kind: FilterAutocompleteSuggestionKind.value,
          replacementStart: 5,
          replacementEnd: 5,
          appendSpace: true,
        ),
      ];
    }
    if (text.endsWith(' ')) {
      final start = text.length;
      return [
        FilterAutocompleteSuggestion(
          label: 'type',
          insertText: 'type',
          kind: FilterAutocompleteSuggestionKind.field,
          replacementStart: start,
          replacementEnd: start,
        ),
        FilterAutocompleteSuggestion(
          label: 'debug',
          insertText: 'debug',
          kind: FilterAutocompleteSuggestionKind.field,
          replacementStart: start,
          replacementEnd: start,
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _currentSuggestions();
    return Column(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
        ),
        if (_open)
          for (var index = 0; index < suggestions.length; index++)
            Text(
              suggestions[index].label,
              key: index == _highlightedIndex
                  ? const ValueKey('selected-suggestion')
                  : ValueKey('suggestion-$index'),
              style: TextStyle(
                fontWeight: index == _highlightedIndex
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
      ],
    );
  }
}
