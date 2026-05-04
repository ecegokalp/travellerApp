import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

class GeminiService {
  static const String _apiKey = 'AIzaSyCJUw4lfoUQwZjl0Y74_raDTww1OxzLM6A';
  
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  Future<String?> generateBlogContent(String country, String city) async {
    try {
      debugPrint('Gemini: Generating blog for $city, $country...');
      final content = [
        Content.text('Write a short, engaging travel blog post about $city, $country. '
            'Mention one famous landmark and one local food. '
            'Keep it under 120 words. Friendly and adventurous tone.'),
      ];

      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('!!! GEMINI BLOG ERROR: $e');
      return 'AI generation failed. Please try again later. Error: $e';
    }
  }

  Future<Map<String, dynamic>?> processDocument(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final extension = p.extension(file.path).toLowerCase();
      String mimeType = (extension == '.pdf') ? 'application/pdf' : 'image/jpeg';

      final content = [
        Content.multi([
          DataPart(mimeType, bytes),
          TextPart('Extract trip details from this document to JSON format.'),
        ]),
      ];

      final response = await _model.generateContent(content);
      return _parseJson(response.text);
    } catch (e) {
      debugPrint('Gemini Document Error: $e');
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
