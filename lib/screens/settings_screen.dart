import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: currentUser?.avatarUrl != null
                      ? NetworkImage(currentUser!.avatarUrl!)
                      : null,
                  child: currentUser?.avatarUrl == null
                      ? Text(
                          currentUser?.displayName?[0].toUpperCase() ?? 'U',
                          style: const TextStyle(fontSize: 40),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  currentUser?.displayName ?? 'User',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Notifications Section
          _SectionHeader(title: 'Notifications'),
          Consumer<NotificationService>(
            builder: (context, notificationService, child) {
              return SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive task reminders and updates'),
                value: notificationService.permissionGranted,
                onChanged: (value) async {
                  if (value) {
                    await notificationService.initialize();
                  }
                },
                secondary: const Icon(Icons.notifications),
              );
            },
          ),
          Consumer<PreferencesService>(
            builder: (context, prefsService, child) {
              return ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Daily Summary'),
                subtitle: const Text('Receive daily task summary at 8 PM'),
                trailing: Switch(
                  value: prefsService.dailySummaryEnabled,
                  onChanged: (value) async {
                    await prefsService.setDailySummaryEnabled(value);
                    
                    final notificationService = context.read<NotificationService>();
                    if (value) {
                      await notificationService.scheduleDailySummary(hour: 20, minute: 0);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily summary enabled at 8 PM')),
                        );
                      }
                    } else {
                      await notificationService.cancelAllNotifications();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily summary disabled')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),

          const Divider(),

          // App Settings
          _SectionHeader(title: 'App Settings'),
          Consumer<PreferencesService>(
            builder: (context, prefsService, child) {
              return ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: Text(prefsService.getThemeModeDisplayName()),
                onTap: () {
                  _showThemeDialog();
                },
              );
            },
          ),
          Consumer<PreferencesService>(
            builder: (context, prefsService, child) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: Text(prefsService.getLanguageDisplayName()),
                onTap: () {
                  _showLanguageDialog();
                },
              );
            },
          ),

          const Divider(),

          // Account Section
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            onTap: () {
              _showEditProfileDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            textColor: AppTheme.urgentColor,
            iconColor: AppTheme.urgentColor,
            onTap: () {
              _showSignOutDialog();
            },
          ),

          const Divider(),

          // About Section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Version'),
            subtitle: Text('${AppConstants.appName} v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () {
              _openDocument('terms_of_service');
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              _openDocument('privacy_policy');
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    final nameController = TextEditingController(
      text: currentUser?.displayName ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final success = await authService.updateProfile(
                  displayName: name,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (newPassword.isEmpty || confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }

              final authService = context.read<AuthService>();
              final success = await authService.updatePassword(newPassword);

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = context.read<AuthService>();
      await authService.signOut();

       // Ensure navigation resets to the auth screen after sign out
       if (mounted) {
         Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(builder: (_) => const AuthScreen()),
           (route) => false,
         );
       }
    }
  }

  Future<void> _showThemeDialog() async {
    final prefsService = context.read<PreferencesService>();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: prefsService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: prefsService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: prefsService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final prefsService = context.read<PreferencesService>();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: prefsService.languageCode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setLanguageCode(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Language changed to English'),
                    ),
                  );
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: prefsService.languageCode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setLanguageCode(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Idioma cambiado a Español'),
                    ),
                  );
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Français'),
              value: 'fr',
              groupValue: prefsService.languageCode,
              onChanged: (value) {
                if (value != null) {
                  prefsService.setLanguageCode(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Langue changée en Français'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(String docName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DocumentViewer(
          title: docName == 'terms_of_service' 
              ? 'Terms of Service' 
              : 'Privacy Policy',
          assetPath: 'assets/docs/$docName.md',
        ),
      ),
    );
  }
}

class _DocumentViewer extends StatelessWidget {
  final String title;
  final String assetPath;

  const _DocumentViewer({
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                snapshot.data!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error loading document: ${snapshot.error}'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
