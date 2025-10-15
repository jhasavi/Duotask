import 'package:flutter/material.dart';
import '../screens/pairing_screen.dart';
import 'smart_task_form.dart';

class EmptyStateGuidance extends StatelessWidget {
  final String tabType;
  final bool isPaired;
  final String? partnerName;
  final VoidCallback? onPairWithSomeone;

  const EmptyStateGuidance({
    super.key,
    required this.tabType,
    required this.isPaired,
    this.partnerName,
    this.onPairWithSomeone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIcon(),
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _getTitle(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getDescription(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (tabType.toLowerCase()) {
      case 'shared':
        return isPaired ? Icons.task_alt : Icons.people_outline;
      case 'personal':
        return Icons.person_outline;
      case 'partner':
        return Icons.favorite_border;
      default:
        return Icons.task_outlined;
    }
  }

  String _getTitle() {
    switch (tabType) {
      case 'shared':
        return 'No Shared Tasks Yet';
      case 'personal':
        return 'No Personal Tasks Yet';
      case 'partner':
        return 'No Partner Tasks Yet';
      default:
        return 'No Tasks Yet';
    }
  }

  String _getDescription() {
    switch (tabType) {
      case 'shared':
        return 'Create tasks to work on together with your partner. Both of you will see all shared tasks here.';
      case 'personal':
        return 'Create personal tasks that only you can see and manage.';
      case 'partner':
        return 'Tasks that your partner creates and shares with you will appear here.';
      default:
        return 'Start by creating your first task!';
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (tabType.toLowerCase()) {
      case 'shared':
        if (!isPaired) {
          return Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openPairingScreen(context),
                icon: const Icon(Icons.people),
                label: const Text('Pair with Someone'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Personal Task'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          );
        } else {
          return ElevatedButton.icon(
            onPressed: () => _showAddTaskDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Shared Task'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          );
        }
      case 'personal':
        return ElevatedButton.icon(
          onPressed: () => _showAddTaskDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Create Task'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
      case 'partner':
        return OutlinedButton.icon(
          onPressed: () => _openPairingScreen(context),
          icon: const Icon(Icons.people),
          label: const Text('Manage Pairing'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
      default:
        return ElevatedButton.icon(
          onPressed: () => _showAddTaskDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Create Task'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
    }
  }

  void _openPairingScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PairingScreen(),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartTaskForm(
        onSubmit: (title, dueDate, urgent, repeatType) {
          // This would need to be handled by the parent widget
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(context).pop(),
        tabType: tabType,
        isPaired: isPaired,
        partnerName: partnerName,
      ),
    );
  }
}
