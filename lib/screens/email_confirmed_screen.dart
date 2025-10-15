import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';

class EmailConfirmedScreen extends StatelessWidget {
  const EmailConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Confirmed')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Your email has been confirmed!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can now sign in to your account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // If a session exists, navigate to root; otherwise go to AuthScreen
                final user = Supabase.instance.client.auth.currentUser;
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => user == null
                          ? const AuthScreen()
                          : const _PostConfirmRedirect(),
                    ),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple redirect target that pops to root; used if user is already signed in
class _PostConfirmRedirect extends StatelessWidget {
  const _PostConfirmRedirect();
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
