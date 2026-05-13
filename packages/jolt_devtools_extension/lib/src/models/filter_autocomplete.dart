enum FilterAutocompleteSuggestionKind {
  field,
  operator,
  value,
  snippet,
}

class FilterAutocompleteSuggestion {
  final String label;
  final String insertText;
  final FilterAutocompleteSuggestionKind kind;
  final int replacementStart;
  final int replacementEnd;
  final bool appendSpace;
  final String completionSuffix;
  final String postInsertText;
  final int? postInsertOffset;
  final int? caretOffset;

  const FilterAutocompleteSuggestion({
    required this.label,
    required this.insertText,
    required this.kind,
    required this.replacementStart,
    required this.replacementEnd,
    this.appendSpace = false,
    this.completionSuffix = '',
    this.postInsertText = '',
    this.postInsertOffset,
    this.caretOffset,
  });

  String applyTo(String input) {
    final replacementText = '$insertText${appendSpace ? ' ' : ''}'
        '$completionSuffix';
    final replaced = input.replaceRange(
      replacementStart,
      replacementEnd,
      replacementText,
    );
    if (postInsertText.isEmpty || postInsertOffset == null) {
      return replaced;
    }
    final adjustedPostInsertOffset = postInsertOffset! +
        (replacementText.length - (replacementEnd - replacementStart));
    return replaced.replaceRange(
      adjustedPostInsertOffset,
      adjustedPostInsertOffset,
      postInsertText,
    );
  }

  int caretOffsetAfterApply() {
    if (caretOffset != null) return caretOffset!;
    final replacementTextLength =
        insertText.length + (appendSpace ? 1 : 0) + completionSuffix.length;
    if (postInsertText.isNotEmpty && postInsertOffset != null) {
      return postInsertOffset! +
          (replacementTextLength - (replacementEnd - replacementStart)) +
          postInsertText.length;
    }
    return replacementStart + replacementTextLength;
  }

  @override
  String toString() => label;
}
