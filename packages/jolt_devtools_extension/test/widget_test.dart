import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/models/filter_autocomplete.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/utils/filter_autocomplete.dart';

final _nodes = [
  JoltNode(
    id: 1,
    type: 'Signal',
    label: 'counter',
    debugType: 'store',
    isDisposed: false,
    flags: 0,
    valueType: 'int',
  ),
  JoltNode(
    id: 2,
    type: 'Computed',
    label: 'total',
    debugType: 'JoltBuilder',
    isDisposed: false,
    flags: 0,
    valueType: 'double',
  ),
];

void main() {
  testWidgets('方向键移动候选高亮，Enter 确认候选且保持焦点', (tester) async {
    await _pumpAutocompleteHarness(tester, initialText: 'de');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('debug'), findsOneWidget);
    expect(find.text('dep'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(_fieldText(tester), 'dep');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text(':'), findsOneWidget);
  });

  testWidgets('Tab 只向下循环候选，不上屏也不失焦', (tester) async {
    await _pumpAutocompleteHarness(tester, initialText: 'de');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_fieldText(tester), 'de');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'dep');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_fieldText(tester), 'de');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'deps');
  });

  testWidgets('Shift+Tab 只向上循环候选，不上屏也不失焦', (tester) async {
    await _pumpAutocompleteHarness(tester, initialText: 'de');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();

    expect(_fieldText(tester), 'de');
    expect(_fieldHasFocus(tester), isTrue);
    expect(_selectedSuggestionText(tester), 'deps');
  });

  testWidgets('Enter 确认候选后不让过滤框失焦', (tester) async {
    await _pumpAutocompleteHarness(tester, initialText: 'ty');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_fieldText(tester), 'type');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text(':'), findsOneWidget);
  });

  testWidgets('值候选上屏后追加空格并继续提示字段', (tester) async {
    await _pumpAutocompleteHarness(tester, initialText: 'ty');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_fieldText(tester), 'type:Computed ');
    expect(_fieldHasFocus(tester), isTrue);
    expect(find.text('type'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);
  });
}

Future<void> _pumpAutocompleteHarness(
  WidgetTester tester, {
  required String initialText,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _AutocompleteHarness(initialText: initialText),
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
  const _AutocompleteHarness({required this.initialText});

  final String initialText;

  @override
  State<_AutocompleteHarness> createState() => _AutocompleteHarnessState();
}

class _AutocompleteHarnessState extends State<_AutocompleteHarness> {
  late final _controller = TextEditingController(text: widget.initialText);
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
    return buildFilterAutocompleteSuggestions(
      input: _controller.text,
      caretOffset: _controller.selection.baseOffset < 0
          ? _controller.text.length
          : _controller.selection.baseOffset,
      nodes: _nodes,
    );
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
