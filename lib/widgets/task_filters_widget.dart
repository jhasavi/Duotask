import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Widget for task filtering and sorting controls
class TaskFiltersWidget extends StatelessWidget {
  final String currentFilter;
  final String currentSort;
  final bool isPaired;
  final Function(String) onFilterChanged;
  final Function(String) onSortChanged;

  const TaskFiltersWidget({
    super.key,
    required this.currentFilter,
    required this.currentSort,
    required this.isPaired,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        if (!isPaired) _buildPersonalFilters(context),
        if (isPaired) _buildPairedFilters(context),
        
        const SizedBox(height: AppConstants.smallPadding),
        
        // Sort options
        _buildSortOptions(context),
      ],
    );
  }

  Widget _buildPersonalFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Row(
        children: [
          _buildFilterChip(context, 'all', 'All Tasks', Icons.list),
          const SizedBox(width: AppConstants.smallPadding),
          _buildFilterChip(context, 'mine', 'My Tasks', Icons.person),
        ],
      ),
    );
  }

  Widget _buildPairedFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Row(
        children: [
          _buildFilterChip(context, 'all', 'All Tasks', Icons.list),
          const SizedBox(width: AppConstants.smallPadding),
          _buildFilterChip(context, 'mine', 'My Tasks', Icons.person),
          const SizedBox(width: AppConstants.smallPadding),
          _buildFilterChip(context, 'partner', 'Partner Tasks', Icons.people),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String value, String label, IconData icon) {
    final isSelected = currentFilter == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => onFilterChanged(value),
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[200],
      side: BorderSide(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
      ),
    );
  }

  Widget _buildSortOptions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          _buildSortChip(context, 'newest', 'Newest'),
          const SizedBox(width: 8),
          _buildSortChip(context, 'oldest', 'Oldest'),
        ],
      ),
    );
  }

  Widget _buildSortChip(BuildContext context, String value, String label) {
    final isSelected = currentSort == value;
    
    return GestureDetector(
      onTap: () => onSortChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
