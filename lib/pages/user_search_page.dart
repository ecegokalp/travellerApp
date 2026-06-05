import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _controller = TextEditingController();

  static const _accent = Color(0xFFFF6B6B);
  static const _warmGray = Color(0xFF6B7280);

  String _query = '';
  Future<List<Map<String, dynamic>>>? _suggestedFuture;
  Future<List<Map<String, dynamic>>>? _resultsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedFuture = _authService.getSuggestedUsers();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() {
      _query = v.trim();
      _resultsFuture = _query.length >= 2 ? _authService.searchUsers(_query) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Travellers', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search travellers by username...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: _warmGray),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onChanged('');
                      },
                      child: Icon(Icons.close_rounded, size: 20, color: _warmGray),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _query.length < 2 ? _suggestedSection(textColor) : _resultsSection(textColor)),
        ],
      ),
    );
  }

  Widget _suggestedSection(Color textColor) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _suggestedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) return _empty('No travellers to suggest yet');
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text('Suggested Travellers', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            ...users.map((u) => _userTile(u, textColor)),
          ],
        );
      },
    );
  }

  Widget _resultsSection(Color textColor) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) return _empty('No travellers found for "$_query"');
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: users.map((u) => _userTile(u, textColor)).toList(),
        );
      },
    );
  }

  Widget _userTile(Map<String, dynamic> user, Color textColor) {
    final fullName = (user['fullName'] ?? '').toString();
    final username = (user['username'] ?? '').toString();
    final photoUrl = (user['photoUrl'] ?? '').toString();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : (username.isNotEmpty ? username[0].toUpperCase() : 'T');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: user['uid']))),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _accent.withAlpha(30),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty ? Text(initial, style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)) : null,
      ),
      title: Text(fullName.isNotEmpty ? fullName : 'Traveller', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
      subtitle: username.isNotEmpty ? Text('@$username', style: GoogleFonts.inter(color: _warmGray, fontSize: 13)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: _warmGray),
    );
  }

  Widget _empty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 48, color: _warmGray.withAlpha(120)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _warmGray)),
        ],
      ),
    );
  }
}