import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/enhanced_pairing_service.dart';
import '../services/clean_pairing_service.dart';
import '../utils/ui_helper.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onPairStatusChanged;
  
  const SettingsScreen({
    super.key, 
    this.embedded = false,
    this.onPairStatusChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final EnhancedPairingService _pairingService = EnhancedPairingService();
  final CleanPairingService _cleanPairingService = CleanPairingService();
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pairCodeController = TextEditingController();
  
  bool _loading = false;
  bool _editingName = false;
  String? _error;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      
      final profile = await _client
          .from('usr')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      
      // Get current pairing status using the new system
      final pairInfo = await _cleanPairingService.getCurrentPair();
      final hasPair = pairInfo != null && pairInfo['status'] == 'active';
      final partnerName = pairInfo?['partner_name'] as String?;
      
      if (mounted) {
        setState(() {
          _userProfile = {
            ...profile ?? {},
            '_has_pair': hasPair,
            '_partner_name': partnerName,
          };
          _nameController.text = profile?['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      await _client
          .from('usr')
          .update({'name': newName})
          .eq('id', user.id);
      
      if (mounted) {
        setState(() {
          _editingName = false;
          _loading = false;
          if (_userProfile != null) {
            _userProfile!['name'] = newName;
          }
        });
        UIHelper.showSnack(context, 'Name updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to update name: $e';
        });
      }
    }
  }

  Future<void> _copyPairCode() async {
    final pairCode = _userProfile?['pair_code'] as String?;
    if (pairCode == null) return;
    
    try {
      await Clipboard.setData(ClipboardData(text: pairCode));
      if (mounted) {
        UIHelper.showSnack(context, 'Pair code copied to clipboard');
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, 'Failed to copy: $e');
      }
    }
  }

  Future<void> _sendPairRequest() async {
    final code = _pairCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a pair code.');
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      await _client.rpc('request_pair_by_code_v1', params: {
        'p_user_id': user.id,
        'p_partner_code': code,
      });
      
      if (mounted) {
        setState(() => _loading = false);
        _pairCodeController.clear();
        UIHelper.showSnack(context, 'Pair request sent successfully');
        _loadUserProfile(); // Refresh to show updated status
        widget.onPairStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          final msg = e.toString();
          if (msg.contains('No user found with that code')) {
            _error = 'No user found with that code.';
          } else if (msg.contains('already paired')) {
            _error = 'Cannot send request: already paired.';
          } else if (msg.contains('Cannot pair with yourself')) {
            _error = 'You cannot pair with your own code.';
          } else {
            _error = 'Pairing failed: $e';
          }
        });
      }
    }
  }

  Future<void> _unpair() async {
    final ok = await UIHelper.confirm(
      context,
      title: 'Unpair?',
      message: 'Are you sure you want to unpair from your partner? You can re-pair later.',
      confirmText: 'Unpair',
      destructive: true,
    );
    if (!ok) return;
    
    setState(() => _loading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
              await _cleanPairingService.unpair();
      
      if (mounted) {
        setState(() => _loading = false);
        UIHelper.showSnack(context, 'Unpaired successfully');
        _loadUserProfile(); // Refresh profile
        widget.onPairStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unpair failed: $e';
        });
      }
    }
  }

  Future<void> _signOut() async {
    final ok = await UIHelper.confirm(
      context,
      title: 'Sign Out?',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
    );
    if (!ok) return;
    
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, 'Sign out failed: $e');
      }
    }
  }

  Widget _buildProfileSection() {
    final user = _client.auth.currentUser;
    final name = _userProfile?['name'] as String? ?? '';
    final email = user?.email ?? '';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Name
            Row(
              children: [
                Expanded(
                  child: _editingName
                      ? TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          autofocus: true,
                          onSubmitted: (_) => _updateName(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Name',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              name.isEmpty ? 'No name set' : name,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                ),
                if (_editingName) ...[
                  IconButton(
                    onPressed: _loading ? null : _updateName,
                    icon: const Icon(Icons.check, color: Colors.green),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _editingName = false;
                        _nameController.text = _userProfile?['name'] ?? '';
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ] else
                  IconButton(
                    onPressed: () => setState(() => _editingName = true),
                    icon: const Icon(Icons.edit),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Email
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingSection() {
    final pairCode = _userProfile?['pair_code'] as String?;
    // Use the new pairing system instead of old columns
    final hasPair = _userProfile?['_has_pair'] as bool? ?? false;
    final partnerName = _userProfile?['_partner_name'] as String?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Partner Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current pairing status
            if (hasPair) ...[
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  partnerName != null && partnerName.isNotEmpty
                      ? 'Paired with $partnerName'
                      : 'Paired',
                ),
                trailing: TextButton.icon(
                  onPressed: _loading ? null : _unpair,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Unpair'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ] else ...[
              // Your pair code
              if (pairCode != null) ...[
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: const Text('Your Pair Code'),
                  subtitle: SelectableText(
                    pairCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: _copyPairCode,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy code',
                  ),
                ),
                const Divider(),
              ],
              
              // Send pair request
              const Text(
                'Enter Partner\'s Code',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pairCodeController,
                      decoration: const InputDecoration(
                        hintText: 'Enter pair code',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _sendPairRequest,
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pair'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 24),
                const SizedBox(width: 8),
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out'),
              onTap: _signOut,
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('DuoTask v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'DuoTask',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 DuoTask',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 16),
                  _buildPairingSection(),
                  const SizedBox(height: 16),
                  _buildAppSection(),
                  
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: content,
    );
  }
}
