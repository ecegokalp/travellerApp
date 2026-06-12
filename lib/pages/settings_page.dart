import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
  String _username = '';
  String _email = '';
  String _photoUrl = '';
  bool _isUpdating = false;

  static const _accent = Color(0xFFFF6B6B);
  static const _accentLight = Color(0xFFFF8E53);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final display = (user.displayName ?? '').trim();
    final emailPrefix = (user.email ?? '').split('@').first.trim();
    final fallbackName =
        display.isNotEmpty
            ? display
            : (emailPrefix.isNotEmpty ? emailPrefix : 'Traveller');

    try {
      final profile = await _authService.getUserProfile(user.uid);
      final fullName = (profile?['fullName'] ?? '').toString().trim();

      if (mounted) {
        setState(() {
          _displayName = fullName.isNotEmpty ? fullName : fallbackName;
          _username = profile?['username'] ?? '';
          _email = user.email ?? '';
          _photoUrl = profile?['photoUrl'] ?? '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayName = fallbackName;
          _email = user.email ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

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
        title: Text('Settings', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Text('PROFILE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: secondaryTextColor, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 5), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isUpdating ? null : _pickProfileImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_accent, _accentLight]),
                            borderRadius: BorderRadius.circular(18),
                            image: _photoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_photoUrl), fit: BoxFit.cover) : null,
                          ),
                          child: _photoUrl.isEmpty ? Center(
                            child: Text(
                              _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'T',
                              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ) : (_isUpdating ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : null),
                        ),
                        if (!_isUpdating)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 12, color: _accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text(_username.isNotEmpty ? '@$_username' : _email, style: GoogleFonts.inter(fontSize: 14, color: secondaryTextColor)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditProfileSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined, color: _accent, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Preferences Section
            Text('PREFERENCES', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: secondaryTextColor, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 5), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildSettingTile(context, icon: Icons.notifications_none_rounded, title: 'Notifications',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      activeThumbColor: _accent,
                      onChanged: (value) => setState(() => _notificationsEnabled = value),
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  _buildSettingTile(context, icon: Icons.dark_mode_outlined, title: 'Dark Mode',
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeThumbColor: _accent,
                      onChanged: (value) => themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  _buildSettingTile(context, icon: Icons.language_rounded, title: 'Language',
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('English', style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 14)),
                      Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
                    ]),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // More Section
            Text('MORE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: secondaryTextColor, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 5), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildSettingTile(context, icon: Icons.help_outline_rounded, title: 'Help Center', onTap: () {}),
                  Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  _buildSettingTile(context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () {}),
                  Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  _buildSettingTile(context, icon: Icons.info_outline_rounded, title: 'About App', onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await _authService.signOut();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text('Logout', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _accent.withAlpha(isDark ? 30 : 15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _accent, size: 22),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() => _isUpdating = true);
      try {
        final ref = FirebaseStorage.instance.ref().child('profiles/${_authService.currentUser?.uid}.jpg');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        await _authService.updateProfilePicture(url);
        setState(() {
          _photoUrl = url;
          _isUpdating = false;
        });
      } catch (e) {
        setState(() => _isUpdating = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showEditProfileSheet(BuildContext context) {
    final usernameController = TextEditingController(text: _username);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit Username', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                hintText: 'Username',
                prefixText: '@',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  await _authService.updateUsername(usernameController.text);
                  setState(() => _username = usernameController.text);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
