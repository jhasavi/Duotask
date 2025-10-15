import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Widget for task action buttons (add, refresh, etc.)
class TaskActionsWidget extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenPairTab;
  final bool isPaired;
  final bool isLoading;

  const TaskActionsWidget({
    super.key,
    required this.onAddTask,
    required this.onRefresh,
    this.onOpenPairTab,
    required this.isPaired,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        children: [
          // Add task button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppConstants.smallPadding),

          // Refresh button
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
          ),

          // Pair button (if not paired)
          if (!isPaired && onOpenPairTab != null) ...[
            const SizedBox(width: AppConstants.smallPadding),
            IconButton(
              onPressed: onOpenPairTab,
              icon: const Icon(Icons.people),
              tooltip: 'Pair with someone',
            ),
          ],
        ],
      ),
    );
  }
}
