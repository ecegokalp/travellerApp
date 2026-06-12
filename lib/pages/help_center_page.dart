import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_widgets.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  static const _accent = Color(0xFF0D9488);

  static const _faqs = [
    (
      'How do I plan a new trip?',
      'From the Home screen, tap the "Plan Your Trip" card. Enter your destination, '
          'travel dates, flight and hotel details, and a budget, then tap "Save Trip '
          'Plan". Your trip will appear under "My Trips" on the Home screen.',
    ),
    (
      'How do I upload and manage travel documents?',
      'Open the Documents tab and tap the add button to upload files such as flight '
          'tickets, passports, visas or hotel confirmations. Tap any document to open '
          'or share it, and swipe to remove documents you no longer need.',
    ),
    (
      'How can I discover places in a new city?',
      'Go to the Map tab and search for any city or area. Wander will show top-rated '
          'attractions, restaurants and cafes nearby so you can plan what to see and '
          'where to eat.',
    ),
    (
      'How do I find and follow other travellers?',
      'In the Wander feed, tap the search icon to look up travellers by name. Open '
          'their profile and tap "Follow" to see their stories and trips in your feed.',
    ),
    (
      'How do I save a story to read later?',
      'Tap the bookmark icon on any story in your feed. You can find every story '
          'you have saved under Profile > Saved Stories.',
    ),
    (
      'Can I switch between light and dark mode?',
      'Yes. Go to Settings > Preferences and toggle Dark Mode. The whole app switches '
          'theme instantly, and your preference is remembered the next time you open Wander.',
    ),
    (
      'How do I update my profile photo or bio?',
      'Open your Profile, then tap the edit icon on your photo to change it, or tap '
          '"Add Bio" to introduce yourself to other travellers.',
    ),
    (
      'How do I log out of my account?',
      'Open Settings and scroll to the bottom of the page, then tap "Logout". '
          'You can always sign back in with the same account afterwards.',
    ),
  ];

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@wanderapp.com',
      query: 'subject=Wander Support Request',
    );
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
      appBar: const AppHeader(title: 'Help Center'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick answers to the most common questions about using Wander.',
            style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.5),
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [
                  for (var i = 0; i < _faqs.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 20, endIndent: 20, color: dividerColor),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      expandedAlignment: Alignment.topLeft,
                      iconColor: _accent,
                      collapsedIconColor: secondaryTextColor,
                      title: Text(
                        _faqs[i].$1,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      children: [
                        Text(
                          _faqs[i].$2,
                          style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.6),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _accent.withAlpha(15), shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded, color: _accent, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Still need help?',
                  style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 6),
                Text(
                  'Our support team is happy to help with anything else you run into.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.5),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Contact Support',
                  icon: Icons.mail_outline_rounded,
                  onPressed: _contactSupport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
