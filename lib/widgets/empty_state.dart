import 'package:flutter/material.dart';

/// Centered icon + message for empty lists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
