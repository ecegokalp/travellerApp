import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TripDetailsPage extends StatelessWidget {
  final Map<String, dynamic> tripData;

  const TripDetailsPage({super.key, required this.tripData});

  static const _coral = Color(0xFFFF6B6B);

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final cardColor = Theme.of(context).cardColor;

    final city = tripData['city'] ?? 'Unknown City';
    final country = tripData['country'] ?? '';
    final hotelName = tripData['hotelName'] ?? 'No hotel planned';
    final hotelPrice = tripData['hotelPrice'] ?? 0;
    final totalBudget = tripData['totalBudget'] ?? 0;
    final List<dynamic> places = tripData['places'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('$city Plan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_coral, Color(0xFFFF8E8E)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    '$city, $country',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Budget: ${totalBudget.toStringAsFixed(0)} ₺',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Hotel Section
            _buildSectionTitle('Accommodation', textColor, Icons.hotel_rounded),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(hotelName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text('${hotelPrice.toStringAsFixed(0)} ₺'),
                    trailing: tripData['hotelDocumentUrl'] != null
                        ? IconButton(
                            icon: const Icon(Icons.description, color: _coral),
                            onPressed: () => _openFile(tripData['hotelDocumentUrl']),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Places Section
            _buildSectionTitle('Places to Visit', textColor, Icons.map_rounded),
            const SizedBox(height: 12),
            if (places.isEmpty)
              const Text('No places added to this plan.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index] as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(place['name'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      subtitle: Text('${(place['price'] ?? 0).toStringAsFixed(0)} ₺'),
                      trailing: place['documentUrl'] != null
                          ? IconButton(
                              icon: const Icon(Icons.attach_file, color: _coral, size: 20),
                              onPressed: () => _openFile(place['documentUrl']),
                            )
                          : null,
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _coral, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
