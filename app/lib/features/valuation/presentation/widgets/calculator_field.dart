import 'package:flutter/material.dart';

/// A number typed into one of the calculators (import cost, financing):
/// outlined, with its unit as a suffix and an optional hint under it;
/// [onChanged] works the result out again.
class const CalculatorField({
  required final TextEditingController controller,
  required final String label,
  required final String suffix,
  required final VoidCallback onChanged,
  final String? helper,
  final bool decimal = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
