import 'dart:convert';
//import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CachedResponse {
  final String response;
  final DateTime timestamp;
  CachedResponse({required this.response, required this.timestamp});
}

class GroqAIService {
  static final String GROQ_API_KEY =
      const String.fromEnvironment("GROQ_API_KEY");
  static const String GROQ_API_ENDPOINT =
      "https://api.groq.com/openai/v1/chat/completions";

  static final Map<String, CachedResponse> _cache = {};

  /// MODELS THAT WORK (confirmed)
  static const List<String> workingModels = [
    "llama-3.3-70b-versatile",
    "llama-3.2-11b-text-preview",     // fallback
    "llama-3.1-8b-instant",           // fallback
  ];

  // ----------------------------------------------------------------------
  // 🔥 UNIVERSAL REQUEST HANDLER (with logs + fallback + caching)
  // ----------------------------------------------------------------------
  static Future<String> _requestWithFallback({
    required List<String> models,
    required List<Map<String, String>> messages,
    int maxTokens = 800,
    double temperature = 0.3,
  }) async {
    final cacheKey =
        messages.isNotEmpty ? messages.last['content']?.toLowerCase().trim() ?? '' : '';

    if (cacheKey.isNotEmpty && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp).inHours < 12) {
        print('[GroqAI] CACHE HIT: $cacheKey');
        return cached.response;
      }
    }

    for (final model in models) {
      try {
        final body = {
          "model": model,
          "messages": messages,
          "max_tokens": maxTokens,
          "temperature": temperature,
        };

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        print("🔥 GROQ REQUEST → model=$model");
        print("URL: $GROQ_API_ENDPOINT");
        print("BODY: ${jsonEncode(body)}");
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        final response = await http.post(
          Uri.parse(GROQ_API_ENDPOINT),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $GROQ_API_KEY",
          },
          body: jsonEncode(body),
        );

        print("📥 RESPONSE (status ${response.statusCode})");
        print(response.body);
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final result = decoded["choices"][0]["message"]["content"];

          if (cacheKey.isNotEmpty) {
            _cache[cacheKey] =
                CachedResponse(response: result, timestamp: DateTime.now());
          }

          return result;
        }

        // MODEL DECOMMISSION CHECK
        if (response.statusCode == 400 &&
            response.body.toLowerCase().contains("decommission")) {
          print("⚠️ Model $model is decommissioned. Trying next model...");
          continue;
        }

        return "⚠️ AI Error: ${response.body}";

      } catch (e, st) {
        print("❌ Groq Exception on model=$model → $e\n$st");
        continue;
      }
    }

    return "⚠️ All models failed. Try again later.";
  }

  // ----------------------------------------------------------------------
  // 🔍 MEDICINE SEARCH FEATURE
  // ----------------------------------------------------------------------
  static Future<String> searchMedication(String name) async {
    if (name.trim().isEmpty) return "Enter a medicine name.";

    return await _requestWithFallback(
      models: workingModels,
      maxTokens: 500,
      temperature: 0.2,
      messages: [
        {
          "role": "system",
          "content": "You are a medical information assistant. Provide factual, simple explanations. Always add: '⚠️ Not medical advice.'"
        },
        {
          "role": "user",
          "content":
              "Give complete medicine info for: $name. Include uses, dosage, precautions, interactions, and warnings."
        }
      ],
    );
  }

  // ----------------------------------------------------------------------
  // 📝 JOURNAL ANALYSIS FEATURE
  // ----------------------------------------------------------------------
  static Future<String> analyzeJournalEntry(String text) async {
    if (text.trim().isEmpty) return "Write something to analyze.";

    return await _requestWithFallback(
      models: workingModels,
      maxTokens: 500,
      temperature: 0.2,
      messages: [
        {
          "role": "system",
          "content":
              "You are an emotional wellness assistant. Identify emotion, give supportive advice, and keep it extremely safe and non-medical."
        },
        {
          "role": "user",
          "content": "Analyze this journal entry: $text"
        }
      ],
    );
  }
}


//flutter build apk --release --split-per-abi
//✓ Built build/app/outputs/flutter-apk/app-release.apk (64.5MB)