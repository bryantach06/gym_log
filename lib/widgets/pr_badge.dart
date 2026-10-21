import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small gold "PR" pill.
class PRBadge extends StatelessWidget {
  const PRBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: gym.pr,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PR',
        style: AppTheme.number(context, size: 13, color: gym.onPr),
      ),
    );
  }

  /// Celebratory toast for a new personal record.
  static void show(BuildContext context, String message) {
    final gym = GymColors.of(context);
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: gym.pr,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: gym.onPr),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.titleMedium?.copyWith(color: gym.onPr),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
