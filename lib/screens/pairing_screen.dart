import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/clean_pairing_service.dart';
import '../utils/ui_helper.dart';
import '../utils/logger.dart';

class PairingScreen extends StatefulWidget {
  final VoidCallback? onPaired;
  final bool embedded;
  const PairingScreen({super.key, this.onPaired, this.embedded = false});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _pairCodeController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  final CleanPairingService _pairingService = CleanPairingService();
  
  String? _previousPartnerName;
  String? _previousPartnerId;
  String? _currentPartnerName;
  Map<String, dynamic>? _outgoing;
  Timer? _outgoingTimer;
  Timer? _incomingTimer;
  bool _incomingPending = false;
  bool _loading = false;
  String? _error;
  
  static const String _pendingNameKey = 'pending_request_name';
  static const String _pendingEmailKey = 'pending_request_email';
  static const String _pendingExpiryKey = 'pending_request_expiry_ms';

  @override
  void initState() {
    super.initState();
    _restoreCachedOutgoing();
    _startIncomingPoll();
    _fetchCurrentPartnerName();
    _debugCheckPairCode(); // Debug: Check if current user has pair code
  }

  @override
  void dispose() {
    _outgoingTimer?.cancel();
    _incomingTimer?.cancel();
    _pairCodeController.dispose();
    super.dispose();
  }

  // Stream for current user info
  Stream<List<Map<String, dynamic>>> get _userStream => _client
      .from('usr')
      .stream(primaryKey: ['id'])
      .eq('id', _client.auth.currentUser?.id ?? '')
      .limit(1);

  void _startIncomingPoll() {
    _incomingTimer ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pairInfo = await _pairingService.getCurrentPair();
        if (!mounted) return;
        
        if (pairInfo != null && pairInfo['status'] == 'active') {
          await _clearCachedOutgoing();
          if (mounted) {
            setState(() {
              _outgoing = null;
              _incomingPending = false;
              _currentPartnerName = pairInfo['partner_name'] as String?;
            });
          }
          _incomingTimer?.cancel();
          _incomingTimer = null;
          widget.onPaired?.call();
        }
      } catch (e) {
        Log.error('Error checking pairing status: $e');
      }
    });
  }

  // Fetch current partner name
  Future<void> _fetchCurrentPartnerName() async {
    try {
      final pairInfo = await _pairingService.getCurrentPair();
      if (mounted && pairInfo != null && pairInfo['status'] == 'active') {
        setState(() {
          _currentPartnerName = pairInfo['partner_name'] as String?;
        });
      }
    } catch (e) {
      Log.error('Error fetching current partner name: $e');
    }
  }

  // Debug: Check current user's pair code
  Future<void> _debugCheckPairCode() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final userData = await _client
            .from('usr')
            .select('id, email, name, pair_code')
            .eq('id', user.id)
            .maybeSingle();
        
        print('🔍 Current user data: $userData');
        
        if (userData != null && userData['pair_code'] != null) {
          print('🔍 Current user pair code: ${userData['pair_code']}');
        } else {
          print('❌ Current user has no pair code!');
          // Try to ensure user has a pair code
          await _ensureUserHasPairCode(user);
        }
        
        // Also check all users in the database
        final allUsers = await _client
            .from('usr')
            .select('id, email, name, pair_code')
            .limit(10);
        
        print('🔍 All users in database: $allUsers');
      }
    } catch (e) {
      print('❌ Error checking pair code: $e');
    }
  }

  // Show manual code input dialog
  void _showManualCodeInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Pair Code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter 8-character code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            LengthLimitingTextInputFormatter(8),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.length == 8) {
                setState(() {
                  _pairCodeController.text = code;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code entered: $code'), duration: const Duration(seconds: 1)),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Ensure current user has a pair code
  Future<void> _ensureUserHasPairCode(User user) async {
    try {
      print('🔧 Ensuring user has pair code...');
      
      // Generate a unique pair code
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rng = Random.secure();
      String pairCode;
      
      for (var attempt = 0; attempt < 10; attempt++) {
        pairCode = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
        
        // Check if this code is unique
        final existing = await _client
            .from('usr')
            .select('id')
            .eq('pair_code', pairCode)
            .maybeSingle();
        
        if (existing == null) {
          // Update user with the new pair code
          await _client
              .from('usr')
              .update({'pair_code': pairCode})
              .eq('id', user.id);
          
          print('✅ Generated new pair code: $pairCode');
          return;
        }
      }
      
      print('❌ Could not generate unique pair code after 10 attempts');
    } catch (e) {
      print('❌ Error ensuring pair code: $e');
    }
  }

  // Restore cached outgoing request
  Future<void> _restoreCachedOutgoing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(_pendingExpiryKey);
      if (expiryMs == null || DateTime.now().millisecondsSinceEpoch > expiryMs) {
        await _clearCachedOutgoing();
        return;
      }
      final name = prefs.getString(_pendingNameKey);
      final email = prefs.getString(_pendingEmailKey);
      if (name != null && email != null) {
        setState(() {
          _outgoing = {
            'recipient_name': name,
            'recipient_email': email,
          };
        });
      }
    } catch (_) {}
  }

  // Cache outgoing request
  Future<void> _cacheOutgoing(String name, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = DateTime.now().millisecondsSinceEpoch + (60 * 60 * 1000); // 1 hour
      await prefs.setInt(_pendingExpiryKey, expiryMs);
      await prefs.setString(_pendingNameKey, name);
      await prefs.setString(_pendingEmailKey, email);
    } catch (_) {}
  }

  // Clear cached outgoing request
  Future<void> _clearCachedOutgoing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingNameKey);
      await prefs.remove(_pendingEmailKey);
      await prefs.remove(_pendingExpiryKey);
    } catch (_) {}
  }

  // Copy pair code
  Future<void> _copyPairCode(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      UIHelper.showSnack(context, 'Code copied to clipboard');
    } catch (e) {
      if (!mounted) return;
      UIHelper.showError(context, 'Failed to copy: $e');
    }
  }

  // Share via SMS
  Future<void> _shareViaSMS(String code) async {
    try {
      final message = 'Join me on DuoTask! Use this code to pair: $code';
      final uris = [
        Uri.parse('sms:?body=${Uri.encodeComponent(message)}'),
        Uri.parse('sms:?body=${Uri.encodeComponent(message)}&to='),
        Uri.parse('sms:'),
      ];
      
      bool launched = false;
      for (final uri in uris) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      }
      
      if (!launched) {
        await Share.share(message, subject: 'DuoTask Pairing Code');
      }
    } catch (e) {
      try {
        final message = 'Join me on DuoTask! Use this code to pair: $code';
        await Share.share(message, subject: 'DuoTask Pairing Code');
      } catch (fallbackError) {
        UIHelper.showError(context, 'Could not share code');
      }
    }
  }

  // Share via WhatsApp
  Future<void> _shareViaWhatsApp(String code) async {
    try {
      final message = 'Join me on DuoTask! Use this code to pair: $code';
      final uris = [
        Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}'),
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
      ];
      
      bool launched = false;
      for (final uri in uris) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      }
      
      if (!launched) {
        await Share.share(message, subject: 'DuoTask Pairing Code');
      }
    } catch (e) {
      try {
        final message = 'Join me on DuoTask! Use this code to pair: $code';
        await Share.share(message, subject: 'DuoTask Pairing Code');
      } catch (fallbackError) {
        UIHelper.showError(context, 'Could not share code');
      }
    }
  }

  // Share via Email
  Future<void> _shareViaEmail(String code) async {
    try {
      final subject = 'Join me on DuoTask!';
      final body = 'Hi! I\'d like to pair with you on DuoTask. Use this code to connect: $code\n\nDownload DuoTask from the app store to get started.';
      final uri = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Share.share('Join me on DuoTask! Use this code to pair: $code', subject: 'DuoTask Pairing Code');
      }
    } catch (e) {
      try {
        await Share.share('Join me on DuoTask! Use this code to pair: $code', subject: 'DuoTask Pairing Code');
      } catch (fallbackError) {
        UIHelper.showError(context, 'Could not share code');
      }
    }
  }

  // Send pair request
  Future<void> _pair() async {
    final code = _pairCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a pair code.');
      return;
    }
    
    // Debug: Log the code being used
    print('🔍 Pairing attempt with code: "$code" (length: ${code.length})');
    print('🔍 Code bytes: ${code.codeUnits}');
    
    // Check if user is trying to pair with their own code
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final userData = await _client
            .from('usr')
            .select('pair_code')
            .eq('id', user.id)
            .maybeSingle();
        
        if (userData != null && userData['pair_code'] == code) {
          setState(() {
            _error = 'You cannot pair with your own code.';
            _loading = false;
          });
          return;
        }
      } catch (e) {
        print('❌ Error checking own pair code: $e');
      }
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _pairingService.pairUpWithCode(code);
      
      if (result['status'] == 'paired') {
        setState(() {
          _loading = false;
          _error = null;
        });
        
        if (!mounted) return;
        UIHelper.showSnack(context, result['message']);
        
        // Navigate back to refresh the main screen
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _loading = false;
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        final msg = e.toString();
        print('❌ Pairing error: $msg');
        
        if (msg.contains('Invalid pair code')) {
          _error = 'No user found with that code.';
        } else if (msg.contains('already paired')) {
          _error = 'That user is already paired.';
        } else if (msg.contains('Cannot pair with yourself') || msg.contains('Invalid partner')) {
          _error = 'You cannot pair with your own code.';
        } else if (msg.contains('User not authenticated')) {
          _error = 'Please sign in again.';
        } else if (msg.contains('PostgrestException')) {
          _error = 'Database error. Please try again.';
        } else {
          _error = 'Pairing failed. Please check the code and try again.';
        }
        _loading = false;
      });
    }
  }

  Future<String?> _fetchMyName(String userId) async {
    try {
      final row = await _client
          .from('usr')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchPartnerNameById(String partnerId) async {
    try {
      final row = await _client
          .from('usr')
          .select('name')
          .eq('id', partnerId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (_) {
      return null;
    }
  }



  Future<void> _unpair() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _pairingService.unpair();
      
      if (!mounted) return;
      setState(() {
        _loading = false;
        _previousPartnerName = null;
        _previousPartnerId = null;
      });
      widget.onPaired?.call();
      messenger.showSnackBar(const SnackBar(content: Text('Unpaired successfully.')));
      
      // Navigate back to refresh the main screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unpair failed: $e';
      });
    }
  }



  // Only 3 sharing options: SMS, WhatsApp, Email
  Widget _buildShareButtons(String code) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildShareButton(Icons.sms, 'SMS', () => _shareViaSMS(code), Colors.green),
        _buildShareButton(Icons.chat, 'WhatsApp', () => _shareViaWhatsApp(code), Colors.green),
        _buildShareButton(Icons.email, 'Email', () => _shareViaEmail(code), Colors.blue),
      ],
    );
  }

  Widget _buildShareButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final userData = (snapshot.data != null && snapshot.data!.isNotEmpty)
              ? snapshot.data!.first
              : null;
          final myPairCode = userData?['pair_code'] as String?;
          final hasPair = _currentPartnerName != null && _incomingPending == false;
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tiny status indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(radius: 8, backgroundColor: Colors.blue, child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 8))),
                    const SizedBox(width: 4),
                    Icon(Icons.favorite, color: hasPair ? Colors.pink : Colors.grey, size: 10),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: hasPair ? Colors.green : Colors.grey,
                      child: Text(hasPair ? (_currentPartnerName?[0].toUpperCase() ?? 'P') : '?', style: const TextStyle(color: Colors.white, fontSize: 8)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Your pairing code (if not paired)
                if (myPairCode != null && !hasPair) ...[
                  Text('Your pairing code:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(myPairCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _copyPairCode(myPairCode),
                        icon: const Icon(Icons.copy, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildShareButtons(myPairCode),
                  const SizedBox(height: 20),
                ],
                
                // Paired status
                if (hasPair) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: [
                        Expanded(child: Text('You are paired!', style: TextStyle(fontSize: 11, color: Colors.green.shade700))),
                        OutlinedButton(
                          onPressed: _loading ? null : _unpair,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), textStyle: const TextStyle(fontSize: 10)),
                          child: const Text('Unpair'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Enter partner code (if not paired)
                if (!hasPair) ...[
                  // Debug: Show current user's pair code if available
                  if (userData?['pair_code'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Your code: ${userData!['pair_code']}',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  Text('Enter partner code:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pairCodeController,
                          decoration: InputDecoration(
                            hintText: 'Enter code',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, letterSpacing: 1),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          textCapitalization: TextCapitalization.characters,
                          enableInteractiveSelection: true,
                          enableSuggestions: false,
                          autocorrect: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          try {
                            // Try multiple clipboard formats for better iOS compatibility
                            ClipboardData? data;
                            try {
                              data = await Clipboard.getData(Clipboard.kTextPlain);
                            } catch (e) {
                              print('❌ Failed to get clipboard data: $e');
                            }
                            
                            print('🔍 Clipboard data: ${data?.text}');
                            if (data?.text != null) {
                              // More flexible text processing - handle various formats
                              String cleanedText = data!.text!.trim();
                              
                              // Remove common separators and convert to uppercase
                              cleanedText = cleanedText
                                  .replaceAll(RegExp(r'[^A-Za-z0-9]'), '') // Remove all non-alphanumeric
                                  .toUpperCase();
                              
                              print('🔍 Processed pasted text: "$cleanedText"');
                              print('🔍 Text length: ${cleanedText.length}');
                              print('🔍 Text bytes: ${cleanedText.codeUnits}');
                              
                              if (cleanedText.length == 8 && cleanedText.isNotEmpty) {
                                setState(() {
                                  _pairCodeController.text = cleanedText;
                                });
                                // Show feedback
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Pasted: $cleanedText'), duration: const Duration(seconds: 1)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Invalid code format. Expected 8 characters, got ${cleanedText.length}'), duration: const Duration(seconds: 2)),
                                );
                              }
                            } else {
                              // For iOS, try to show a manual input dialog
                              _showManualCodeInputDialog();
                            }
                          } catch (e) {
                            print('❌ Paste error: $e');
                            // Fallback to manual input
                            _showManualCodeInputDialog();
                          }
                        },
                        icon: const Icon(Icons.paste, size: 20),
                        tooltip: 'Paste code',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _pair,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                      child: _loading ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
                    ),
                  ),
                  
                  // Debug: Add button to regenerate pair code
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : () async {
                      final user = _client.auth.currentUser;
                      if (user != null) {
                        await _ensureUserHasPairCode(user);
                        // Refresh the screen
                        setState(() {});
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Regenerate Pair Code'),
                  ),
                  
                  // Debug: Add button to apply migration
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _loading ? null : () async {
                      try {
                        await _pairingService.applyPairCodeMigration();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Migration applied successfully'), duration: const Duration(seconds: 2)),
                        );
                        // Refresh the screen
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Migration failed: $e'), duration: const Duration(seconds: 2)),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Apply Migration'),
                  ),
                  
                  // Debug: Add button to check all users
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _loading ? null : () async {
                      try {
                        await _pairingService.debugCheckAllUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Check console for debug info'), duration: const Duration(seconds: 2)),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Debug failed: $e'), duration: const Duration(seconds: 2)),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Debug Users'),
                  ),
                  
                  // Debug: Test pairing with hardcoded code
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _loading ? null : () async {
                      try {
                        print('🔍 Testing pairing with hardcoded code: TQE6TW3M');
                        final result = await _pairingService.pairUpWithCode('TQE6TW3M');
                        print('🔍 Pairing result: $result');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Test result: ${result['status']}'), duration: const Duration(seconds: 2)),
                        );
                      } catch (e) {
                        print('❌ Test pairing error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Test failed: $e'), duration: const Duration(seconds: 2)),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Test Pairing'),
                  ),
                ],
                
                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 10)),
                  ),
                ],
                
                // Re-pair option
                if (!hasPair && _previousPartnerName != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                                            onPressed: null,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: Text('Re-pair with $_previousPartnerName', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
