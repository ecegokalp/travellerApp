import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  String _displayName = '';
  String _email = '';

  static const _coral = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _displayName = profile?['fullName'] ?? user.displayName ?? 'Traveller';
          _email = user.email ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: secondaryTextColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDarkMode ? 20 : 5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _coral.withAlpha(30),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _coral,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Edit profile action
                    },
                    icon: const Icon(Icons.edit_outlined, color: _coral, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Preferences Section
            Text(
              'Preferences',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: secondaryTextColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDarkMode ? 20 : 5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    context,
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      activeThumbColor: _coral,
                      activeTrackColor: _coral.withAlpha(100),
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingTile(
                    context,
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    trailing: Switch.adaptive(
                      value: isDarkMode,
                      activeThumbColor: _coral,
                      activeTrackColor: _coral.withAlpha(100),
                      onChanged: (value) {
                        themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingTile(
                    context,
                    icon: Icons.language_rounded,
                    title: 'Language',

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('English', style: TextStyle(color: secondaryTextColor)),
                        Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
                      ],
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // More Section
            Text(
              'More',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: secondaryTextColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDarkMode ? 20 : 5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingTile(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About App',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await _authService.signOut();
                  if (mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: _coral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: _coral, width: 1),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDarkMode ? Colors.white70 : const Color(0xFF6B7280);
    final iconBgColor = isDarkMode ? Colors.white10 : const Color(0xFFFFF8F0);

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _coral, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
    );
  }
}
