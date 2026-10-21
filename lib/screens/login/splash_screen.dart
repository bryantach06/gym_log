import 'package:flutter/material.dart';
import '../../widgets/brand_mark.dart';

/// Shown while Firebase restores the signed-in user, so the login screen
/// doesn't flash for users who are already signed in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: BrandMark(size: 56, showWordmark: false)),
    );
  }
}
