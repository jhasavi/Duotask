import 'package:flutter/material.dart';
import '../models/task.dart';
import '../config/theme.dart';

class NudgeDialog extends StatelessWidget {
  final Task task;
  final String partnerName;
  final Future<bool> Function() onSend;

  const NudgeDialog({
    super.key,
    required this.task,
    required this.partnerName,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nudge Partner'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send a reminder to $partnerName about:'),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final success = await onSend();
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Nudge sent to $partnerName!'
                        : 'Failed to send nudge',
                  ),
                  backgroundColor:
                      success ? AppTheme.completedColor : AppTheme.urgentColor,
                ),
              );
            }
          },
          icon: const Icon(Icons.notifications_active),
          label: const Text('Send Nudge'),
        ),
      ],
    );
  }
}
