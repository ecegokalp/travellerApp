import 'package:flutter/material.dart';

class SavedTripsPage extends StatelessWidget {
  const SavedTripsPage({super.key});

  static const _coral = Color(0xFFFF6B6B);
  static const _cream = Color(0xFFFFF8F0);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Adventures',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildTripCard(
            context,
            'Cappadocia, Turkey',
            'Hot air balloons & fairy chimneys',
            'https://images.unsplash.com/photo-1541167760496-1628856ab772?q=80&w=500',
            '4.9',
          ),
          const SizedBox(height: 20),
          _buildTripCard(
            context,
            'Bali, Indonesia',
            'Tropical paradise and temples',
            'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=500',
            '4.8',
          ),
          const SizedBox(height: 20),
          _buildTripCard(
            context,
            'Santorini, Greece',
            'Sunset views and white houses',
            'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=500',
            '4.7',
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    String title,
    String subtitle,
    String imageUrl,
    String rating,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported_outlined, color: _warmGray),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: _coral, size: 20),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _warmGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
