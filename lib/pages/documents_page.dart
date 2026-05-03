import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  static const _accent = Color(0xFFFF6B6B);

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('My Documents', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: textColor)),
      ),
      body: user == null
          ? Center(child: Text('Please login to see documents', style: GoogleFonts.inter(color: Colors.grey)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('trips')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accent));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                List<Map<String, dynamic>> allDocs = [];

                for (var tripDoc in snapshot.data!.docs) {
                  final data = tripDoc.data() as Map<String, dynamic>;
                  final city = data['city'] ?? 'Unknown City';

                  if (data['hotelDocumentUrl'] != null) {
                    allDocs.add({
                      'name': data['hotelDocumentName'] ?? 'Hotel Document',
                      'url': data['hotelDocumentUrl'],
                      'subtitle': 'Hotel: ${data['hotelName'] ?? 'Unknown'} ($city)',
                      'type': 'hotel',
                    });
                  }

                  final List<dynamic>? places = data['places'];
                  if (places != null) {
                    for (var place in places) {
                      if (place is Map<String, dynamic> && place['documentUrl'] != null) {
                        allDocs.add({
                          'name': place['documentName'] ?? 'Place Document',
                          'url': place['documentUrl'],
                          'subtitle': 'Place: ${place['name'] ?? 'Unknown'} ($city)',
                          'type': 'place',
                        });
                      }
                    }
                  }
                }

                if (allDocs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: allDocs.length,
                  itemBuilder: (context, index) {
                    final doc = allDocs[index];
                    final isHotel = doc['type'] == 'hotel';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 10), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isHotel ? Colors.blue : _accent).withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isHotel ? Icons.hotel_rounded : Icons.place_rounded,
                            color: isHotel ? Colors.blue : _accent,
                            size: 22,
                          ),
                        ),
                        title: Text(doc['name'], style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(doc['subtitle'], style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF5F0E8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.open_in_new_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                        ),
                        onTap: () => _openFile(doc['url']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accent.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_rounded, size: 48, color: _accent.withAlpha(150)),
          ),
          const SizedBox(height: 20),
          Text('No documents found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Upload documents while planning your trip', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
