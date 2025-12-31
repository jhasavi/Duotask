import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/pairing_service.dart';
import '../config/theme.dart';
import '../utils/haptic_helper.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _pairingCodeController = TextEditingController();
  String? _myPairingCode;
  bool _isLoadingCode = false;

  @override
  void initState() {
    super.initState();
    // Load any existing pending pairing code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingPairingCode();
    });
  }

  Future<void> _loadExistingPairingCode() async {
    setState(() => _isLoadingCode = true);
    
    final authService = context.read<AuthService>();
    final pairingService = context.read<PairingService>();
    final userId = authService.currentUser?.id;
    
    if (userId == null) {
      setState(() => _isLoadingCode = false);
      return;
    }

    // Check if there's an existing pending pairing code for this user
    final code = await pairingService.getMyPendingPairingCode(userId);
    
    if (mounted) {
      setState(() {
        _myPairingCode = code;
        _isLoadingCode = false;
      });
    }
  }

  @override
  void dispose() {
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _generatePairingCode() async {
    await HapticHelper.lightImpact();
    
    final authService = context.read<AuthService>();
    final pairingService = context.read<PairingService>();
    
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    final code = await pairingService.createPairingCode(userId);
    
    if (code != null) {
      await HapticHelper.lightImpact();
      // Reload user data to get updated pairing code
      await authService.refreshUser();
      setState(() {
        _myPairingCode = code;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pairing code generated: $code')),
        );
      }
    } else {
      await HapticHelper.error();
      if (mounted && pairingService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pairingService.errorMessage!)),
        );
      }
    }
  }

  Future<void> _acceptPairingCode() async {
    final code = _pairingCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    await HapticHelper.mediumImpact();

    final authService = context.read<AuthService>();
    final pairingService = context.read<PairingService>();
    
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    final success = await pairingService.acceptPairingCode(userId, code);

    if (mounted) {
      if (success) {
        await HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully paired!')),
        );
        Navigator.pop(context);
      } else {
        await HapticHelper.error();
        if (pairingService.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(pairingService.errorMessage!)),
          );
        }
      }
    }
  }

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Confirmation'),
        content: const Text('Are you sure you want to unpair? This will remove the connection between you and your partner.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await HapticHelper.heavyImpact();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authService = context.read<AuthService>();
    final pairingService = context.read<PairingService>();
    
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    final success = await pairingService.unpair(userId);

    if (mounted) {
      if (success) {
        await HapticHelper.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unpairing successful')),
        );
        Navigator.pop(context);
      } else {
        await HapticHelper.error();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Partner Pairing'),
        elevation: 0,
      ),
      body: Consumer<PairingService>(
        builder: (context, pairingService, child) {
          if (pairingService.isPaired && pairingService.partner != null) {
            // Already paired - show partner info
            return _buildPairedView(pairingService);
          }

          // Not paired - show pairing options
          return _buildPairingOptionsView();
        },
      ),
    );
  }

  Widget _buildPairedView(PairingService pairingService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Partner avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage: pairingService.partner!.avatarUrl != null
                    ? NetworkImage(pairingService.partner!.avatarUrl!)
                    : null,
                child: pairingService.partner!.avatarUrl == null
                    ? Text(
                        pairingService.partner!.displayName?[0].toUpperCase() ?? 'P',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            
            // Success icon
            Icon(
              Icons.check_circle,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Connected with',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              pairingService.partner!.displayName ?? 'Partner',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              pairingService.partner!.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 48),
            
            // Unpair button
            OutlinedButton.icon(
              onPressed: _unpair,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect Partner'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.urgentColor,
                side: BorderSide(color: AppTheme.urgentColor),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingOptionsView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header text
            Text(
              'Connect with Your Partner',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose one of the options below to pair with your partner',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Option 1: Share your code
            _buildShareCodeCard(),
            
            const SizedBox(height: 32),

            // Divider with OR
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            // Option 2: Enter partner's code
            _buildEnterCodeCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCodeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              'Share Your Code',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a unique code and share it with your partner',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Pairing code display
            if (_myPairingCode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.secondaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Pairing Code',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _myPairingCode!,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                                color: AppTheme.primaryColor,
                                fontFamily: 'monospace',
                              ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.content_copy_rounded, color: AppTheme.primaryColor),
                          tooltip: 'Copy code',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _myPairingCode!),
                            );
                            await HapticHelper.lightImpact();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text('Code copied to clipboard!'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share this code with your partner',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
            ] else if (_isLoadingCode) ...[
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ],

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatePairingCode,
                icon: Icon(_myPairingCode == null ? Icons.add_circle_outline : Icons.refresh_rounded),
                label: Text(
                  _myPairingCode == null ? 'Generate Code' : 'Generate New Code',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterCodeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.secondaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_rounded,
                size: 48,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              'Enter Partner\'s Code',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the pairing code your partner shared with you',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Text field for entering code
            TextField(
              controller: _pairingCodeController,
              decoration: InputDecoration(
                labelText: 'Enter Code',
                hintText: 'ABCD1234',
                prefixIcon: Icon(Icons.password_rounded, color: AppTheme.secondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.secondaryColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.secondaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.secondaryColor, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.secondaryColor.withOpacity(0.05),
              ),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
              maxLength: 8,
              onSubmitted: (_) => _acceptPairingCode(),
            ),
            const SizedBox(height: 16),

            // Pair button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _acceptPairingCode,
                icon: const Icon(Icons.link_rounded),
                label: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
