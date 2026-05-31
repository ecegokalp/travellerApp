import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'details_page.dart';
import 'blog_page.dart';
import 'profile_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final AuthService _authService = AuthService();
  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  int selectedCategory = 0;
  List<Map<String, dynamic>> _foundUsers = [];
  bool _isSearchingUsers = false;
  final TextEditingController _searchController = TextEditingController();

  // Cache suggested users so FutureBuilder doesn't re-fetch on every rebuild
  Future<List<Map<String, dynamic>>>? _suggestedUsersFuture;

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps_rounded},
    {'name': 'Cities', 'icon': Icons.location_city_rounded},
    {'name': 'History', 'icon': Icons.account_balance_rounded},
    {'name': 'Beaches', 'icon': Icons.beach_access_rounded},
    {'name': 'Mountains', 'icon': Icons.terrain_rounded},
    {'name': 'Forests', 'icon': Icons.forest_rounded},
    {'name': 'Desert', 'icon': Icons.wb_sunny_rounded},
    {'name': 'Camping', 'icon': Icons.hiking_rounded},
    {'name': 'Islands', 'icon': Icons.sailing_rounded},
    {'name': 'Art', 'icon': Icons.palette_rounded},
  ];

  final List<Map<String, String>> allDestinations = [
    {'title': 'Paris, France', 'subtitle': 'The city of love', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=500', 'rating': '4.8', 'price': '\$120', 'category': 'Cities'},
    {'title': 'Petra, Jordan', 'subtitle': 'Ancient Rose City', 'image': 'https://images.unsplash.com/photo-1580834341580-8c17a3a630ca?q=80&w=500', 'rating': '4.9', 'price': '\$85', 'category': 'History'},
    {'title': 'Maldives', 'subtitle': 'Crystal clear waters', 'image': 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?q=80&w=500', 'rating': '4.9', 'price': '\$250', 'category': 'Beaches'},
    {'title': 'Sahara Desert', 'subtitle': 'Golden dunes', 'image': 'https://images.unsplash.com/photo-1547235001-d703406d3f17?q=80&w=500', 'rating': '4.6', 'price': '\$110', 'category': 'Desert'},
    {'title': 'Swiss Alps', 'subtitle': 'Snowy peaks', 'image': 'https://images.unsplash.com/photo-1531310197839-ccf54634509e?q=80&w=500', 'rating': '4.7', 'price': '\$180', 'category': 'Mountains'},
    {'title': 'Yosemite, USA', 'subtitle': 'Camping adventure', 'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=500', 'rating': '4.8', 'price': '\$60', 'category': 'Camping'},
    {'title': 'Colosseum, Italy', 'subtitle': 'Ancient history', 'image': 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?q=80&w=500', 'rating': '4.9', 'price': '\$140', 'category': 'History'},
    {'title': 'Amazon Forest', 'subtitle': 'Pure nature', 'image': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?q=80&w=500', 'rating': '4.5', 'price': '\$95', 'category': 'Forests'},
    {'title': 'Santorini, Greece', 'subtitle': 'Blue domes', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=500', 'rating': '5.0', 'price': '\$220', 'category': 'Islands'},
    {'title': 'Louvre Museum', 'subtitle': 'World of Art', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=500', 'rating': '4.8', 'price': '\$50', 'category': 'Art'},
  ];

  List<Map<String, String>> get filteredDestinations {
    if (selectedCategory == 0) return allDestinations;
    return allDestinations.where((d) => d['category'] == categories[selectedCategory]['name']).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (Navigator.canPop(context))
                      _circleBtn(Icons.arrow_back_ios_new, isDark, cardColor, textColor, () => Navigator.pop(context))
                    else
                      const SizedBox(width: 44),
                    _circleBtn(Icons.edit_note_rounded, isDark, cardColor, textColor, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogPage()));
                    }),
                  ],
                ),
                const SizedBox(height: 28),

                // Big title
                Text(
                  'Select\ndestination',
                  style: GoogleFonts.playfairDisplay(fontSize: 38, fontWeight: FontWeight.w800, color: textColor, height: 1.1),
                ),
                const SizedBox(height: 20),

                // Search bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) async {
                      if (val.length > 2) {
                        setState(() => _isSearchingUsers = true);
                        final users = await _authService.searchUsers(val);
                        setState(() {
                          _foundUsers = users;
                        });
                      } else {
                        setState(() {
                          _isSearchingUsers = false;
                          _foundUsers = [];
                        });
                      }
                    },
                    style: GoogleFonts.inter(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search destinations or travellers...',
                      hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : _warmGray, fontSize: 14),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : _warmGray, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_foundUsers.isNotEmpty || _searchController.text.isEmpty) ...[
                  Text(_searchController.text.isEmpty ? 'Suggested Travellers' : 'Travellers', 
                      style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _searchController.text.isEmpty
                          ? (_suggestedUsersFuture ??= _authService.getSuggestedUsers())
                          : Future.value(_foundUsers),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final users = snapshot.data!;
                        if (users.isEmpty) return const SizedBox.shrink();

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: user['uid']))),
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 16),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: _accent.withAlpha(30),
                                      backgroundImage: (user['photoUrl'] ?? '').isNotEmpty ? NetworkImage(user['photoUrl']) : null,
                                      child: (user['photoUrl'] ?? '').isEmpty
                                          ? Text(user['fullName']?[0].toUpperCase() ?? 'U', style: const TextStyle(color: _accent, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(user['username'] ?? user['fullName'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: textColor), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Category chips with icons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: categories.asMap().entries.map((entry) {
                      int index = entry.key;
                      var cat = entry.value;
                      bool isSelected = selectedCategory == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => selectedCategory = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? _accent : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                              borderRadius: BorderRadius.circular(30),
                              border: isSelected ? null : Border.all(color: isDark ? Colors.white12 : const Color(0xFFE0DDD5)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.white60 : _warmGray)),
                              const SizedBox(width: 6),
                              Text(cat['name'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : (isDark ? Colors.white70 : _darkText))),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // 2-column grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filteredDestinations.length,
                  itemBuilder: (context, index) => _gridCard(filteredDestinations[index], isDark, cardColor, textColor),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, bool isDark, Color cardColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(15) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 18, color: isDark ? Colors.white70 : textColor),
      ),
    );
  }

  Widget _gridCard(Map<String, String> d, bool isDark, Color cardColor, Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DestinationDetailPage(destination: d))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: d['image']!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined)),
                  ),
                ),
                // Bottom gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0],
                        colors: [Colors.transparent, Colors.black.withAlpha(140)],
                      ),
                    ),
                  ),
                ),
                // Blog button
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () {
                      final parts = d['title']!.split(', ');
                      final city = parts[0];
                      final country = parts.length > 1 ? parts[1] : '';
                      
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BlogPage(
                        initialCountry: country,
                        initialCity: city,
                      )));
                    },
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: Colors.white.withAlpha(200), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_note_rounded, size: 18, color: _darkText),
                    ),
                  ),
                ),
                // Rating
                Positioned(
                  bottom: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(d['rating']!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            d['category']!.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _warmGray, letterSpacing: 1.5),
          ),
          const SizedBox(height: 2),
          Text(d['title']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
