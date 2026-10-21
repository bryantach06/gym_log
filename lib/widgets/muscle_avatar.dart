import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _abbreviations = {
  'chest': 'CH',
  'back': 'BK',
  'shoulders': 'SH',
  'biceps': 'BI',
  'triceps': 'TR',
  'legs': 'LG',
  'glutes': 'GL',
  'core': 'CO',
  'cardio': 'CA',
};

/// Rounded tile tinted with the muscle group's color, showing its abbreviation.
class MuscleAvatar extends StatelessWidget {
  final String muscleGroup;
  final double size;

  const MuscleAvatar({super.key, required this.muscleGroup, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = GymColors.of(context).muscleColor(muscleGroup);
    final label = _abbreviations[muscleGroup] ??
        muscleGroup.substring(0, muscleGroup.length.clamp(0, 2)).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
