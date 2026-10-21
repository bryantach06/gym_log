import 'package:flutter/material.dart';

/// Small uppercase heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 24, 4, 10),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
