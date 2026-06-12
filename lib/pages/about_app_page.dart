import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_widgets.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  static const _accent = Color(0xFF0D9488);

  static const _highlights = [
    (Icons.map_outlined, 'Plan trips with itineraries, flights, hotels and budgets in one place'),
    (Icons.folder_copy_outlined, 'Keep every travel document organised and within reach'),
    (Icons.explore_outlined, 'Discover top-rated places wherever you go'),
    (Icons.groups_outlined, 'Follow fellow travellers and share your own stories'),
  ];

  Future<void> _contactUs() async {
    final uri = Uri(scheme: 'mailto', path: 'hello@wanderapp.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFE8E4DC);

    return Scaffold(
      appBar: const AppHeader(title: 'About App'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: kBrandGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: kBrandPrimary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.explore_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 16),
                Text(
                  'Wander',
                  style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w800, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover the world, one journey at a time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Wander',
                  style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'Wander is your all-in-one travel companion. Plan every detail of your '
                  'next adventure, keep travel documents organised, discover great places '
                  'wherever you land, and share the journey with a community of fellow '
                  'travellers.',
                  style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _highlights.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 60, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _accent.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(_highlights[i].$1, color: _accent, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _highlights[i].$2,
                            style: GoogleFonts.inter(fontSize: 13, color: textColor, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _accent.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mail_outline_rounded, color: _accent, size: 20),
              ),
              title: Text('Contact Us', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              subtitle: Text('hello@wanderapp.com', style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor)),
              trailing: Icon(Icons.chevron_right_rounded, color: secondaryTextColor),
              onTap: _contactUs,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  'Made with care for travellers everywhere',
                  style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 Wander. All rights reserved.',
                  style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
