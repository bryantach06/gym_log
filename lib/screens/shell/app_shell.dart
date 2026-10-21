import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elapsed_timer.dart';
import '../exercise/exercise_library_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../session/active_session_screen.dart';
import '../settings/settings_screen.dart';

/// Signed-in root: bottom navigation across the four top-level tabs, plus a
/// "workout in progress" bar on every tab except Home (which has its own card).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onSeeAllHistory: () => _select(1)),
          const HistoryScreen(),
          const ExerciseLibraryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_index != 0) const ActiveWorkoutBar(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact strip showing the running workout; tapping it reopens the session.
class ActiveWorkoutBar extends StatelessWidget {
  const ActiveWorkoutBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is! SessionActive) return const SizedBox.shrink();
        return Material(
          color: theme.colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: gym.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Workout in progress'),
                        TextSpan(
                          text: '  ·  ${state.exercises.length} exercise'
                              '${state.exercises.length == 1 ? '' : 's'}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ]),
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElapsedTimer(
                    since: state.session.startedAt,
                    style: AppTheme.number(context, size: 18, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
