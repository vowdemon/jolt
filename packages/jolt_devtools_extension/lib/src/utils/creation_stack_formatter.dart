String formatCreationStackForDisplay(String? rawStack) {
  if (rawStack == null || rawStack.isEmpty) {
    return "";
  }

  final lines = rawStack.split("\n");
  final firstJoltIndex = _findFirstJoltFrameIndex(lines);
  if (firstJoltIndex == null) {
    return rawStack;
  }

  final trimmedLines =
      lines.skip(_findContiguousJoltBlockEnd(lines, firstJoltIndex) + 1);
  return trimmedLines.join("\n").trim();
}

int? _findFirstJoltFrameIndex(List<String> lines) {
  for (var index = 0; index < lines.length; index++) {
    if (_isJoltPackageFrame(lines[index])) {
      return index;
    }
  }
  return null;
}

int _findContiguousJoltBlockEnd(List<String> lines, int startIndex) {
  var endIndex = startIndex;
  while (
      endIndex + 1 < lines.length && _isJoltPackageFrame(lines[endIndex + 1])) {
    endIndex++;
  }
  return endIndex;
}

bool _isJoltPackageFrame(String line) {
  return line.contains("package:jolt/");
}
