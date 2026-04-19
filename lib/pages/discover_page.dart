import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'details_page.dart';
import 'saved_trips_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  static const _coral = Color(0xFFFF6B6B);
  static const _cream = Color(0xFFFFF8F0);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  int selectedCategory = 0;

  final List<Map<String, String>> categories = [
    {'name': 'All', 'icon': '🌍'},
    {'name': 'Cities', 'icon': '🏙️'},
    {'name': 'History', 'icon': '🏛️'},
    {'name': 'Beaches', 'icon': '🏖️'},
    {'name': 'Mountains', 'icon': '🏔️'},
    {'name': 'Forests', 'icon': '🌲'},
    {'name': 'Desert', 'icon': '🌵'},
    {'name': 'Camping', 'icon': '⛺'},
    {'name': 'Islands', 'icon': '🏝️'},
    {'name': 'Art', 'icon': '🎨'},
  ];

  final List<Map<String, String>> allDestinations = [
    {'title': 'Paris, France', 'subtitle': 'The city of love', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=500', 'rating': '4.8', 'price': '\$120', 'category': 'Cities'},
    {'title': 'Petra, Jordan', 'subtitle': 'Ancient Rose City', 'image': 'https://images.unsplash.com/photo-1579606091094-119c43d2ec75?q=80&w=500', 'rating': '4.9', 'price': '\$85', 'category': 'History'},
    {'title': 'Maldives', 'subtitle': 'Crystal clear waters', 'image': 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?q=80&w=500', 'rating': '4.9', 'price': '\$250', 'category': 'Beaches'},
    {'title': 'Sahara Desert', 'subtitle': 'Golden dunes', 'image': 'https://images.unsplash.com/photo-1509063255018-b80c102a900c?q=80&w=500', 'rating': '4.6', 'price': '\$110', 'category': 'Desert'},
    {'title': 'Swiss Alps', 'subtitle': 'Snowy peaks', 'image': 'https://images.unsplash.com/photo-1531310197839-ccf54634509e?q=80&w=500', 'rating': '4.7', 'price': '\$180', 'category': 'Mountains'},
    {'title': 'Yosemite, USA', 'subtitle': 'Camping adventure', 'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=500', 'rating': '4.8', 'price': '\$60', 'category': 'Camping'},
    {'title': 'Colosseum, Italy', 'subtitle': 'Ancient history', 'image': 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?q=80&w=500', 'rating': '4.9', 'price': '\$140', 'category': 'History'},
    {'title': 'Amazon Forest', 'subtitle': 'Pure nature', 'image': 'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?q=80&w=500', 'rating': '4.5', 'price': '\$95', 'category': 'Forests'},
    {'title': 'Santorini, Greece', 'subtitle': 'Blue domes', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=500', 'rating': '5.0', 'price': '\$220', 'category': 'Islands'},
    {'title': 'Louvre Museum', 'subtitle': 'World of Art', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=500', 'rating': '4.8', 'price': '\$50', 'category': 'Art'},
  ];

  void _scrollToTop() => _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  void _scrollToBottom() => _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);

  List<Map<String, String>> get filteredDestinations {
    if (selectedCategory == 0) return allDestinations;
    return allDestinations.where((d) => d['category'] == categories[selectedCategory]['name']).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDarkMode ? Colors.white : _darkText;
    final secondaryTextColor = isDarkMode ? Colors.white70 : _warmGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'top_btn',
            onPressed: _scrollToTop,
            backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            elevation: 4,
            mini: false,
            child: const Icon(Icons.arrow_upward_rounded, color: _coral),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'bottom_btn',
            onPressed: _scrollToBottom,
            backgroundColor: _coral,
            elevation: 4,
            mini: false,
            child: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          'Discover',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Explore Worlds',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search destinations...',
                          hintStyle: TextStyle(color: secondaryTextColor),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: _coral),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Kategoriler
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: categories.asMap().entries.map((entry) {
                    int index = entry.key;
                    var category = entry.value;
                    bool isSelected = selectedCategory == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => selectedCategory = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? _coral : cardColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: _coral.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                            ],
                          ),
                          child: Text(
                            '${category['icon']} ${category['name']}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: filteredDestinations.map((d) => _buildCard(d)).toList(),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> d) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDarkMode ? Colors.white : _darkText;
    final secondaryTextColor = isDarkMode ? Colors.white70 : _warmGray;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(d['image']!, height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      d['title']!,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          d['rating']!,
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(d['subtitle']!, style: TextStyle(color: secondaryTextColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${d['price']}/day',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _coral),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await _authService.saveTrip({
                              'title': d['title']!,
                              'subtitle': d['subtitle']!,
                              'image': d['image']!,
                              'rating': d['rating']!,
                            });
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SavedTripsPage()),
                              );
                            }
                          },
                          icon: const Icon(Icons.bookmark_border, color: _coral),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DestinationDetailPage(destination: d),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _coral,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
