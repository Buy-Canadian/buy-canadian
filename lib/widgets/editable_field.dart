import 'package:flutter/material.dart';

class EditableField extends StatelessWidget {
  final String label;
  final String value;
  final String? helperText;
  final Function(String) onChanged;

  const EditableField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: helperText,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
