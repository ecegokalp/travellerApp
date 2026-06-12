import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';

class UserListPage extends StatelessWidget {
  final String title;
  final String userId;
  final bool isFollowers;

  const UserListPage({
    super.key,
    required this.title,
    required this.userId,
    required this.isFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: isFollowers
            ? authService.getFollowers(userId)
            : authService.getFollowing(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                isFollowers ? 'No followers yet' : 'Not following anyone yet',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final uid = docs[index].id;
              return FutureBuilder<Map<String, dynamic>?>(
                future: authService.getUserProfile(uid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const ListTile();
                  final user = userSnap.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFF6B6B).withAlpha(30),
                      child: Text(
                        (user['fullName'] ?? 'T')[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                    title: Text(user['fullName'] ?? 'Traveller',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    subtitle: Text('@${user['username'] ?? ''}',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: uid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
