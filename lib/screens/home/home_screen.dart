import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/session/session_bloc.dart';
import '../../blocs/session_history/session_history_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/workout_session.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/unit_converter.dart';
import '../../widgets/elapsed_timer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/session_card.dart';
import '../../widgets/stat_tile.dart';
import '../history/session_detail_screen.dart';
import '../session/active_session_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeAllHistory;

  const HomeScreen({super.key, this.onSeeAllHistory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SessionHistoryCubit>().loadInitial();
    // Resume draft session if exists
    context.read<SessionBloc>().add(const SessionResumed());
  }

  void _openSession() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final useLbs = context.watch<SettingsCubit>().state.useLbs;

    return Scaffold(
      body: BlocListener<SessionBloc, SessionState>(
        listenWhen: (_, state) => state is SessionComplete,
        listener: (context, state) {
          // Newly finished workout should appear in Recent Sessions.
          context.read<SessionHistoryCubit>().loadInitial();
        },
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => context.read<SessionHistoryCubit>().loadInitial(),
            child: BlocBuilder<SessionHistoryCubit, SessionHistoryState>(
              builder: (context, history) {
                final sessions =
                    history is SessionHistoryLoaded ? history.sessions : const <WorkoutSession>[];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    const _Greeting(),
                    const SizedBox(height: 20),
                    BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, state) => state is SessionActive
                          ? _ActiveWorkoutCard(session: state, onTap: _openSession)
                          : _StartWorkoutCard(
                              loading: state is SessionLoading,
                              onTap: () {
                                context.read<SessionBloc>().add(SessionStarted());
                                _openSession();
                              },
                            ),
                    ),
                    const SectionHeader('This week'),
                    _WeekCard(sessions: sessions, useLbs: useLbs),
                    SectionHeader(
                      'Recent workouts',
                      actionLabel: sessions.isEmpty ? null : 'See all',
                      onAction: widget.onSeeAllHistory,
                    ),
                    if (history is SessionHistoryLoading || history is SessionHistoryInitial)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (history is SessionHistoryError)
                      EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: "Couldn't load workouts",
                        message: 'Pull down to try again.',
                      )
                    else if (sessions.isEmpty)
                      const EmptyState(
                        icon: Icons.fitness_center_rounded,
                        title: 'No workouts yet',
                        message: 'Your finished sessions will show up here.',
                      )
                    else
                      for (final s in sessions.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SessionCard(
                            session: s,
                            useLbs: useLbs,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting
// ---------------------------------------------------------------------------

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final auth = context.watch<AuthCubit>().state;
    final fullName = auth is AuthAuthenticated ? auth.user.displayName : null;
    final firstName = (fullName ?? '').trim().split(' ').first;
    final h = now.hour;
    final greeting = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE, MMM d').format(now).toUpperCase(),
            style: theme.textTheme.labelSmall),
        const SizedBox(height: 6),
        Text(
          firstName.isEmpty ? '$greeting.' : '$greeting,\n$firstName.',
          style: theme.textTheme.displaySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Start / resume hero
// ---------------------------------------------------------------------------

class _StartWorkoutCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _StartWorkoutCard({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    final theme = Theme.of(context);
    return Material(
      color: gym.accent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START WORKOUT',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: gym.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Empty session — add exercises as you go',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: gym.onAccent.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: gym.onAccent, shape: BoxShape.circle),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: gym.accent),
                      )
                    : Icon(Icons.play_arrow_rounded, size: 32, color: gym.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  final SessionActive session;
  final VoidCallback onTap;

  const _ActiveWorkoutCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final sets = session.exercises.fold<int>(0, (n, e) => n + e.sets.length);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: gym.accent.withValues(alpha: 0.6), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: gym.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('IN PROGRESS',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workoutTitle(session.session.startedAt),
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${session.exercises.length} exercises  ·  $sets sets',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ElapsedTimer(
                    since: session.session.startedAt,
                    style: AppTheme.number(context, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// This week
// ---------------------------------------------------------------------------

class _WeekCard extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final bool useLbs;

  const _WeekCard({required this.sessions, required this.useLbs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final thisWeek = sessions.where((s) => !s.startedAt.isBefore(monday)).toList();
    final trainedDays = thisWeek.map((s) => s.startedAt.weekday).toSet();
    final time = thisWeek.fold<Duration>(Duration.zero, (d, s) => d + (s.duration ?? Duration.zero));
    final volume = thisWeek.fold<double>(0, (v, s) => v + (s.volumeKg ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  _DayDot(
                    label: 'MTWTFSS'[d - 1],
                    trained: trainedDays.contains(d),
                    isToday: d == today.weekday,
                    isFuture: d > today.weekday,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Workouts', value: '${thisWeek.length}')),
                Expanded(child: StatTile(label: 'Time', value: formatDuration(time))),
                Expanded(
                  child: StatTile(
                    label: 'Volume',
                    value: formatVolume(volume, useLbs),
                    unit: unitLabel(useLbs),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool trained;
  final bool isToday;
  final bool isFuture;

  const _DayDot({
    required this.label,
    required this.trained,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? theme.colorScheme.onSurface : null,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trained
                ? gym.accent
                : (isFuture ? Colors.transparent : theme.colorScheme.surfaceContainerHighest),
            border: isToday && !trained
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : (isFuture ? Border.all(color: theme.colorScheme.outlineVariant) : null),
          ),
          child: trained ? Icon(Icons.check_rounded, size: 18, color: gym.onAccent) : null,
        ),
      ],
    );
  }
}
