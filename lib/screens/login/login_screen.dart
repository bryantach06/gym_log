import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_mark.dart';
import 'email_login_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final display = theme.textTheme.displayLarge?.copyWith(fontSize: 76, height: 0.92);

    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Stack(
            children: [
              const Positioned(top: -90, right: -140, child: PlateRings(size: 420)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 36),
                      const Spacer(),
                      Text('LIFT.', style: display),
                      Text('LOG.', style: display),
                      Text('PROGRESS.', style: display?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 16),
                      Text(
                        'Every set, every session, every PR —\nin one place.',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: gym.accent,
                            foregroundColor: gym.onAccent,
                          ),
                          onPressed: loading
                              ? null
                              : () => context.read<AuthCubit>().signInWithGoogle(),
                          child: loading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: theme.colorScheme.onSurface),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _GoogleG(color: gym.onAccent),
                                    const SizedBox(width: 12),
                                    const Text('Continue with Google'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.mail_outline_rounded),
                          label: const Text('Continue with email'),
                          onPressed: loading
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  final Color color;
  const _GoogleG({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
      child: Text('G',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color, height: 1)),
    );
  }
}
