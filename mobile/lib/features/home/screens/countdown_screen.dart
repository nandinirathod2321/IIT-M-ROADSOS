import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/countdown_overlay.dart';

/// Full-screen countdown overlay triggered by crash detection or
/// manual SOS activation. No bottom navigation bar.
class CountdownScreen extends StatelessWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CountdownOverlay(
      onComplete: () {
        // SOS dispatched — will be wired in a later prompt
        context.go('/');
      },
      onCancel: () {
        context.go('/');
      },
      onSendNow: () {
        // Immediate SOS — will be wired in a later prompt
        context.go('/');
      },
    );
  }
}
