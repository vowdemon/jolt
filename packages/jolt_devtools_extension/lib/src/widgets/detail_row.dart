import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that displays a detail row with label and value.
class DetailRow extends StatelessWidget {
  final String label;
  final dynamic
      value; // Can be any type, will be converted to string for display
  final bool showCopyButton;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.showCopyButton = false,
  });

  static const textStyle = TextStyle(fontSize: 13, height: 16 / 13);

  /// Converts value to string for display (max 200 chars)
  String get _displayValue {
    final str = value?.toString() ?? 'null';
    if (str.length > 200) {
      return '${str.substring(0, 200)}...';
    }
    return str;
  }

  /// Gets full value string for copying
  String get _fullValue {
    return value?.toString() ?? 'null';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 20,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            Expanded(
              child: showCopyButton
                  ? _CopyableValue(
                      displayValue: _displayValue,
                      fullValue: _fullValue,
                    )
                  : Text(
                      _displayValue,
                      style: textStyle,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that displays a value with a copy button that appears on hover.
class _CopyableValue extends StatefulWidget {
  final String displayValue; // Displayed value (truncated)
  final String fullValue; // Full value for copying

  const _CopyableValue({
    required this.displayValue,
    required this.fullValue,
  });

  @override
  State<_CopyableValue> createState() => _CopyableValueState();
}

class _CopyableValueState extends State<_CopyableValue> {
  bool _isHovered = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.fullValue));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.displayValue,
              style: DetailRow.textStyle,
            ),
            if (_isHovered)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyToClipboard,
                      tooltip: 'Copy to clipboard',
                      padding: EdgeInsets.zero,
                      iconSize: 12,
                      color: Colors.grey.shade400,
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
