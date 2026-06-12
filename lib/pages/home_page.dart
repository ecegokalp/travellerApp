import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'settings_page.dart';
import 'planner_page.dart';
import 'trip_details_page.dart';
import 'blog_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String _displayName = '';
  String _photoUrl = '';
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  final PageController _checklistController = PageController(viewportFraction: 0.95);
  int _checklistPage = 0;

  int _heroImageIndex = 0;
  Timer? _heroImageTimer;

  static const _accent = Color(0xFF0D9488);
  static const _accentLight = Color(0xFF2DD4BF);
  static const _warmGray = Color(0xFF6B7280);
  static const _darkText = Color(0xFF1F2937);

  static const _heroImages = [
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=1200&q=85',
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200&q=85',
    'https://images.unsplash.com/photo-1526392060635-9d6019884377?w=1200&q=85',
    'https://images.unsplash.com/photo-1555400038-63f5ba517a47?w=1200&q=85',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=1200&q=85',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _heroImageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _heroImageIndex = (_heroImageIndex + 1) % _heroImages.length);
    });
  }

  @override
  void dispose() {
    _checklistController.dispose();
    _heroImageTimer?.cancel();
    super.dispose();
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
          _photoUrl = profile?['photoUrl'] ?? '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayName = fallbackName;
        });
      }
    }
  }

  Future<void> _deleteTrip(String tripId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .doc(tripId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting trip: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(String tripId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _warmGray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrip(tripId);
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : _darkText;
    final secondaryTextColor = isDark ? Colors.white70 : _warmGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  // Avatar leading to Settings
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                      _loadUserData();
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_accent, _accentLight]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: _accent.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        image: _photoUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_photoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _photoUrl.isEmpty
                          ? Center(
                              child: Text(
                                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'T',
                                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor)),
                        const SizedBox(height: 2),
                        Text(
                          _displayName.isNotEmpty ? _displayName : 'Traveller',
                          style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  GestureDetector(
                    onTap: () => _showNotifications(context, isDark, textColor),
                    child: StreamBuilder<int>(
                      stream: _authService.currentUser != null
                          ? _authService.getUnreadNotificationCount(_authService.currentUser!.uid)
                          : Stream.value(0),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return Stack(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                              ),
                              child: Icon(count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded, size: 22, color: isDark ? Colors.white70 : _darkText),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 0, top: 0,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                  child: Center(child: Text(count > 9 ? '9+' : '$count', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerPage()));
                      },
                      child: Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: _accent.withAlpha(60), blurRadius: 24, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 1200),
                                child: SizedBox.expand(
                                  key: ValueKey(_heroImages[_heroImageIndex]),
                                  child: CachedNetworkImage(
                                    imageUrl: _heroImages[_heroImageIndex],
                                    fit: BoxFit.cover,
                                    placeholder: (_, p1) => Container(color: _accent),
                                    errorWidget: (_, e1, e2) => Container(color: _accent),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withAlpha(70),
                                      Colors.black.withAlpha(40),
                                      Colors.black.withAlpha(140),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(40),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white.withAlpha(30)),
                                        ),
                                        child: const Icon(Icons.flight_takeoff_rounded, size: 28, color: Colors.white),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(30),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Plan Your\nTrip',
                                    style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Plan your next adventure.\nSave hotels, places and track your budget.',
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withAlpha(210), height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // My Trips Section
                    _buildMyTripsSection(context, textColor, secondaryTextColor, isDark, cardColor),
                    const SizedBox(height: 28),

                    // Trip Checklist Section
                    _buildTripChecklist(textColor, secondaryTextColor, isDark, cardColor),
                    const SizedBox(height: 28),

                    // Travel Calendar Section
                    _buildCalendarSection(cardColor, textColor, secondaryTextColor, isDark),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTripsSection(BuildContext context, Color textColor, Color secondaryTextColor, bool isDark, Color cardColor) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Trips', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('trips')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  ),
                  child: Center(
                    child: Text('No planned trips yet. Start exploring!', style: GoogleFonts.inter(color: secondaryTextColor, fontSize: 13)),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final city = data['city'] ?? 'Unknown';
                  final country = data['country'] ?? '';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TripDetailsPage(tripData: data, tripId: docs[index].id),
                      ));
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _accent.withAlpha(40), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10, top: -10,
                            child: Icon(Icons.flight_takeoff, color: Colors.white.withAlpha(30), size: 60),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _confirmDelete(docs[index].id),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  city,
                                  style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (country.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(country, style: GoogleFonts.inter(color: Colors.white.withAlpha(180), fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(35),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        showCreateStorySheet(context, initialCity: city, initialCountry: country);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(40),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context, bool isDark, Color textColor) {
    final user = _authService.currentUser;
    if (user == null) return;

    // Mark all as read when opening
    _authService.markNotificationsRead(user.uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _authService.getNotifications(user.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: _warmGray.withAlpha(120)),
                          const SizedBox(height: 12),
                          Text('No notifications yet', style: GoogleFonts.inter(color: _warmGray)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final n = docs[i].data() as Map<String, dynamic>;
                      final fromName = n['fromName'] ?? 'Someone';
                      final fromPhoto = n['fromPhoto'] as String? ?? '';
                      final message = n['message'] ?? '';
                      final type = n['type'] ?? '';
                      final isRead = n['read'] == true;
                      final createdAt = (n['createdAt'] as Timestamp?)?.toDate();

                      IconData icon;
                      Color iconColor;
                      switch (type) {
                        case 'like':
                          icon = Icons.favorite_rounded;
                          iconColor = _accent;
                          break;
                        case 'comment':
                          icon = Icons.chat_bubble_rounded;
                          iconColor = Colors.blue;
                          break;
                        case 'save':
                          icon = Icons.bookmark_rounded;
                          iconColor = Colors.amber[700]!;
                          break;
                        case 'follow':
                          icon = Icons.person_add_rounded;
                          iconColor = const Color(0xFF2ECC71);
                          break;
                        default:
                          icon = Icons.notifications_rounded;
                          iconColor = _warmGray;
                      }

                      String timeAgo = '';
                      if (createdAt != null) {
                        final diff = DateTime.now().difference(createdAt);
                        if (diff.inMinutes < 1) {
                          timeAgo = 'just now';
                        } else if (diff.inMinutes < 60) {
                          timeAgo = '${diff.inMinutes}m';
                        } else if (diff.inHours < 24) {
                          timeAgo = '${diff.inHours}h';
                        } else {
                          timeAgo = '${diff.inDays}d';
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.transparent : _accent.withAlpha(8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _accent.withAlpha(30),
                              backgroundImage: fromPhoto.isNotEmpty ? NetworkImage(fromPhoto) : null,
                              child: fromPhoto.isEmpty ? Text(fromName[0].toUpperCase(), style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(fontSize: 13, color: textColor),
                                  children: [
                                    TextSpan(text: fromName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: ' $message'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                Icon(icon, size: 18, color: iconColor),
                                if (timeAgo.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(timeAgo, style: GoogleFonts.inter(fontSize: 10, color: _warmGray)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripChecklist(Color textColor, Color secondaryTextColor, bool isDark, Color cardColor) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .orderBy('startDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final trips = <Map<String, dynamic>>[];
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final checklist = data['checklist'] as List? ?? [];
          if (checklist.isEmpty) continue;
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          if (endDate != null && endDate.isBefore(now)) continue; // skip past trips
          trips.add({'data': data, 'id': doc.id});
        }

        if (trips.isEmpty) return const SizedBox.shrink();

        final page = _checklistPage.clamp(0, trips.length - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _checklistController,
                itemCount: trips.length,
                onPageChanged: (i) => setState(() => _checklistPage = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildChecklistCard(
                    trips[i]['data'] as Map<String, dynamic>,
                    trips[i]['id'] as String,
                    user.uid,
                    textColor,
                    secondaryTextColor,
                    isDark,
                    cardColor,
                  ),
                ),
              ),
            ),
            if (trips.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(trips.length, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? _accent : _accent.withAlpha(60),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildChecklistCard(Map<String, dynamic> tripData, String tripId, String uid, Color textColor, Color secondaryTextColor, bool isDark, Color cardColor) {
    final now = DateTime.now();
    final checklist = (tripData['checklist'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final city = tripData['city'] ?? '';
    final country = tripData['country'] ?? '';
    final startDate = (tripData['startDate'] as Timestamp?)?.toDate();
    final doneCount = checklist.where((c) => c['done'] == true).length;
    final total = checklist.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    String? dueLabel;
    if (startDate != null && startDate.isAfter(now)) {
      final days = startDate.difference(now).inDays;
      if (days <= 7) {
        dueLabel = days == 0 ? 'Today!' : days == 1 ? 'Tomorrow' : 'In $days days';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 8), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.checklist_rounded, color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip Checklist', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                    if (city.isNotEmpty)
                      Text('$city${country.isNotEmpty ? ', $country' : ''}', style: GoogleFonts.inter(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('$doneCount/$total Done', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor)),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? const Color(0xFF2ECC71) : _accent),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: checklist.length,
              itemBuilder: (context, i) {
                final item = checklist[i];
                final isDone = item['done'] == true;
                return GestureDetector(
                  onTap: () {
                    checklist[i]['done'] = !isDone;
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('trips')
                        .doc(tripId)
                        .update({'checklist': checklist});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: isDone ? const Color(0xFF2ECC71) : (isDark ? Colors.white30 : Colors.grey[400]),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['text'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDone ? secondaryTextColor : textColor,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (dueLabel != null && !isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(dueLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _accent)),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.grey[400]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(Color cardColor, Color textColor, Color secondaryTextColor, bool isDark) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<QuerySnapshot>>(
      stream: _combinedCalendarStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.length == 2) {
          final newEvents = <DateTime, List<dynamic>>{};

          for (var doc in snapshot.data![0].docs) {
            final data = doc.data() as Map<String, dynamic>;
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();
            final city = data['city'] ?? 'Trip';
            final country = data['country'] ?? '';

            void addFlight(DateTime date, String leg) {
              final dayKey = DateTime(date.year, date.month, date.day);
              if (newEvents[dayKey] == null) newEvents[dayKey] = [];
              newEvents[dayKey]!.add({
                'city': city,
                'country': country,
                'leg': leg,
                'type': 'flight',
                'id': doc.id,
                'data': data,
                'source': 'tripFlight',
              });
            }

            if (startDate != null) addFlight(startDate, 'Departure');
            if (endDate != null) addFlight(endDate, 'Return');
          }

          // Process calendar events (from documents)
          for (var doc in snapshot.data![1].docs) {
            final data = doc.data() as Map<String, dynamic>;
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();
            final name = data['name'] ?? 'Event';
            final type = data['type'] ?? 'travel';

            if (startDate == null) continue;

            // Flights: only mark the single day (departure or return)
            // Hotels/other: mark the full date range
            if (type == 'flight' || endDate == null) {
              final dayKey = DateTime(startDate.year, startDate.month, startDate.day);
              if (newEvents[dayKey] == null) newEvents[dayKey] = [];
              newEvents[dayKey]!.add({
                'name': name,
                'type': type,
                'city': data['city'] ?? '',
                'country': data['country'] ?? '',
                'id': doc.id,
                'source': 'document',
              });
            } else {
              DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
              DateTime last = DateTime(endDate.year, endDate.month, endDate.day);

              int safety = 0;
              while ((current.isBefore(last) || current.isAtSameMomentAs(last)) && safety < 365) {
                final dayKey = DateTime(current.year, current.month, current.day);
                if (newEvents[dayKey] == null) newEvents[dayKey] = [];
                newEvents[dayKey]!.add({
                  'name': name,
                  'type': type,
                  'city': data['city'] ?? '',
                  'country': data['country'] ?? '',
                  'id': doc.id,
                  'source': 'document',
                });
                current = current.add(const Duration(days: 1));
                safety++;
              }
            }
          }

          _events = newEvents;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 8), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _accent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.calendar_month_rounded, color: _accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Travel Calendar', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                ],
              ),
              const SizedBox(height: 8),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  return _events[DateTime(day.year, day.month, day.day)] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: _markerColor(events), shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: _accent.withAlpha(60), shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                  markersMaxCount: 1,
                  defaultTextStyle: GoogleFonts.inter(color: textColor),
                  weekendTextStyle: GoogleFonts.inter(color: textColor.withAlpha(150)),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: _accent),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: _accent),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.inter(color: secondaryTextColor, fontWeight: FontWeight.w600, fontSize: 12),
                  weekendStyle: GoogleFonts.inter(color: secondaryTextColor.withAlpha(150), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              if (_selectedDay != null && _events[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] != null)
                ...(_events[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]!).map((event) {
                  final e = event as Map<String, dynamic>;
                  if (e['source'] == 'document') {
                    return _buildDocumentEventCard(e, textColor, secondaryTextColor);
                  }
                  return _buildTripFlightCard(e, textColor, secondaryTextColor);
                }),
            ],
          ),
        );
      },
    );
  }

  Color _markerColor(List events) {
    bool has(String type) => events.any((e) {
      final m = e as Map<String, dynamic>;
      final src = m['source'];
      return (src == 'document' || src == 'tripFlight') && m['type'] == type;
    });
    if (has('flight')) return Colors.blue;
    if (has('hotel')) return Colors.purple;
    if (has('transport')) return Colors.orange;
    if (has('ticket')) return Colors.teal;
    return _accent;
  }

  Widget _buildTripFlightCard(Map<String, dynamic> e, Color textColor, Color secondaryTextColor) {
    final leg = e['leg'] as String? ?? 'Flight';
    final city = e['city'] as String? ?? '';
    final country = e['country'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withAlpha(40)),
      ),
      child: InkWell(
        onTap: e['data'] != null
            ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => TripDetailsPage(tripData: e['data'], tripId: e['id'])))
            : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.flight_rounded, size: 18, color: Colors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flight ($leg)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                  if (city.isNotEmpty)
                    Text('$city${country.isNotEmpty ? ', $country' : ''}', style: GoogleFonts.inter(fontSize: 11, color: secondaryTextColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Text(leg, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentEventCard(Map<String, dynamic> e, Color textColor, Color secondaryTextColor) {
    final type = e['type'] as String? ?? 'travel';
    final name = e['name'] as String? ?? 'Event';
    final city = e['city'] as String? ?? '';
    final country = e['country'] as String? ?? '';

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'flight':
        icon = Icons.flight_rounded;
        iconColor = Colors.blue;
        break;
      case 'hotel':
        icon = Icons.hotel_rounded;
        iconColor = Colors.purple;
        break;
      case 'transport':
        icon = Icons.directions_bus_rounded;
        iconColor = Colors.orange;
        break;
      case 'ticket':
        icon = Icons.confirmation_number_rounded;
        iconColor = Colors.teal;
        break;
      default:
        icon = Icons.event_rounded;
        iconColor = _accent;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (city.isNotEmpty)
                  Text('$city${country.isNotEmpty ? ', $country' : ''}', style: GoogleFonts.inter(fontSize: 11, color: secondaryTextColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type == 'flight' ? 'Flight' : type == 'hotel' ? 'Hotel' : type == 'transport' ? 'Transport' : 'Event',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<QuerySnapshot>> _combinedCalendarStream(String uid) {
    final tripsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('trips')
        .snapshots();

    final eventsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar_events')
        .snapshots();

    // Combine both streams - emit when either changes
    QuerySnapshot? lastTrips;
    QuerySnapshot? lastEvents;
    final controller = StreamController<List<QuerySnapshot>>();

    final tripsSub = tripsStream.listen((snap) {
      lastTrips = snap;
      if (lastEvents != null) controller.add([lastTrips!, lastEvents!]);
    });

    final eventsSub = eventsStream.listen((snap) {
      lastEvents = snap;
      if (lastTrips != null) controller.add([lastTrips!, lastEvents!]);
    });

    controller.onCancel = () {
      tripsSub.cancel();
      eventsSub.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
