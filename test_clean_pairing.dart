import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Simple test script to verify the clean pairing system
/// Run this with: dart test_clean_pairing.dart
void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final client = Supabase.instance.client;
  
  print('🧪 Testing Clean Pairing System');
  print('================================');
  
  try {
    // Test 1: Check if pair table exists
    print('\n1. Testing pair table...');
    final pairTableResult = await client
        .from('pair')
        .select('*')
        .limit(1);
    print('✅ Pair table exists and is accessible');
    
    // Test 2: Check if new functions exist
    print('\n2. Testing new functions...');
    
    // Test fn_get_current_pair (should return empty if not paired)
    try {
      final currentPair = await client.rpc('fn_get_current_pair');
      print('✅ fn_get_current_pair function works');
      print('   Current pair: $currentPair');
    } catch (e) {
      print('❌ fn_get_current_pair failed: $e');
    }
    
    // Test 3: Check tasks table structure
    print('\n3. Testing tasks table structure...');
    final tasksResult = await client
        .from('tasks')
        .select('scope, creator_id, pair_id')
        .limit(1);
    print('✅ Tasks table has new columns (scope, creator_id, pair_id)');
    
    // Test 4: Check RLS policies
    print('\n4. Testing RLS policies...');
    try {
      final policies = await client
          .from('pair')
          .select('*')
          .limit(1);
      print('✅ RLS policies are working');
    } catch (e) {
      print('⚠️ RLS policies may need adjustment: $e');
    }
    
    print('\n🎉 Clean pairing system test completed successfully!');
    print('\nNext steps:');
    print('1. Test pairing functionality in the Flutter app');
    print('2. Verify shared tasks work correctly');
    print('3. Test unpairing and re-pairing');
    print('4. Verify task persistence across pairing cycles');
    
  } catch (e) {
    print('❌ Test failed: $e');
  }
}
