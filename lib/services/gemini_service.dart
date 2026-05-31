import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

class GeminiService {
  static String _apiKey = '';
  GenerativeModel? _model;

  static final GeminiService _instance = GeminiService._();
  factory GeminiService() => _instance;
  GeminiService._();

  Future<void> _ensureInitialized() async {
    if (_model != null) return;

    // Try dart-define first, then env.json asset
    _apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (_apiKey.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('env.json');
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _apiKey = map['GEMINI_API_KEY'] ?? '';
      } catch (_) {}
    }

    if (_apiKey.isEmpty) {
      debugPrint('WARNING: GEMINI_API_KEY not found');
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  static String _mimeTypeFromExtension(String ext) {
    switch (ext) {
      case '.pdf': return 'application/pdf';
      case '.png': return 'image/png';
      case '.gif': return 'image/gif';
      case '.webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }

  Future<String?> generateBlogContent(String country, String city) async {
    try {
      await _ensureInitialized();
      if (_model == null) return null;

      debugPrint('Gemini: Generating blog for $city, $country...');
      final content = [
        Content.text('Write a short, engaging travel blog post about $city, $country. '
            'Mention one famous landmark and one local food. '
            'Keep it under 120 words. Friendly and adventurous tone.'),
      ];

      final response = await _model!.generateContent(content);
      final text = response.text;
      if (text == null || text.trim().isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('!!! GEMINI BLOG ERROR: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> processDocument(File file) async {
    try {
      await _ensureInitialized();
      if (_model == null) return null;

      final bytes = await file.readAsBytes();
      final extension = p.extension(file.path).toLowerCase();
      final mimeType = _mimeTypeFromExtension(extension);

      final content = [
        Content.multi([
          DataPart(mimeType, bytes),
          TextPart(
            'Extract trip details from this document and return ONLY a JSON object with these fields: '
            '"name", "type" (one of: flight, hotel, transport, ticket), "price", "currency", "city", "country", "startDate" (YYYY-MM-DD), "endDate" (YYYY-MM-DD). '
            'If a field is not found, omit it.',
          ),
        ]),
      ];

      final response = await _model!.generateContent(content);
      return _parseJson(response.text);
    } catch (e) {
      debugPrint('Gemini Document Error: $e');
      return null;
    }
  }

  Future<List<String>?> generateChecklist(String country, String city) async {
    try {
      await _ensureInitialized();
      if (_model == null) return null;

      final response = await _model!.generateContent([
        Content.text(
          'I am traveling to $city, $country. '
          'Give me a travel checklist as a JSON array of strings. '
          'Include country-specific items like visa requirements, currency, adaptor type, '
          'health precautions, local customs, and general packing essentials. '
          'Return ONLY a JSON array, no explanation. Example: ["Item 1","Item 2"]. '
          'Keep it 10-15 items max, in English.',
        ),
      ]);

      final text = response.text;
      if (text == null) return null;

      String cleaned = text.trim();
      if (cleaned.contains('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'```json|```'), '').trim();
      }
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(cleaned);
      if (match != null) {
        final list = jsonDecode(match.group(0)!) as List;
        return list.map((e) => e.toString()).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Gemini Checklist Error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseJson(String? text) {
    if (text == null) return null;
    try {
      String cleaned = text.trim();
      if (cleaned.contains('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'```json|```'), '').trim();
      }
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
