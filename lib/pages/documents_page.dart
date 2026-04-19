import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Documents'),
      ),
      body: user == null
          ? const Center(child: Text('Please login to see documents'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('trips')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Flatten all documents (Hotel + Places) into a single list
                List<Map<String, dynamic>> allDocs = [];

                for (var tripDoc in snapshot.data!.docs) {
                  final data = tripDoc.data() as Map<String, dynamic>;
                  final city = data['city'] ?? 'Unknown City';
                  
                  // Add Hotel Document if exists
                  if (data['hotelDocumentUrl'] != null) {
                    allDocs.add({
                      'name': data['hotelDocumentName'] ?? 'Hotel Document',
                      'url': data['hotelDocumentUrl'],
                      'subtitle': 'Hotel: ${data['hotelName'] ?? 'Unknown'} ($city)',
                      'type': 'hotel',
                    });
                  }

                  // Add Place Documents if they exist
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
                  return _buildEmptyState();
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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isHotel ? Colors.blue : const Color(0xFFFF6B6B)).withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isHotel ? Icons.hotel_rounded : Icons.place_rounded,
                            color: isHotel ? Colors.blue : const Color(0xFFFF6B6B),
                          ),
                        ),
                        title: Text(
                          doc['name'],
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          doc['subtitle'],
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 20, color: Colors.grey),
                        onTap: () => _openFile(doc['url']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.withAlpha(100)),
          const SizedBox(height: 16),
          const Text('No documents found'),
          const SizedBox(height: 8),
          const Text('Upload documents while planning your trip', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
