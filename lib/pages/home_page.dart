import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import 'settings_page.dart';
import 'planner_page.dart';
import 'trip_details_page.dart';
import 'profile_page.dart';
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

  static const _accent = Color(0xFFFF6B6B);
  static const _accentLight = Color(0xFFFF8E53);
  static const _warmGray = Color(0xFF6B7280);
  static const _darkText = Color(0xFF1F2937);

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
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                    ),
                    child: Icon(Icons.notifications_none_rounded, size: 22, color: isDark ? Colors.white70 : _darkText),
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
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFFAA85)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: _accent.withAlpha(60), blurRadius: 24, offset: const Offset(0, 12)),
                          ],
                        ),
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
                              'Ready to\nExplore?',
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
                    ),
                    const SizedBox(height: 28),

                    // My Trips Section
                    _buildMyTripsSection(context, textColor, secondaryTextColor, isDark, cardColor),
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
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
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
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => BlogPage(initialCity: city, initialCountry: country)));
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

  Widget _buildCalendarSection(Color cardColor, Color textColor, Color secondaryTextColor, bool isDark) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final newEvents = <DateTime, List<dynamic>>{};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();
            final city = data['city'] ?? 'Trip';

            if (startDate != null && endDate != null) {
              DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
              DateTime last = DateTime(endDate.year, endDate.month, endDate.day);

              // Cap at 365 days to prevent infinite/huge loops
              int safety = 0;
              while ((current.isBefore(last) || current.isAtSameMomentAs(last)) && safety < 365) {
                final dayKey = DateTime(current.year, current.month, current.day);
                if (newEvents[dayKey] == null) newEvents[dayKey] = [];
                newEvents[dayKey]!.add({
                  'city': city,
                  'country': data['country'] ?? '',
                  'hotel': data['hotelName'] ?? '',
                  'budget': data['totalBudgetTRY'] ?? 0,
                  'id': doc.id,
                  'data': data,
                });
                current = current.add(const Duration(days: 1));
                safety++;
              }
            } else if (startDate != null) {
              final dayKey = DateTime(startDate.year, startDate.month, startDate.day);
              if (newEvents[dayKey] == null) newEvents[dayKey] = [];
              newEvents[dayKey]!.add({
                'city': city,
                'country': data['country'] ?? '',
                'hotel': data['hotelName'] ?? '',
                'budget': data['totalBudgetTRY'] ?? 0,
                'id': doc.id,
                'data': data,
              });
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
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: _accent.withAlpha(60), shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
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
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accent.withAlpha(30)),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TripDetailsPage(tripData: e['data'], tripId: e['id']),
                        ));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: _accent),
                              const SizedBox(width: 4),
                              Text('${e['city']}, ${e['country']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
                              const Spacer(),
                              Text('${e['budget'].toStringAsFixed(0)} ₺', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          if (e['hotel'].isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.hotel, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(e['hotel'], style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
