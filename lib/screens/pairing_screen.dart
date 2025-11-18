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
      setState(() {
        _myPairingCode = code;
      });
    } else {
      await HapticHelper.error();
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
      appBar: AppBar(
        title: const Text('Partner Pairing'),
      ),
      body: Consumer<PairingService>(
        builder: (context, pairingService, child) {
          if (pairingService.isPaired && pairingService.partner != null) {
            // Already paired view
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: pairingService.partner!.avatarUrl != null
                          ? NetworkImage(pairingService.partner!.avatarUrl!)
                          : null,
                      child: pairingService.partner!.avatarUrl == null
                          ? Text(
                              pairingService.partner!.displayName?[0].toUpperCase() ?? 'P',
                              style: const TextStyle(fontSize: 48),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Paired with',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pairingService.partner!.displayName ?? 'Partner',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pairingService.partner!.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: _unpair,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Unpair'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.urgentColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Not paired view
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Option 1: Generate code
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Share Your Code',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate a pairing code and share it with your partner',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_myPairingCode != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _myPairingCode!,
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 4,
                                      ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _myPairingCode!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Code copied to clipboard'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ElevatedButton.icon(
                          onPressed: _generatePairingCode,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _myPairingCode == null
                                ? 'Generate Code'
                                : 'Generate New Code',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 32),

                // Option 2: Enter code
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.link,
                          size: 64,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter Partner\'s Code',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the pairing code shared by your partner',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _pairingCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Pairing Code',
                            hintText: 'ABCD1234',
                            prefixIcon: Icon(Icons.password),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 8,
                          onSubmitted: (_) => _acceptPairingCode(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _acceptPairingCode,
                          icon: const Icon(Icons.check),
                          label: const Text('Pair'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
