import 'package:flutter/material.dart';

class JoltEditableScalarField extends StatefulWidget {
  const JoltEditableScalarField({
    super.key,
    required this.initialValue,
    required this.onSubmit,
    required this.onCancel,
  });

  final String initialValue;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<JoltEditableScalarField> createState() => _JoltEditableScalarFieldState();
}

class _JoltEditableScalarFieldState extends State<JoltEditableScalarField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: widget.onSubmit,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: widget.onCancel,
          ),
        ),
      ),
    );
  }
}
