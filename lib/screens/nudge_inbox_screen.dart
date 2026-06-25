import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/nudge_service.dart';
import '../services/auth_service.dart';
import '../config/theme.dart';

class NudgeInboxScreen extends StatelessWidget {
  const NudgeInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudges'),
        actions: [
          Consumer<NudgeService>(
            builder: (context, nudgeService, _) {
              if (nudgeService.unreadCount == 0 || userId == null) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: () => nudgeService.markAllAsRead(userId),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NudgeService>(
        builder: (context, nudgeService, _) {
          if (nudgeService.isLoading && nudgeService.nudges.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (nudgeService.nudges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No nudges yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Long-press a shared task to nudge your partner',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: nudgeService.nudges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final nudge = nudgeService.nudges[index];
              return Card(
                color: nudge.read
                    ? null
                    : AppTheme.primaryColor.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: nudge.read
                        ? AppTheme.textSecondary.withOpacity(0.2)
                        : AppTheme.primaryColor,
                    child: Icon(
                      Icons.notifications_active,
                      color: nudge.read ? AppTheme.textSecondary : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(nudge.message),
                  subtitle: Text(timeago.format(nudge.createdAt)),
                  onTap: () {
                    if (!nudge.read && userId != null) {
                      nudgeService.markAsRead(nudge.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
