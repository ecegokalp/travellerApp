import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
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
      appBar: AppHeader(title: title),
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
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final uid = docs[index].id;
              return FutureBuilder<Map<String, dynamic>?>(
                future: authService.getUserProfile(uid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox.shrink();
                  final user = userSnap.data!;
                  return SectionCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kBrandPrimary.withAlpha(30),
                        child: Text(
                          (user['fullName'] ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(color: kBrandPrimary),
                        ),
                      ),
                      title: Text(user['fullName'] ?? 'Traveller',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text('@${user['username'] ?? ''}',
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: uid),
                          ),
                        );
                      },
                    ),
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
