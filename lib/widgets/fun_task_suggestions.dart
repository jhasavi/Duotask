import 'package:flutter/material.dart';
import '../models/relationship_type.dart';

class FunTaskSuggestions extends StatelessWidget {
  final RelationshipType relationshipType;
  final Function(String) onTaskSelected;

  const FunTaskSuggestions({
    super.key,
    required this.relationshipType,
    required this.onTaskSelected,
  });

  Map<String, List<String>> get _taskSuggestions {
    switch (relationshipType) {
      case RelationshipType.brothers:
        return {
          'Gaming': [
            '🏆 Beat that boss level together',
            '🎮 Set up gaming tournament',
            '🕹️ Try a new co-op game',
            '🏁 Race each other in Mario Kart',
            '🎯 Practice aim in FPS games'
          ],
          'Sports': [
            '⚽ Play soccer in the backyard',
            '🏀 Have a basketball shootout',
            '🏃‍♂️ Go for a run together',
            '🏋️‍♂️ Work out at the gym',
            '🚴‍♂️ Go cycling together'
          ],
          'Chores': [
            '🧹 Clean our shared room',
            '🧺 Do laundry together',
            '🍽️ Wash dishes after dinner',
            '🗑️ Take out the trash',
            '🧽 Clean the bathroom'
          ],
          'Adventures': [
            '🏔️ Plan a hiking trip',
            '🎪 Visit the amusement park',
            '🎬 Watch a movie together',
            '🍕 Try a new restaurant',
            '🎨 Take a painting class'
          ],
          'Tech': [
            '💻 Build a computer together',
            '📱 Learn a new app',
            '🎵 Create a playlist',
            '📸 Take cool photos',
            '🎬 Make a short video'
          ]
        };
      
      case RelationshipType.fatherSon:
        return {
          'Learning': [
            '📚 Read a book together',
            '🔬 Do a science experiment',
            '🌍 Learn about a new country',
            '🎨 Try a new hobby',
            '📖 Teach each other something'
          ],
          'Outdoor': [
            '🏕️ Go camping',
            '🎣 Go fishing',
            '🚴‍♂️ Ride bikes together',
            '🏃‍♂️ Play catch',
            '🌳 Plant a tree'
          ],
          'Projects': [
            '🔨 Build something together',
            '🚗 Fix the car',
            '🏠 Work on home improvement',
            '🎨 Paint a room',
            '🔧 Learn to use tools'
          ],
          'Skills': [
            '👨‍🍳 Cook dinner together',
            '💰 Learn about money',
            '🏠 Do household repairs',
            '🚗 Learn to drive',
            '💼 Practice job skills'
          ],
          'Bonding': [
            '🎮 Play video games',
            '🎬 Watch a movie',
            '🍕 Make pizza together',
            '🎵 Listen to music',
            '📸 Look at old photos'
          ]
        };
      
      case RelationshipType.roommates:
        return {
          'Cleaning': [
            '🧹 Deep clean the apartment',
            '🧺 Organize the laundry room',
            '🍽️ Clean the kitchen',
            '🚿 Scrub the bathroom',
            '🗑️ Take out all trash'
          ],
          'Cooking': [
            '👨‍🍳 Cook dinner together',
            '🥗 Meal prep for the week',
            '🍕 Make homemade pizza',
            '🍰 Bake cookies',
            '🥪 Pack lunches'
          ],
          'Shopping': [
            '🛒 Grocery shopping',
            '🧴 Buy cleaning supplies',
            '🛏️ Get new bedding',
            '🪑 Buy furniture',
            '🎨 Get decorations'
          ],
          'Bills': [
            '💰 Split utility bills',
            '📱 Pay rent together',
            '🛡️ Get renter\'s insurance',
            '🔌 Set up internet',
            '📺 Choose streaming services'
          ],
          'Decor': [
            '🎨 Paint a room',
            '🖼️ Hang pictures',
            '🌱 Buy plants',
            '💡 Install new lights',
            '🛋️ Rearrange furniture'
          ]
        };
      
      case RelationshipType.bestFriends:
        return {
          'Fun': [
            '🎉 Plan a surprise party',
            '🎭 Do karaoke night',
            '🎨 Paint together',
            '🎵 Create a playlist',
            '🎬 Have a movie marathon'
          ],
          'Adventures': [
            '🏔️ Go on a road trip',
            '🎪 Visit a theme park',
            '🏖️ Go to the beach',
            '🎯 Try escape room',
            '🎨 Take a pottery class'
          ],
          'Goals': [
            '💪 Start a fitness challenge',
            '📚 Read the same book',
            '🎯 Set monthly goals',
            '💰 Save money together',
            '🎓 Study for exams'
          ],
          'Support': [
            '💝 Surprise with gifts',
            '📞 Daily check-ins',
            '🎉 Celebrate achievements',
            '🤗 Be there when needed',
            '💌 Write encouraging notes'
          ],
          'Memories': [
            '📸 Take lots of photos',
            '📝 Start a journal together',
            '🎵 Create a friendship playlist',
            '🎨 Make friendship bracelets',
            '📚 Start a book club'
          ]
        };
      
      default:
        return {
          'Tasks': [
            '✅ Complete a project',
            '📝 Make a to-do list',
            '🎯 Set goals together',
            '📅 Plan the week',
            '💡 Brainstorm ideas'
          ],
          'Fun': [
            '🎉 Have fun together',
            '🎮 Play games',
            '🎬 Watch movies',
            '🍕 Eat together',
            '🎵 Listen to music'
          ],
          'Work': [
            '💼 Work on projects',
            '📊 Review progress',
            '🤝 Collaborate',
            '📈 Plan improvements',
            '🎯 Set objectives'
          ]
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              relationshipType.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              'Task Ideas for ${relationshipType.displayName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Categories
        ..._taskSuggestions.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              // Task suggestions for this category
              ...entry.value.map((task) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      task,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => onTaskSelected(task),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      tooltip: 'Add this task',
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 16),
            ],
          );
        }),
        
        // Quick Add Section
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Text(
                '💡 Quick Add Your Own Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the + button to add any of these suggestions, or create your own custom task!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
