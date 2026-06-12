import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  static const _accent = Color(0xFFFF6B6B);
  final AuthService _authService = AuthService();
  final GeminiService _geminiService = GeminiService();
  final NotificationService _notificationService = NotificationService();
  bool _isUploading = false;
  double _uploadProgress = 0;

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Upload Document', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_rounded, color: Colors.blue)),
                title: Text('File / PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Pick from files or Drive', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                onTap: () { Navigator.pop(context); _uploadDocument(); },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_rounded, color: Colors.orange)),
                title: Text('Image / Screenshot', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('JPG, PNG from gallery or Drive', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                onTap: () { Navigator.pop(context); _uploadImage(); },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.camera_alt_rounded, color: Colors.green)),
                title: Text('Camera', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Take a photo of your ticket', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                onTap: () { Navigator.pop(context); _uploadFromCamera(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadImage() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // FileType.image opens system picker that includes Drive
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        final fileName = pickedFile.name;

        File file;
        if (pickedFile.path != null) {
          file = File(pickedFile.path!);
        } else if (pickedFile.bytes != null) {
          final tempDir = Directory.systemTemp;
          file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(pickedFile.bytes!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read file'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
            );
          }
          return;
        }

        setState(() { _isUploading = true; _uploadProgress = 0; });
        await _doUpload(file, fileName, user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadFromCamera() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;

      setState(() { _isUploading = true; _uploadProgress = 0; });

      final file = File(picked.path);
      final fileName = picked.name;
      await _doUpload(file, fileName, user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _doUpload(File file, String fileName, String uid) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'users/$uid/documents/${timestamp}_$fileName';

    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final uploadTask = ref.putFile(file);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (mounted) {
        setState(() { _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes; });
      }
    });

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('personal_documents')
        .add({
      'name': fileName,
      'url': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'general',
      'size': await file.length(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName uploaded!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
    }

    // Process with Gemini for calendar
    _processDocumentForCalendar(file, fileName, docRef.id, uid);
  }

  Future<void> _uploadDocument() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        final fileName = pickedFile.name;

        File file;
        if (pickedFile.path != null) {
          file = File(pickedFile.path!);
        } else if (pickedFile.bytes != null) {
          final tempDir = Directory.systemTemp;
          file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(pickedFile.bytes!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read file'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
            );
          }
          return;
        }

        setState(() { _isUploading = true; _uploadProgress = 0; });
        await _doUpload(file, fileName, user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _processDocumentForCalendar(File file, String fileName, String docId, String uid) async {
    try {
      final extracted = await _geminiService.processDocument(file);
      debugPrint('Gemini extracted: $extracted');
      if (extracted == null) return;

      String? str(dynamic v) => v is String ? v : v is List ? v.firstOrNull?.toString() : v?.toString();
      final name = str(extracted['name']) ?? fileName;
      final city = str(extracted['city']);
      final country = str(extracted['country']);
      final startDateStr = str(extracted['startDate']);
      final endDateStr = str(extracted['endDate']);

      // Determine event type from file name, extracted name, and Gemini type hint
      String eventType = 'travel';
      final geminiType = str(extracted['type'])?.toLowerCase() ?? '';
      final lowerName = '${fileName.toLowerCase()} ${name.toLowerCase()} $geminiType';

      // Airlines list for auto-detecting flights
      const airlines = ['sunexpress', 'sun express', 'thy', 'turkish airlines', 'türk hava',
        'pegasus', 'anadolujet', 'onur air', 'corendon', 'ryanair', 'easyjet',
        'lufthansa', 'emirates', 'qatar', 'wizz', 'flydubai', 'airfrance'];

      if (lowerName.contains('flight') || lowerName.contains('uçuş') || lowerName.contains('boarding') ||
          lowerName.contains('havayol') || lowerName.contains('airline') ||
          airlines.any((a) => lowerName.contains(a))) {
        eventType = 'flight';
      } else if (lowerName.contains('hotel') || lowerName.contains('otel') || lowerName.contains('reservation') ||
          lowerName.contains('booking') || lowerName.contains('airbnb') || lowerName.contains('konaklama')) {
        eventType = 'hotel';
      } else if (lowerName.contains('bus') || lowerName.contains('otobüs') || lowerName.contains('train') || lowerName.contains('tren')) {
        eventType = 'transport';
      } else if (lowerName.contains('ticket') || lowerName.contains('bilet')) {
        eventType = 'ticket';
      }

      if (startDateStr == null) return;

      final startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) return;

      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      // For flights: save departure and return as separate events, not a range
      // For hotels: keep the range (startDate to endDate)
      if (eventType == 'flight' && endDate != null) {
        // Departure event
        final depRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .add({
          'name': '$name (Departure)',
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Return event
        final retRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .add({
          'name': '$name (Return)',
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(endDate),
          'endDate': null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _notificationService.scheduleEventReminders(
          eventId: depRef.id, eventName: '$name (Departure)',
          eventType: _eventTypeLabel(eventType), eventDate: startDate, city: city,
        );
        await _notificationService.scheduleEventReminders(
          eventId: retRef.id, eventName: '$name (Return)',
          eventType: _eventTypeLabel(eventType), eventDate: endDate, city: city,
        );

        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('personal_documents').doc(docId)
            .update({
          'type': eventType,
          'extractedData': extracted,
          'calendarEventId': depRef.id,
          'calendarEventIdReturn': retRef.id,
        });
      } else {
        // Hotels, transport, etc. — keep as range
        final eventRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .add({
          'name': name,
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _notificationService.scheduleEventReminders(
          eventId: eventRef.id, eventName: name,
          eventType: _eventTypeLabel(eventType), eventDate: startDate, city: city,
        );

        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('personal_documents').doc(docId)
            .update({
          'type': eventType,
          'extractedData': extracted,
          'calendarEventId': eventRef.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Added to calendar: $name', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: const Color(0xFF4A90D9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Document calendar processing error: $e');
    }
  }

  String _eventTypeLabel(String type) {
    switch (type) {
      case 'flight': return 'flight';
      case 'hotel': return 'hotel reservation';
      case 'transport': return 'transport';
      case 'ticket': return 'ticket';
      default: return 'travel event';
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
      // Get document data to check for linked calendar event
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_documents')
          .doc(docId)
          .get();

      final docData = docSnap.data();
      final calendarEventId = docData?['calendarEventId'] as String?;
      final calendarEventIdReturn = docData?['calendarEventIdReturn'] as String?;

      // Delete linked calendar events and cancel notifications
      for (final eventId in [calendarEventId, calendarEventIdReturn]) {
        if (eventId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('calendar_events')
              .doc(eventId)
              .delete();
          await _notificationService.cancelEventReminders(eventId);
        }
      }

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

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'flight': return Icons.flight_rounded;
      case 'hotel': return Icons.hotel_rounded;
      case 'transport': return Icons.directions_bus_rounded;
      case 'ticket': return Icons.confirmation_number_rounded;
      default: return Icons.description_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'flight': return Colors.blue;
      case 'hotel': return Colors.purple;
      case 'transport': return Colors.orange;
      case 'ticket': return Colors.teal;
      default: return Colors.teal;
    }
  }

  String? _asString(dynamic v) {
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return v.first?.toString();
    return v?.toString();
  }

  String _typeSubtitle(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'general';
    final extracted = data['extractedData'] as Map<String, dynamic>?;
    if (extracted != null) {
      final city = _asString(extracted['city']);
      final startDate = _asString(extracted['startDate']);
      final parts = <String>[];
      if (city != null) parts.add(city);
      if (startDate != null) parts.add(startDate);
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    switch (type) {
      case 'flight': return 'Flight Ticket';
      case 'hotel': return 'Hotel Reservation';
      case 'transport': return 'Transport Ticket';
      case 'ticket': return 'Event Ticket';
      default: return 'Personal Document';
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
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton(
          onPressed: _isUploading ? null : _showUploadOptions,
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
                        final type = data['type'] as String?;

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
                                color: _typeColor(type).withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
                            ),
                            title: Text(name, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(_typeSubtitle(data), style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (data['calendarEventId'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(Icons.calendar_today_rounded, size: 16, color: _accent.withAlpha(180)),
                                  ),
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
          Text('Upload flight tickets, hotel bookings\nand they\'ll appear in your calendar!', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
