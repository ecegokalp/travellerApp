import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import 'planner_page.dart';
import 'blog_page.dart';

class TripDetailsPage extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String? tripId;

  const TripDetailsPage({super.key, required this.tripData, this.tripId});

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final _currencyService = CurrencyService();
  Map<String, double>? _rates;

  static const _coral = Color(0xFFFF6B6B);
  static const _orange = Color(0xFFFF8E53);

  @override
  void initState() {
    super.initState();
    _currencyService.getRatesToTRY().then((r) {
      if (mounted) setState(() => _rates = r);
    });
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && widget.tripId != null) {
      final uid = AuthService().currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('trips').doc(widget.tripId).delete();
        if (mounted) Navigator.pop(context);
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _priceText(double amount, String currency) {
    if (_rates == null || currency == 'TRY') return '${amount.toStringAsFixed(0)} ₺';
    return _currencyService.formatWithConversion(amount, currency, _rates!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardColor = Theme.of(context).cardColor;

    final d = widget.tripData;
    final city = d['city'] ?? 'Unknown';
    final country = d['country'] ?? '';
    final hotelName = d['hotelName'] ?? '';
    final hotelPrice = (d['hotelPrice'] ?? 0).toDouble();
    final hotelCurrency = d['hotelCurrency'] ?? 'TRY';
    final totalTRY = (d['totalBudgetTRY'] ?? d['totalBudget'] ?? 0).toDouble();
    final budgetLimitRaw = (d['budgetLimit'] ?? 0).toDouble();
    final budgetLimitCurrency = d['budgetLimitCurrency'] ?? 'TRY';
    final budgetLimit = _rates != null ? _currencyService.convertToTRY(budgetLimitRaw, budgetLimitCurrency, _rates!) : budgetLimitRaw;
    final List<dynamic> places = d['places'] ?? [];
    final List<dynamic> checklist = d['checklist'] ?? [];
    final budgetCats = d['budgetCategories'] as Map<String, dynamic>?;
    final hasStart = d['startDate'] != null;
    final hasEnd = d['endDate'] != null;

    final budgetRatio = budgetLimit > 0 ? (totalTRY / budgetLimit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$city Trip'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 22, color: _coral),
            onPressed: () {
              final city = widget.tripData['city'];
              final country = widget.tripData['country'];
              showCreateStorySheet(context, initialCity: city, initialCountry: country);
            },
          ),
          if (widget.tripId != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 22),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlannerPage(existingTrip: d, tripId: widget.tripId))),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Colors.redAccent),
              onPressed: _deleteTrip,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_coral, _orange]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text('$city, $country', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Budget: ${totalTRY.toStringAsFixed(0)} ₺', style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600)),
                if (hasStart || hasEnd) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(d['startDate'])}${hasEnd ? ' - ${_formatDate(d['endDate'])}' : ''}',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // ── Budget Overview ──
            if (budgetLimit > 0) ...[
              _section('Budget Overview', Icons.account_balance_wallet_rounded, textColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${totalTRY.toStringAsFixed(0)} ₺', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                    Text('/ ${budgetLimit.toStringAsFixed(0)} ₺', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: budgetRatio,
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                      color: budgetRatio > 0.9 ? Colors.red : budgetRatio > 0.7 ? Colors.orange : _coral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(budgetLimit - totalTRY).toStringAsFixed(0)} ₺ remaining',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: budgetRatio > 0.9 ? Colors.red : _coral),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // ── Budget Categories ──
            if (budgetCats != null && budgetCats.isNotEmpty) ...[
              _section('Expenses', Icons.receipt_long_rounded, textColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
                child: Column(children: [
                  if (hotelName.isNotEmpty) _expenseRow('Hotel', hotelPrice, hotelCurrency, Icons.hotel_rounded, textColor),
                  ...budgetCats.entries.where((e) => (e.value['amount'] ?? 0) > 0).map((e) {
                    final icon = switch (e.key) {
                      'Flight' => Icons.flight_rounded,
                      'Food' => Icons.restaurant_rounded,
                      'Transport' => Icons.directions_bus_rounded,
                      _ => Icons.more_horiz_rounded,
                    };
                    return _expenseRow(e.key, (e.value['amount'] as num).toDouble(), e.value['currency'] ?? 'TRY', icon, textColor);
                  }),
                  if (places.isNotEmpty)
                    ...places.map((p) => _expenseRow(p['name'] ?? '', ((p['price'] ?? 0) as num).toDouble(), p['currency'] ?? 'TRY', Icons.place_rounded, textColor)),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // ── Hotel (if no budget categories) ──
            if (budgetCats == null && hotelName.isNotEmpty) ...[
              _section('Accommodation', Icons.hotel_rounded, textColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(hotelName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text(_priceText(hotelPrice, hotelCurrency), style: GoogleFonts.inter(color: _coral, fontWeight: FontWeight.w600)),
                  trailing: d['hotelDocumentUrl'] != null
                      ? IconButton(icon: const Icon(Icons.description, color: _coral), onPressed: () => _openFile(d['hotelDocumentUrl']))
                      : null,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Places (if no budget categories) ──
            if (budgetCats == null && places.isNotEmpty) ...[
              _section('Places to Visit', Icons.map_rounded, textColor),
              const SizedBox(height: 12),
              ...places.map((p) {
                final place = p as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(place['name'] ?? '', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text(_priceText(((place['price'] ?? 0) as num).toDouble(), place['currency'] ?? 'TRY')),
                    trailing: place['documentUrl'] != null
                        ? IconButton(icon: const Icon(Icons.attach_file, color: _coral, size: 20), onPressed: () => _openFile(place['documentUrl']))
                        : null,
                  ),
                );
              }),
            ],

            // ── Checklist ──
            if (checklist.isNotEmpty) ...[
              const SizedBox(height: 24),
              _section('Checklist', Icons.checklist_rounded, textColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
                child: Column(
                  children: checklist.map((item) {
                    final done = item['done'] ?? false;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            done ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: done ? const Color(0xFF2ECC71) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['text'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: done ? Colors.grey : textColor,
                                decoration: done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _expenseRow(String label, double amount, String currency, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: _coral),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: textColor))),
        Text(_priceText(amount, currency), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      ]),
    );
  }

  Widget _section(String title, IconData icon, Color textColor) {
    return Row(children: [
      Icon(icon, color: _coral, size: 20),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
    ]);
  }
}
