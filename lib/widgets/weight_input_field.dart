import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/weight_calculator.dart';
import '../utils/unit_converter.dart';
import 'tap_to_edit.dart';

/// Compact numeric cell for the set table. The unit lives in the column
/// header; for barbell / dumbbell entries the derived total is shown below.
class WeightInputField extends StatefulWidget {
  final double initialValue;
  final String equipmentType;
  final double? barWeightKg;
  final bool useLbs;
  final ValueChanged<double> onChanged;

  const WeightInputField({
    super.key,
    required this.initialValue,
    required this.equipmentType,
    this.barWeightKg,
    this.useLbs = false,
    required this.onChanged,
  });

  @override
  State<WeightInputField> createState() => _WeightInputFieldState();
}

class _WeightInputFieldState extends State<WeightInputField> {
  late final TextEditingController _ctrl;
  final _focusNode = FocusNode();
  late double _valueKg; // always stored in kg internally
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _valueKg = widget.initialValue;
    _ctrl = TextEditingController(text: _displayText(_valueKg));
  }

  @override
  void didUpdateWidget(WeightInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the unit system changed, reformat the displayed value.
    if (oldWidget.useLbs != widget.useLbs && !_focused) {
      _ctrl.text = _displayText(_valueKg);
    }

    // If the underlying value changed externally (e.g. "use previous")
    // and the field isn't focused, sync it.
    if (!_focused && oldWidget.initialValue != widget.initialValue) {
      _valueKg = widget.initialValue;
      _ctrl.text = _displayText(_valueKg);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _displayText(double kg) => kg == 0 ? '' : displayNumber(kg, widget.useLbs);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTotal = hasDerivedTotal(widget.equipmentType) && _valueKg > 0;
    final total = deriveTotal(widget.equipmentType, _valueKg, widget.barWeightKg);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            // On blur, reformat to clean up trailing dots / extra decimals.
            if (!focused) _ctrl.text = _displayText(_valueKg);
          },
          child: Semantics(
            label: weightInputLabel(widget.equipmentType, useLbs: widget.useLbs),
            child: TapToEdit(
              focusNode: _focusNode,
              controller: _ctrl,
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: AppTheme.number(context, size: 20),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                ),
                onChanged: (v) {
                  final displayVal = double.tryParse(v) ?? 0;
                  // Convert display value back to kg for internal storage.
                  setState(() => _valueKg = fromDisplayWeight(displayVal, widget.useLbs));
                  widget.onChanged(_valueKg);
                },
              ),
            ),
          ),
        ),
        if (showTotal)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '= ${displayNumber(total, widget.useLbs)} ${unitLabel(widget.useLbs)}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
      ],
    );
  }
}
