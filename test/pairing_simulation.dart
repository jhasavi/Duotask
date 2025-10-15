/// Database simulation to test pairing scenarios and identify issues
void main() {
  print('🔍 Pairing Database Simulation - Issue Analysis\n');

  // Mock database state
  Map<String, Map<String, dynamic>> users = {};
  Map<String, Map<String, dynamic>> tasks = {};
  Map<String, Map<String, dynamic>> pairHistory = {};

  // Initialize test data
  users = {
    'user1': {
      'id': 'user1',
      'name': 'Alice',
      'email': 'alice@test.com',
      'paired_with': null,
      'pair_code': 'ABC123'
    },
    'user2': {
      'id': 'user2',
      'name': 'Bob',
      'email': 'bob@test.com',
      'paired_with': null,
      'pair_code': 'DEF456'
    },
    'user3': {
      'id': 'user3',
      'name': 'Charlie',
      'email': 'charlie@test.com',
      'paired_with': null,
      'pair_code': 'GHI789'
    }
  };
  
  tasks = {};
  pairHistory = {};

  // Mock database functions
  void pairUsers(String user1Id, String user2Id) {
    print('🔗 Pairing $user1Id with $user2Id');
    
    // Check if either user is already paired
    if (users[user1Id]!['paired_with'] != null) {
      print('❌ $user1Id is already paired with ${users[user1Id]!['paired_with']}');
      return;
    }
    if (users[user2Id]!['paired_with'] != null) {
      print('❌ $user2Id is already paired with ${users[user2Id]!['paired_with']}');
      return;
    }

    // Update pairing status
    users[user1Id]!['paired_with'] = user2Id;
    users[user2Id]!['paired_with'] = user1Id;
    
    // Add to pair history
    pairHistory['${user1Id}_${user2Id}'] = {
      'user_id': user1Id,
      'partner_id': user2Id,
      'partner_name': users[user2Id]!['name'],
      'last_paired_at': DateTime.now(),
      'pairing_count': 1
    };
    pairHistory['${user2Id}_${user1Id}'] = {
      'user_id': user2Id,
      'partner_id': user1Id,
      'partner_name': users[user1Id]!['name'],
      'last_paired_at': DateTime.now(),
      'pairing_count': 1
    };
    
    print('✅ Successfully paired $user1Id with $user2Id');
  }

  void unpairUser(String userId) {
    print('🔓 Unpairing $userId');
    
    final partnerId = users[userId]!['paired_with'];
    if (partnerId == null) {
      print('❌ $userId is not paired');
      return;
    }

    // Update pairing status
    users[userId]!['paired_with'] = null;
    users[partnerId]!['paired_with'] = null;
    
    print('✅ Successfully unpaired $userId from $partnerId');
  }

  void createTask(String taskId, String ownerId, String title, {String? pairId, bool isPersonal = false}) {
    print('📝 Creating task: $title (Owner: $ownerId, Personal: $isPersonal)');
    
    tasks[taskId] = {
      'id': taskId,
      'title': title,
      'owner_id': ownerId,
      'pair_id': isPersonal ? null : pairId,
      'status': 'unclaimed',
      'created_at': DateTime.now()
    };
    
    print('✅ Task created: $taskId');
  }

  List<Map<String, dynamic>> getTasksForUser(String userId) {
    final user = users[userId]!;
    final partnerId = user['paired_with'];
    
    print('🔍 Getting tasks for $userId (Partner: $partnerId)');
    
    return tasks.values.where((task) {
      // Personal tasks: only visible to owner
      if (task['pair_id'] == null) {
        return task['owner_id'] == userId;
      }
      
      // Shared tasks: visible to both paired users
      if (partnerId != null) {
        return (task['owner_id'] == userId && task['pair_id'] == partnerId) ||
               (task['owner_id'] == partnerId && task['pair_id'] == userId);
      }
      
      return false;
    }).toList();
  }

  void printUserStatus(String userId) {
    final user = users[userId]!;
    final partnerId = user['paired_with'];
    final partnerName = partnerId != null ? users[partnerId]!['name'] : 'None';
    
    print('👤 $userId (${user['name']}): Paired with $partnerName');
  }

  void printTasks(String userId) {
    final userTasks = getTasksForUser(userId);
    print('📋 Tasks for ${users[userId]!['name']}:');
    if (userTasks.isEmpty) {
      print('   No tasks found');
    } else {
      for (final task in userTasks) {
        final isPersonal = task['pair_id'] == null;
        print('   - ${task['title']} (${isPersonal ? 'Personal' : 'Shared'})');
      }
    }
  }

  // Run simulation scenarios
  print('🧪 Scenario 1: User1 pairs with User2, creates shared tasks, then unpairs');
  
  // Step 1: Pair User1 with User2
  pairUsers('user1', 'user2');
  printUserStatus('user1');
  printUserStatus('user2');
  
  // Step 2: Create tasks
  createTask('task1', 'user1', 'Personal task from User1', isPersonal: true);
  createTask('task2', 'user1', 'Shared task from User1', pairId: 'user2');
  createTask('task3', 'user2', 'Personal task from User2', isPersonal: true);
  createTask('task4', 'user2', 'Shared task from User2', pairId: 'user1');
  
  // Step 3: Check task visibility
  print('\n📋 After creating tasks:');
  printTasks('user1');
  printTasks('user2');
  
  // Step 4: Unpair User1
  unpairUser('user1');
  printUserStatus('user1');
  printUserStatus('user2');
  
  // Step 5: Check task visibility after unpairing
  print('\n📋 After unpairing:');
  printTasks('user1');
  printTasks('user2');
  
  print('\n🧪 Scenario 2: User1 pairs with User3 after unpairing from User2');
  
  // Step 6: Pair User1 with User3
  pairUsers('user1', 'user3');
  printUserStatus('user1');
  printUserStatus('user3');
  
  // Step 7: Create shared tasks between User1 and User3
  createTask('task5', 'user1', 'Shared task User1-User3', pairId: 'user3');
  createTask('task6', 'user3', 'Shared task User3-User1', pairId: 'user1');
  
  // Step 8: Check task visibility
  print('\n📋 Final task visibility:');
  printTasks('user1');
  printTasks('user2');
  printTasks('user3');
  
  // Issue Analysis
  print('\n🔍 Issue Analysis: Task ownership and visibility problems');
  
  print('\n📋 Current database state analysis:');
  print('Users table:');
  for (final user in users.values) {
    print('  ${user['id']}: paired_with = ${user['paired_with']}');
  }
  
  print('\nTasks table:');
  for (final task in tasks.values) {
    print('  ${task['id']}: owner=${task['owner_id']}, pair_id=${task['pair_id']}');
  }
  
  print('\nPair History table:');
  for (final history in pairHistory.values) {
    print('  ${history['user_id']} -> ${history['partner_id']}');
  }
  
  // Identify potential issues
  print('\n🚨 Potential Issues Identified:');
  
  // Issue 1: Task ownership transfer
  print('1. Task ownership transfer: Tasks should not change owner_id when pairing changes');
  
  // Issue 2: Task visibility logic
  print('2. Task visibility logic: Shared tasks should be visible based on pair_id, not current pairing status');
  
  // Issue 3: Pairing status inconsistency
  print('3. Pairing status inconsistency: App state vs database state mismatch');
  
  // Issue 4: Missing task restoration
  print('4. Missing task restoration: Old shared tasks should reappear when re-pairing');
  
  // Recommendations
  print('\n💡 Recommendations:');
  print('1. Add task_pairing_history table to track which pairing a task was created under');
  print('2. Modify task visibility logic to check pair_id against current pairing');
  print('3. Add task restoration when re-pairing with previous partners');
  print('4. Add task ownership tracking to prevent ownership transfer');
}
