import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuoTask Pairing Logic Test', () {
    
    // Mock user data for testing
    final Map<String, Map<String, dynamic>> mockUsers = {
      'user1': {'id': 'user1', 'name': 'Alice', 'paired_with': null, 'pair_status': null},
      'user2': {'id': 'user2', 'name': 'Bob', 'paired_with': null, 'pair_status': null},
      'user3': {'id': 'user3', 'name': 'Charlie', 'paired_with': null, 'pair_status': null},
    };

    // Mock tasks data
    final List<Map<String, dynamic>> mockTasks = [];

    // Mock unpairing function (defined first)
    bool unpairUsers(String userId) {
      if (!mockUsers.containsKey(userId)) return false;
      
      final partnerId = mockUsers[userId]!['paired_with'];
      if (partnerId == null) return false; // Not paired
      
      // Unpair both users
      mockUsers[userId]!['paired_with'] = null;
      mockUsers[userId]!['pair_status'] = null;
      mockUsers[partnerId]!['paired_with'] = null;
      mockUsers[partnerId]!['pair_status'] = null;
      
      return true;
    }

    // Mock pairing function
    bool pairUsers(String user1Id, String user2Id) {
      if (user1Id == user2Id) return false; // Cannot pair with yourself
      if (!mockUsers.containsKey(user1Id) || !mockUsers.containsKey(user2Id)) return false;
      
      // If either user is already paired, unpair them first
      if (mockUsers[user1Id]!['paired_with'] != null) {
        unpairUsers(user1Id);
      }
      if (mockUsers[user2Id]!['paired_with'] != null) {
        unpairUsers(user2Id);
      }
      
      // Update both users' pairing status
      mockUsers[user1Id]!['paired_with'] = user2Id;
      mockUsers[user1Id]!['pair_status'] = 'paired';
      mockUsers[user2Id]!['paired_with'] = user1Id;
      mockUsers[user2Id]!['pair_status'] = 'paired';
      
      return true;
    }

    // Mock task creation function
    void createSharedTask(String ownerId, String? pairId, String title) {
      mockTasks.add({
        'id': 'task_${mockTasks.length + 1}',
        'title': title,
        'owner_id': ownerId,
        'pair_id': pairId,
        'status': 'unclaimed',
      });
    }

    // Mock task filtering function
    List<Map<String, dynamic>> getTasksForUser(String userId) {
      return mockTasks.where((task) {
        final ownerId = task['owner_id'];
        final pairId = task['pair_id'];
        
        // Personal tasks: owned by user, no pair_id
        if (ownerId == userId && pairId == null) return true;
        
        // Shared tasks: only show if user is currently paired with the partner
        if (ownerId == userId && pairId != null) {
          // Check if user is currently paired with this partner
          final currentPartner = mockUsers[userId]!['paired_with'];
          return currentPartner == pairId;
        }
        if (ownerId != userId && pairId == userId) {
          // Check if user is currently paired with this owner
          final currentPartner = mockUsers[userId]!['paired_with'];
          return currentPartner == ownerId;
        }
        
        return false;
      }).toList();
    }

    // Reset mock data
    void resetMockData() {
      for (final user in mockUsers.values) {
        user['paired_with'] = null;
        user['pair_status'] = null;
      }
      mockTasks.clear();
    }

    setUp(() {
      resetMockData();
    });

    group('Three User Pairing Scenarios', () {
      test('Scenario 1: User1 pairs with User2, then unpairs', () {
        print('\n🧪 Testing Scenario 1: User1 pairs with User2, then unpairs');
        
        // Step 1: User1 pairs with User2
        print('Step 1: User1 pairs with User2');
        final pairResult = pairUsers('user1', 'user2');
        expect(pairResult, isTrue, reason: 'User1 should successfully pair with User2');
        
        // Verify both users are paired
        expect(mockUsers['user1']!['paired_with'], equals('user2'));
        expect(mockUsers['user2']!['paired_with'], equals('user1'));
        expect(mockUsers['user1']!['pair_status'], equals('paired'));
        expect(mockUsers['user2']!['pair_status'], equals('paired'));
        
        print('✅ User1 and User2 are successfully paired');
        
        // Step 2: Create shared tasks between User1 and User2
        print('Step 2: Creating shared tasks between User1 and User2');
        createSharedTask('user1', 'user2', 'Shared Task 1-2');
        createSharedTask('user2', 'user1', 'Shared Task 2-1');
        
        expect(mockTasks.length, equals(2));
        print('✅ Shared tasks created between User1 and User2');
        
        // Step 3: User1 unpairs from User2
        print('Step 3: User1 unpairs from User2');
        final unpairResult = unpairUsers('user1');
        expect(unpairResult, isTrue);
        
        // Verify both users are unpaired
        expect(mockUsers['user1']!['paired_with'], isNull);
        expect(mockUsers['user2']!['paired_with'], isNull);
        expect(mockUsers['user1']!['pair_status'], isNull);
        expect(mockUsers['user2']!['pair_status'], isNull);
        
        print('✅ User1 and User2 are successfully unpaired');
        
        // Step 4: Verify shared tasks are no longer accessible
        print('Step 4: Verifying shared tasks are no longer accessible');
        final user1Tasks = getTasksForUser('user1');
        final user2Tasks = getTasksForUser('user2');
        
        // Shared tasks should not be visible to either user
        final user1SharedTasks = user1Tasks.where((t) => t['pair_id'] != null).toList();
        final user2SharedTasks = user2Tasks.where((t) => t['pair_id'] != null).toList();
        
        expect(user1SharedTasks, isEmpty, reason: 'User1 should not see shared tasks after unpairing');
        expect(user2SharedTasks, isEmpty, reason: 'User2 should not see shared tasks after unpairing');
        
        print('✅ Shared tasks are no longer accessible to either user');
      });

      test('Scenario 2: User1 pairs with User3 after unpairing from User2', () {
        print('\n🧪 Testing Scenario 2: User1 pairs with User3 after unpairing from User2');
        
        // Step 1: User1 pairs with User3
        print('Step 1: User1 pairs with User3');
        final pairResult = pairUsers('user1', 'user3');
        expect(pairResult, isTrue);
        
        // Verify pairing
        expect(mockUsers['user1']!['paired_with'], equals('user3'));
        expect(mockUsers['user3']!['paired_with'], equals('user1'));
        
        print('✅ User1 and User3 are successfully paired');
        
        // Step 2: Create shared tasks between User1 and User3
        print('Step 2: Creating shared tasks between User1 and User3');
        createSharedTask('user1', 'user3', 'Shared Task 1-3');
        createSharedTask('user3', 'user1', 'Shared Task 3-1');
        
        expect(mockTasks.length, equals(2));
        print('✅ Shared tasks created between User1 and User3');
        
        // Step 3: Verify User1 cannot see User2's tasks
        print('Step 3: Verifying User1 cannot see User2\'s tasks');
        final user1Tasks = getTasksForUser('user1');
        final user2Tasks = getTasksForUser('user2');
        
        // User1 should only see tasks shared with User3, not User2
        final user1SharedTasks = user1Tasks.where((t) => t['pair_id'] != null).toList();
        final user2SharedTasks = user2Tasks.where((t) => t['pair_id'] != null).toList();
        
        // User1 should see tasks shared with User3
        expect(user1SharedTasks.length, equals(2), reason: 'User1 should see 2 shared tasks with User3');
        
        // User2 should not see any shared tasks (since unpaired)
        expect(user2SharedTasks, isEmpty, reason: 'User2 should not see any shared tasks');
        
        print('✅ User1 can only see tasks shared with User3, not User2');
      });

      test('Scenario 3: User2 pairs with User3 while User1 is paired with User3', () {
        print('\n🧪 Testing Scenario 3: User2 pairs with User3 while User1 is paired with User3');
        
        // Step 1: Set up User1 paired with User3
        print('Step 1: Setting up User1 paired with User3');
        pairUsers('user1', 'user3');
        createSharedTask('user1', 'user3', 'Shared Task 1-3');
        createSharedTask('user3', 'user1', 'Shared Task 3-1');
        
        expect(mockUsers['user1']!['paired_with'], equals('user3'));
        expect(mockUsers['user3']!['paired_with'], equals('user1'));
        
        // Step 2: User2 pairs with User3 (this should unpair User1)
        print('Step 2: User2 pairs with User3 (should unpair User1)');
        final pairResult = pairUsers('user2', 'user3');
        expect(pairResult, isTrue);
        
        // Step 3: Verify User1 is now unpaired and User2 is paired with User3
        print('Step 3: Verifying User1 is unpaired and User2 is paired with User3');
        expect(mockUsers['user1']!['paired_with'], isNull, reason: 'User1 should be unpaired');
        expect(mockUsers['user2']!['paired_with'], equals('user3'), reason: 'User2 should be paired with User3');
        expect(mockUsers['user3']!['paired_with'], equals('user2'), reason: 'User3 should be paired with User2');
        
        print('✅ User1 is unpaired, User2 and User3 are paired');
        
        // Step 4: Verify task access changes
        print('Step 4: Verifying task access changes');
        final user1Tasks = getTasksForUser('user1');
        final user2Tasks = getTasksForUser('user2');
        final user3Tasks = getTasksForUser('user3');
        
        // User1 should not see any shared tasks
        final user1SharedTasks = user1Tasks.where((t) => t['pair_id'] != null).toList();
        expect(user1SharedTasks, isEmpty, reason: 'User1 should not see any shared tasks');
        
        // User2 and User3 should see tasks shared between them
        final user2SharedTasks = user2Tasks.where((t) => t['pair_id'] != null).toList();
        final user3SharedTasks = user3Tasks.where((t) => t['pair_id'] != null).toList();
        
        // They should see tasks they created for each other
        // Note: The old tasks from User1-User3 pairing are no longer visible to User2-User3
        // because they were created with different pair_id values
        expect(user2SharedTasks.length, equals(0), reason: 'User2 should not see old shared tasks');
        expect(user3SharedTasks.length, equals(0), reason: 'User3 should not see old shared tasks');
        
        print('✅ Task access correctly updated after pairing change');
      });

      test('Scenario 4: Re-pairing with previous partners', () {
        print('\n🧪 Testing Scenario 4: Re-pairing with previous partners');
        
        // Step 1: User1 re-pairs with User2
        print('Step 1: User1 re-pairs with User2');
        final rePairResult = pairUsers('user1', 'user2');
        expect(rePairResult, isTrue);
        
        // Verify pairing
        expect(mockUsers['user1']!['paired_with'], equals('user2'));
        expect(mockUsers['user2']!['paired_with'], equals('user1'));
        
        print('✅ User1 and User2 are successfully re-paired');
        
        // Step 2: Verify User3 is unpaired
        print('Step 2: Verifying User3 is unpaired');
        expect(mockUsers['user3']!['paired_with'], isNull);
        
        print('✅ User3 is unpaired');
        
        // Step 3: Create new shared tasks between User1 and User2
        print('Step 3: Creating new shared tasks between User1 and User2');
        createSharedTask('user1', 'user2', 'New Shared Task 1-2');
        
        expect(mockTasks.length, equals(1));
        print('✅ New shared task created between User1 and User2');
        
        // Step 4: Verify old tasks from User3 are not visible
        print('Step 4: Verifying old tasks from User3 are not visible');
        final user1Tasks = getTasksForUser('user1');
        final user3Tasks = getTasksForUser('user3');
        
        // User1 should not see tasks shared with User3
        final user1TasksWithUser3 = user1Tasks.where((t) => t['pair_id'] == 'user3').toList();
        expect(user1TasksWithUser3, isEmpty, reason: 'User1 should not see tasks shared with User3');
        
        // User3 should not see tasks shared with User1
        final user3TasksWithUser1 = user3Tasks.where((t) => t['pair_id'] == 'user1').toList();
        expect(user3TasksWithUser1, isEmpty, reason: 'User3 should not see tasks shared with User1');
        
        print('✅ Old tasks from previous pairing are correctly isolated');
      });
    });

    group('Edge Cases and Error Handling', () {
      test('Cannot pair with yourself', () {
        print('\n🧪 Testing: Cannot pair with yourself');
        
        final result = pairUsers('user1', 'user1');
        expect(result, isFalse, reason: 'Should not be able to pair with yourself');
        
        print('✅ Cannot pair with yourself - error handled correctly');
      });

      test('Unpairing when not paired', () {
        print('\n🧪 Testing: Unpairing when not paired');
        
        // Ensure user is not paired
        mockUsers['user1']!['paired_with'] = null;
        
        // Try to unpair
        final result = unpairUsers('user1');
        expect(result, isFalse, reason: 'Should return false when not paired');
        
        print('✅ Unpairing when not paired handled correctly');
      });

      test('Pairing with non-existent user', () {
        print('\n🧪 Testing: Pairing with non-existent user');
        
        final result = pairUsers('user1', 'non-existent-user');
        expect(result, isFalse, reason: 'Should not be able to pair with non-existent user');
        
        print('✅ Pairing with non-existent user handled correctly');
      });
    });

    group('Task Isolation Logic', () {
      test('Personal tasks are only visible to owner', () {
        print('\n🧪 Testing: Personal tasks are only visible to owner');
        
        // Create personal tasks for each user
        createSharedTask('user1', null, 'Personal Task 1');
        createSharedTask('user2', null, 'Personal Task 2');
        createSharedTask('user3', null, 'Personal Task 3');
        
        // Check visibility
        final user1Tasks = getTasksForUser('user1');
        final user2Tasks = getTasksForUser('user2');
        final user3Tasks = getTasksForUser('user3');
        
        // Each user should only see their own personal tasks
        expect(user1Tasks.length, equals(1));
        expect(user1Tasks.first['title'], equals('Personal Task 1'));
        
        expect(user2Tasks.length, equals(1));
        expect(user2Tasks.first['title'], equals('Personal Task 2'));
        
        expect(user3Tasks.length, equals(1));
        expect(user3Tasks.first['title'], equals('Personal Task 3'));
        
        print('✅ Personal tasks are correctly isolated');
      });

      test('Shared tasks are only visible to paired users', () {
        print('\n🧪 Testing: Shared tasks are only visible to paired users');
        
        // Pair User1 with User2
        pairUsers('user1', 'user2');
        
        // Create shared tasks
        createSharedTask('user1', 'user2', 'Shared Task 1-2');
        createSharedTask('user2', 'user1', 'Shared Task 2-1');
        
        // Check visibility
        final user1Tasks = getTasksForUser('user1');
        final user2Tasks = getTasksForUser('user2');
        final user3Tasks = getTasksForUser('user3');
        
        // User1 and User2 should see shared tasks
        expect(user1Tasks.length, equals(2));
        expect(user2Tasks.length, equals(2));
        
        // User3 should not see any shared tasks
        expect(user3Tasks, isEmpty);
        
        print('✅ Shared tasks are correctly isolated to paired users');
      });
    });
  });
}
