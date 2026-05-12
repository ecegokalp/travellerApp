import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  static const _accent = Color(0xFFFF6B6B);
  final AuthService _authService = AuthService();
  bool _isUploading = false;
  double _uploadProgress = 0;

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _uploadDocument() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0;
        });

        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = 'users/${user.uid}/documents/${timestamp}_$fileName';

        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final uploadTask = ref.putFile(file);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('personal_documents')
            .add({
          'name': fileName,
          'url': downloadUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'general',
          'size': result.files.single.size,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fileName uploaded successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteDocument(String docId, String fileName, String? url) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$fileName"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (url != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_documents')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
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
      floatingActionButton: user == null ? null : Padding(
        padding: const EdgeInsets.only(bottom: 90), // Alt menünün üzerinde görünmesi için
        child: FloatingActionButton(
          onPressed: _isUploading ? null : _uploadDocument,
          backgroundColor: _accent,
          child: _isUploading 
            ? CircularProgressIndicator(value: _uploadProgress, color: Colors.white, strokeWidth: 2)
            : const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
      body: user == null
          ? Center(child: Text('Please login to see documents', style: GoogleFonts.inter(color: Colors.grey)))
          : Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('personal_documents')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _accent));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Untitled';
                        final url = data['url'];

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
                                color: Colors.teal.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.description_rounded, color: Colors.teal, size: 22),
                            ),
                            title: Text(name, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Personal Document', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteDocument(doc.id, name, url),
                                ),
                                IconButton(
                                  icon: Icon(Icons.open_in_new_rounded, size: 20, color: isDark ? Colors.white54 : Colors.grey),
                                  onPressed: () => url != null ? _openFile(url) : null,
                                ),
                              ],
                            ),
                            onTap: () => url != null ? _openFile(url) : null,
                          ),
                        );
                      },
                    );
                  },
                ),
                if (_isUploading)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
              ],
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
          Text('Upload documents by clicking the + button', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
