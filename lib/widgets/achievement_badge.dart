import 'package:flutter/material.dart';

enum AchievementType {
  firstTask,
  taskStreak,
  perfectWeek,
  teamPlayer,
  earlyBird,
  nightOwl,
  weekendWarrior,
  relationshipBuilder,
  goalCrusher,
  consistencyKing;

  String get title {
    switch (this) {
      case AchievementType.firstTask:
        return 'First Steps';
      case AchievementType.taskStreak:
        return 'On Fire!';
      case AchievementType.perfectWeek:
        return 'Perfect Week';
      case AchievementType.teamPlayer:
        return 'Team Player';
      case AchievementType.earlyBird:
        return 'Early Bird';
      case AchievementType.nightOwl:
        return 'Night Owl';
      case AchievementType.weekendWarrior:
        return 'Weekend Warrior';
      case AchievementType.relationshipBuilder:
        return 'Relationship Builder';
      case AchievementType.goalCrusher:
        return 'Goal Crusher';
      case AchievementType.consistencyKing:
        return 'Consistency King';
    }
  }

  String get description {
    switch (this) {
      case AchievementType.firstTask:
        return 'Completed your first task together!';
      case AchievementType.taskStreak:
        return 'Completed 5 tasks in a row!';
      case AchievementType.perfectWeek:
        return 'Completed all tasks for a whole week!';
      case AchievementType.teamPlayer:
        return 'Helped your partner complete 10 tasks!';
      case AchievementType.earlyBird:
        return 'Completed 5 tasks before 9 AM!';
      case AchievementType.nightOwl:
        return 'Completed 5 tasks after 9 PM!';
      case AchievementType.weekendWarrior:
        return 'Completed 10 tasks on weekends!';
      case AchievementType.relationshipBuilder:
        return 'Spent quality time on 20 tasks!';
      case AchievementType.goalCrusher:
        return 'Achieved 3 major goals together!';
      case AchievementType.consistencyKing:
        return 'Used the app for 30 days straight!';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementType.firstTask:
        return '🎯';
      case AchievementType.taskStreak:
        return '🔥';
      case AchievementType.perfectWeek:
        return '⭐';
      case AchievementType.teamPlayer:
        return '🤝';
      case AchievementType.earlyBird:
        return '🌅';
      case AchievementType.nightOwl:
        return '🦉';
      case AchievementType.weekendWarrior:
        return '⚔️';
      case AchievementType.relationshipBuilder:
        return '💝';
      case AchievementType.goalCrusher:
        return '💪';
      case AchievementType.consistencyKing:
        return '👑';
    }
  }

  Color get color {
    switch (this) {
      case AchievementType.firstTask:
        return Colors.blue;
      case AchievementType.taskStreak:
        return Colors.orange;
      case AchievementType.perfectWeek:
        return Colors.yellow.shade700;
      case AchievementType.teamPlayer:
        return Colors.green;
      case AchievementType.earlyBird:
        return Colors.lightBlue;
      case AchievementType.nightOwl:
        return Colors.purple;
      case AchievementType.weekendWarrior:
        return Colors.red;
      case AchievementType.relationshipBuilder:
        return Colors.pink;
      case AchievementType.goalCrusher:
        return Colors.indigo;
      case AchievementType.consistencyKing:
        return Colors.amber;
    }
  }
}

class AchievementBadge extends StatelessWidget {
  final AchievementType type;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final VoidCallback? onTap;

  const AchievementBadge({
    super.key,
    required this.type,
    required this.isUnlocked,
    this.unlockedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Badge Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked 
                    ? type.color.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: isUnlocked ? type.color : Colors.grey,
                  width: 3,
                ),
                boxShadow: isUnlocked ? [
                  BoxShadow(
                    color: type.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              child: Center(
                child: Text(
                  type.emoji,
                  style: TextStyle(
                    fontSize: 32,
                    color: isUnlocked ? type.color : Colors.grey,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Badge Title
            Text(
              type.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black87 : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Unlock Date
            if (isUnlocked && unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Unlocked ${_formatDate(unlockedAt!)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (difference / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }
}

class AchievementShowcase extends StatelessWidget {
  final List<AchievementType> unlockedAchievements;
  final int totalTasksCompleted;
  final int currentStreak;

  const AchievementShowcase({
    super.key,
    required this.unlockedAchievements,
    required this.totalTasksCompleted,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              const Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${unlockedAchievements.length}/10',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Tasks Completed',
                  totalTasksCompleted.toString(),
                  '✅',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Current Streak',
                  '$currentStreak days',
                  '🔥',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Achievements Grid
          if (unlockedAchievements.isNotEmpty) ...[
            const Text(
              'Unlocked Badges',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              children: unlockedAchievements.map((achievement) {
                return AchievementBadge(
                  type: achievement,
                  isUnlocked: true,
                  unlockedAt: DateTime.now().subtract(
                    Duration(days: unlockedAchievements.indexOf(achievement) * 3),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    '🎯',
                    style: TextStyle(fontSize: 32),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No achievements yet!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete tasks together to unlock badges!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
