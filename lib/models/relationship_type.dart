enum RelationshipType {
  brothers,
  fatherSon,
  motherDaughter,
  roommates,
  bestFriends,
  partners,
  siblings,
  cousins,
  mentorStudent,
  custom;

  String get displayName {
    switch (this) {
      case RelationshipType.brothers:
        return 'Brothers';
      case RelationshipType.fatherSon:
        return 'Father & Son';
      case RelationshipType.motherDaughter:
        return 'Mother & Daughter';
      case RelationshipType.roommates:
        return 'Roommates';
      case RelationshipType.bestFriends:
        return 'Best Friends';
      case RelationshipType.partners:
        return 'Partners';
      case RelationshipType.siblings:
        return 'Siblings';
      case RelationshipType.cousins:
        return 'Cousins';
      case RelationshipType.mentorStudent:
        return 'Mentor & Student';
      case RelationshipType.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case RelationshipType.brothers:
        return '👬';
      case RelationshipType.fatherSon:
        return '👨‍👦';
      case RelationshipType.motherDaughter:
        return '👩‍👧';
      case RelationshipType.roommates:
        return '🏠';
      case RelationshipType.bestFriends:
        return '🤝';
      case RelationshipType.partners:
        return '💑';
      case RelationshipType.siblings:
        return '👥';
      case RelationshipType.cousins:
        return '👨‍👩‍👧‍👦';
      case RelationshipType.mentorStudent:
        return '🎓';
      case RelationshipType.custom:
        return '✨';
    }
  }

  String get greeting {
    switch (this) {
      case RelationshipType.brothers:
        return 'Hey bro! Ready to tackle some tasks together?';
      case RelationshipType.fatherSon:
        return 'Let\'s work together, son!';
      case RelationshipType.motherDaughter:
        return 'Time for some mother-daughter bonding through tasks!';
      case RelationshipType.roommates:
        return 'Roomie, let\'s keep our space organized!';
      case RelationshipType.bestFriends:
        return 'Bestie, let\'s crush these tasks!';
      case RelationshipType.partners:
        return 'Partner, let\'s make our goals happen!';
      case RelationshipType.siblings:
        return 'Sibling power! Let\'s get things done!';
      case RelationshipType.cousins:
        return 'Cousin, let\'s team up!';
      case RelationshipType.mentorStudent:
        return 'Let\'s learn and grow together!';
      case RelationshipType.custom:
        return 'Ready to collaborate!';
    }
  }

  List<String> get funTaskCategories {
    switch (this) {
      case RelationshipType.brothers:
        return ['Gaming', 'Sports', 'Chores', 'Adventures', 'Tech'];
      case RelationshipType.fatherSon:
        return ['Learning', 'Outdoor', 'Projects', 'Skills', 'Bonding'];
      case RelationshipType.motherDaughter:
        return ['Cooking', 'Crafts', 'Shopping', 'Self-care', 'Adventures'];
      case RelationshipType.roommates:
        return ['Cleaning', 'Cooking', 'Shopping', 'Bills', 'Decor'];
      case RelationshipType.bestFriends:
        return ['Fun', 'Adventures', 'Goals', 'Support', 'Memories'];
      case RelationshipType.partners:
        return ['Date Night', 'Home', 'Goals', 'Adventures', 'Growth'];
      case RelationshipType.siblings:
        return ['Games', 'Chores', 'Projects', 'Fun', 'Support'];
      case RelationshipType.cousins:
        return ['Games', 'Adventures', 'Learning', 'Fun', 'Family'];
      case RelationshipType.mentorStudent:
        return ['Learning', 'Projects', 'Skills', 'Goals', 'Growth'];
      case RelationshipType.custom:
        return ['Tasks', 'Goals', 'Fun', 'Work', 'Life'];
    }
  }

  String get motivationalMessage {
    switch (this) {
      case RelationshipType.brothers:
        return 'Brothers in arms, brothers in tasks! 💪';
      case RelationshipType.fatherSon:
        return 'Building memories and skills together! 🛠️';
      case RelationshipType.motherDaughter:
        return 'Mother-daughter magic in action! ✨';
      case RelationshipType.roommates:
        return 'Roommates make the dream work! 🏠';
      case RelationshipType.bestFriends:
        return 'Best friends, best team! 🤝';
      case RelationshipType.partners:
        return 'Partners in crime and success! 💑';
      case RelationshipType.siblings:
        return 'Sibling synergy at its best! 👥';
      case RelationshipType.cousins:
        return 'Cousin power activated! 👨‍👩‍👧‍👦';
      case RelationshipType.mentorStudent:
        return 'Learning and growing together! 🎓';
      case RelationshipType.custom:
        return 'Custom collaboration magic! ✨';
    }
  }
}
