import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const supportedCurrencies = ['TRY', 'EUR', 'USD', 'GBP'];

  Map<String, double>? _cachedRates;
  DateTime? _cacheTime;

  static String symbol(String code) {
    switch (code) {
      case 'EUR': return '€';
      case 'USD': return '\$';
      case 'GBP': return '£';
      default: return '₺';
    }
  }

  /// Fetches exchange rates: how much 1 unit of each currency is in TRY
  Future<Map<String, double>> getRatesToTRY() async {
    // Return cache if less than 1 hour old
    if (_cachedRates != null && _cacheTime != null && DateTime.now().difference(_cacheTime!).inMinutes < 60) {
      return _cachedRates!;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.frankfurter.dev/v1/latest?from=EUR&to=TRY,USD,GBP'),
        headers: {'User-Agent': 'WanderApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        final eurToTry = (rates['TRY'] as num).toDouble();
        final eurToUsd = (rates['USD'] as num).toDouble();
        final eurToGbp = (rates['GBP'] as num).toDouble();

        _cachedRates = {
          'TRY': 1.0,
          'EUR': eurToTry,
          'USD': eurToTry / eurToUsd,
          'GBP': eurToTry / eurToGbp,
        };
        _cacheTime = DateTime.now();
        return _cachedRates!;
      }
    } catch (_) {}

    // Fallback rates if API fails
    return {'TRY': 1.0, 'EUR': 53.0, 'USD': 46.0, 'GBP': 62.0};
  }

  double convertToTRY(double amount, String fromCurrency, Map<String, double> rates) {
    final rate = rates[fromCurrency] ?? 1.0;
    return amount * rate;
  }

  String formatWithConversion(double amount, String currency, Map<String, double> rates) {
    final sym = symbol(currency);
    if (currency == 'TRY') return '${amount.toStringAsFixed(0)} ₺';

    final tryAmount = convertToTRY(amount, currency, rates);
    return '$sym${amount.toStringAsFixed(0)} (~${tryAmount.toStringAsFixed(0)} ₺)';
  }
}
