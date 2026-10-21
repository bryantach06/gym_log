import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/set_entry.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'pr_badge.dart';
import 'set_badge.dart';
import 'weight_input_field.dart';

/// Column widths shared by [SetTableHeader] and [SetInputRow].
const _badgeWidth = 40.0;
const _prWidth = 34.0;
const _previousFlex = 5;
const _weightFlex = 5;
const _repsFlex = 4;
const _cellHeight = 46.0;

/// Header row for the set table: SET | PREVIOUS | weight unit | REPS.
class SetTableHeader extends StatelessWidget {
  final String weightLabel;
  const SetTableHeader({super.key, required this.weightLabel});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget cell(String text) => Text(text, style: style, textAlign: TextAlign.center);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _badgeWidth, child: cell('SET')),
          const SizedBox(width: 6),
          Expanded(flex: _previousFlex, child: cell('PREVIOUS')),
          const SizedBox(width: 6),
          Expanded(flex: _weightFlex, child: cell(weightLabel)),
          const SizedBox(width: 6),
          Expanded(flex: _repsFlex, child: cell('REPS')),
          const SizedBox(width: _prWidth),
        ],
      ),
    );
  }
}

enum _SetAction { warmup, dropset, remove }

class SetInputRow extends StatefulWidget {
  final SetEntry set;
  final int index;

  /// Same-position set from the last session, if any.
  final SetEntry? previous;
  final bool isLastSet;
  final String equipmentType;
  final double? barWeightKg;
  final bool isPR;
  final bool useLbs;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onWarmupToggled;
  final VoidCallback onDropsetToggled;
  final VoidCallback onRemove;
  final VoidCallback? onUsePrevious;

  const SetInputRow({
    super.key,
    required this.set,
    required this.index,
    this.previous,
    required this.isLastSet,
    required this.equipmentType,
    this.barWeightKg,
    this.isPR = false,
    this.useLbs = false,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onWarmupToggled,
    required this.onDropsetToggled,
    required this.onRemove,
    this.onUsePrevious,
  });

  @override
  State<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends State<SetInputRow> {
  late final TextEditingController _repsCtrl;
  bool _repsFocused = false;

  @override
  void initState() {
    super.initState();
    _repsCtrl = TextEditingController(
      text: widget.set.reps == 0 ? '' : '${widget.set.reps}',
    );
  }

  @override
  void didUpdateWidget(SetInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync the controller when the field is not focused to avoid
    // clobbering the user's in-progress input.
    if (!_repsFocused && oldWidget.set.reps != widget.set.reps) {
      final newText = widget.set.reps == 0 ? '' : '${widget.set.reps}';
      if (_repsCtrl.text != newText) {
        _repsCtrl.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey('set_${widget.index}_${widget.set.setNumber}'),
      direction: widget.isLastSet ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => widget.onRemove(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isPR ? gym.pr.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isPR ? gym.pr.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _badgeWidth,
              height: _cellHeight,
              child: Center(child: _badgeMenu(context)),
            ),
            const SizedBox(width: 6),
            Expanded(flex: _previousFlex, child: _previousCell(context)),
            const SizedBox(width: 6),
            Expanded(
              flex: _weightFlex,
              child: WeightInputField(
                key: ValueKey('weight_${widget.index}'),
                initialValue: widget.set.weightInput,
                equipmentType: widget.equipmentType,
                barWeightKg: widget.barWeightKg,
                useLbs: widget.useLbs,
                onChanged: widget.onWeightChanged,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: _repsFlex,
              child: Focus(
                onFocusChange: (focused) => setState(() => _repsFocused = focused),
                child: TextField(
                  controller: _repsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: AppTheme.number(context, size: 20),
                  decoration: const InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  ),
                  onChanged: (v) => widget.onRepsChanged(int.tryParse(v) ?? 0),
                ),
              ),
            ),
            SizedBox(
              width: _prWidth,
              height: _cellHeight,
              child: widget.isPR ? const Center(child: PRBadge()) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _previousCell(BuildContext context) {
    final theme = Theme.of(context);
    final prev = widget.previous;
    final text = prev == null || !isLogged(prev) ? '—' : setLabel(prev, widget.useLbs);
    return SizedBox(
      height: _cellHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: prev == null || !isLogged(prev) ? null : widget.onUsePrevious,
          child: Center(
            child: Text(
              text,
              style: AppTheme.number(context, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeMenu(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_SetAction>(
      tooltip: 'Set options',
      padding: EdgeInsets.zero,
      onSelected: (a) => switch (a) {
        _SetAction.warmup => widget.onWarmupToggled(),
        _SetAction.dropset => widget.onDropsetToggled(),
        _SetAction.remove => widget.onRemove(),
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: _SetAction.warmup,
          checked: widget.set.isWarmup,
          child: const Text('Warmup set'),
        ),
        CheckedPopupMenuItem(
          value: _SetAction.dropset,
          checked: widget.set.isDropset,
          child: const Text('Drop set'),
        ),
        if (!widget.isLastSet) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _SetAction.remove,
            child: Text('Remove set', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ],
      child: SetBadge(set: widget.set, size: 32),
    );
  }
}
