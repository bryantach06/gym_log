import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/section_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          final cubit = context.read<SettingsCubit>();
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Profile')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.list(
                  children: [
                    const _ProfileCard(),
                    const SectionHeader('Units'),
                    _SettingCard(
                      title: 'Weight unit',
                      subtitle: 'Data is stored in kg and converted for display.',
                      trailing: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('kg')),
                          ButtonSegment(value: true, label: Text('lbs')),
                        ],
                        selected: {settings.useLbs},
                        onSelectionChanged: (v) => cubit.setUseLbs(v.first),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: const Text('Default bar weight'),
                        subtitle: const Text('Used for new custom barbell exercises'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${trimNumber(settings.defaultBarWeightKg)} kg',
                              style: AppTheme.number(context, size: 20),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                        onTap: () => _editBarWeight(context, settings.defaultBarWeightKg),
                      ),
                    ),
                    const SectionHeader('Appearance'),
                    _SettingCard(
                      title: 'Theme',
                      trailing: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                          ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (v) => cubit.setThemeMode(v.first),
                      ),
                    ),
                    const SectionHeader('Account'),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                        title: Text('Sign out',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.error)),
                        onTap: () => context.read<AuthCubit>().signOut(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(child: Text('GymLog', style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editBarWeight(BuildContext context, double current) {
    final ctrl = TextEditingController(text: trimNumber(current));
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Default bar weight'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          style: AppTheme.number(context, size: 24),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                context.read<SettingsCubit>().setDefaultBarWeight(val);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (auth is! AuthAuthenticated) return const SizedBox.shrink();
        final name = auth.user.displayName?.trim();
        final email = auth.user.email ?? '';
        final display = (name == null || name.isEmpty) ? email : name;
        final initial = display.isEmpty ? '?' : display[0].toUpperCase();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: gym.accent,
                  child: Text(initial, style: AppTheme.number(context, size: 26, color: gym.onAccent)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(display, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                      if (email.isNotEmpty && email != display)
                        Text(email, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingCard({required this.title, this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: trailing),
          ],
        ),
      ),
    );
  }
}
