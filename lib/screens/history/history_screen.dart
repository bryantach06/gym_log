import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/session_history/session_history_cubit.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../models/workout_session.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/session_card.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<SessionHistoryCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final useLbs = context.watch<SettingsCubit>().state.useLbs;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<SessionHistoryCubit>().loadInitial(),
        edgeOffset: 120,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverAppBar.large(title: Text('History')),
            BlocBuilder<SessionHistoryCubit, SessionHistoryState>(
              builder: (context, state) {
                if (state is SessionHistoryError) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load history",
                      message: 'Pull down to try again.',
                    ),
                  );
                }
                if (state is! SessionHistoryLoaded) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (state.sessions.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.calendar_month_rounded,
                      title: 'Nothing logged yet',
                      message: 'Finish a workout and it will appear here.',
                    ),
                  );
                }
                final items = _groupByMonth(state.sessions);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = items[i];
                      if (item is String) {
                        return SectionHeader(
                          item,
                          padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 20, 4, 10),
                        );
                      }
                      final s = item as WorkoutSession;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SessionCard(
                          session: s,
                          useLbs: useLbs,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Interleaves "October 2026"-style headers with the (newest-first) sessions.
  List<Object> _groupByMonth(List<WorkoutSession> sessions) {
    final out = <Object>[];
    String? current;
    for (final s in sessions) {
      final month = DateFormat('MMMM y').format(s.startedAt);
      if (month != current) {
        out.add(month);
        current = month;
      }
      out.add(s);
    }
    return out;
  }
}
