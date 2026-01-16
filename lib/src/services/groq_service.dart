// lib/src/services/groq_service.dart
//  GROQ AI SERVICE — v3 (updated selective functions)
//  - Kept existing functions intact except for targeted updates:
//    • Added runInsightEngineAI(...) to produce Today + Pattern structured JSON
//    • Updated generateHistoryBasedVideo(...) & generateTodayBasedVideo(...) to accept AI URLs but validate them
//    • Kept other functions as-is (no removal)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart' show GROQ_API_KEY;



class CachedResponse {
  final String response;
  final DateTime timestamp;
  CachedResponse({required this.response, required this.timestamp});
}

class GroqAIService {
  static final Map<String, CachedResponse> _cache = {};

  // STRICT allowed models
  static const List<String> _models = [
    'llama-3.3-70b-versatile',
    'llama-3.3-70b-instruct',
  ];

  // Safe API key getter (works for nullable or non-null GROQ_API_KEY)
  static String get _apiKey {
    final fromConst = (GROQ_API_KEY ?? '').trim();
    if (fromConst.isNotEmpty) return fromConst;

    const fromEnv = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    return fromEnv;
  }

  static Uri get _endpoint =>
      Uri.parse('https://api.groq.com/openai/v1/chat/completions');

  // ------------------------------------------------
  // POST
  // ------------------------------------------------
  static Future<http.Response> _post(String model, Map body) async {
    try {
      return await http.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          ...body,
          "model": model,
        }),
      );
    } catch (e) {
      return http.Response(
        jsonEncode({"error": {"message": "Network error: $e"}}),
        503,
      );
    }
  }

  // ------------------------------------------------
  // Fallback across the 2 strict models
  // ------------------------------------------------
  static Future<http.Response> _postFallback(Map body) async {
    if (_apiKey.isEmpty) {
      return http.Response(
        jsonEncode({
          "error": {
            "message":
                "GROQ_API_KEY not set. Add it in constants.dart or via --dart-define."
          }
        }),
        401,
      );
    }

    for (final model in _models) {
      final r = await _post(model, body);

      if (r.statusCode == 200) {
        if (kDebugMode) debugPrint('Groq: $model → 200 OK');
        return r;
      }

      if (r.statusCode == 400) {
        try {
          final msg = jsonDecode(r.body)['error']['message']
              .toString()
              .toLowerCase();
          if (msg.contains('decommission')) {
            continue; // try next model
          }
        } catch (_) {}
      }

      if (r.statusCode == 401) return r; // bad key
      if (r.statusCode >= 500) return r; // server issue

      // other 4xx → just return
      return r;
    }

    return http.Response(
      jsonEncode({"error": {"message": "All Groq models failed"}}),
      500,
    );
  }

  // ------------------------------------------------
  // Parse chat response
  // ------------------------------------------------
  static String _parse(String body) {
    try {
      final data = jsonDecode(body);
      if (data['choices'] != null &&
          data['choices'] is List &&
          data['choices'].isNotEmpty) {
        final c = data['choices'][0];
        final txt = c['message']?['content'] ?? c['text'];
        return txt?.toString() ?? "⚠️ Empty AI response";
      }
    } catch (_) {}
    return "⚠️ Unexpected AI response format";
  }

  // ------------------------------------------------
  // Helper: YouTube URL validator (only allow real youtube links)
  // (still used for other flows if needed)
  // ------------------------------------------------
  static bool _isYoutubeUrl(String? url) {
    if (url == null) return false;
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    return u.startsWith('https://www.youtube.com/watch?') ||
        u.startsWith('http://www.youtube.com/watch?') ||
        u.startsWith('https://youtu.be/') ||
        u.startsWith('http://youtu.be/');
  }

  // Small helper for keyword matching
  static bool _containsAny(String text, List<String> words) {
    final t = text.toLowerCase();
    return words.any((w) => t.contains(w.toLowerCase()));
  }

  // ------------------------------------------------
  // SAFE YOUTUBE SEARCH URL POOLS (20+ links)
  // ------------------------------------------------

  // Stress / anxiety / overthinking
  static const List<String> _videosStress = [
    'https://www.youtube.com/results?search_query=box+breathing+for+anxiety',
    'https://www.youtube.com/results?search_query=5+minute+breathing+exercise+stress',
    'https://www.youtube.com/results?search_query=guided+meditation+for+anxiety',
    'https://www.youtube.com/results?search_query=progressive+muscle+relaxation+stress',
    'https://www.youtube.com/results?search_query=panic+attack+grounding+exercise',
  ];

  // Sleep / tired / insomnia
  static const List<String> _videosSleep = [
    'https://www.youtube.com/results?search_query=deep+sleep+guided+meditation',
    'https://www.youtube.com/results?search_query=10+hour+sleep+music',
    'https://www.youtube.com/results?search_query=relaxing+sleep+stories',
    'https://www.youtube.com/results?search_query=calm+night+meditation',
    'https://www.youtube.com/results?search_query=insomnia+relief+guided+audio',
  ];

  // Money / fees / trading / career
  static const List<String> _videosMoney = [
    'https://www.youtube.com/results?search_query=stock+market+for+beginners',
    'https://www.youtube.com/results?search_query=how+to+start+trading+from+scratch',
    'https://www.youtube.com/results?search_query=how+to+make+money+online+for+students',
    'https://www.youtube.com/results?search_query=budgeting+for+beginners',
    'https://www.youtube.com/results?search_query=personal+finance+basics',
    'https://www.youtube.com/results?search_query=side+hustle+ideas+for+college+students',
    'https://www.youtube.com/results?search_query=options+trading+explained+for+beginners',
  ];

  // Relationships / breakup / love
  static const List<String> _videosRelationship = [
    'https://www.youtube.com/results?search_query=healing+after+breakup',
    'https://www.youtube.com/results?search_query=5+things+to+remember+after+a+breakup',
    'https://www.youtube.com/results?search_query=toxic+relationship+signs+and+healing',
    'https://www.youtube.com/results?search_query=motivational+speech+after+breakup',
    'https://www.youtube.com/results?search_query=feel+good+love+songs+playlist',
    'https://www.youtube.com/results?search_query=bollywood+breakup+songs',
    'https://www.youtube.com/results?search_query=how+to+communicate+better+in+relationships',
  ];

  // Focus / study / productivity / exams
  static const List<String> _videosFocus = [
    'https://www.youtube.com/results?search_query=lofi+study+music',
    'https://www.youtube.com/results?search_query=how+to+focus+while+studying',
    'https://www.youtube.com/results?search_query=deep+work+tutorial',
    'https://www.youtube.com/results?search_query=study+with+me+2+hours',
    'https://www.youtube.com/results?search_query=productivity+tips+for+students',
  ];

  // General calm / gratitude / motivation
  static const List<String> _videosGeneral = [
    'https://www.youtube.com/results?search_query=gratitude+meditation+10+minutes',
    'https://www.youtube.com/results?search_query=motivation+for+hard+days',
    'https://www.youtube.com/results?search_query=morning+positive+affirmations',
    'https://www.youtube.com/results?search_query=relaxing+nature+sounds+4k',
    'https://www.youtube.com/results?search_query=confidence+affirmations',
  ];

  // Pick one safe URL based on diary text
  static String _pickSafeVideoForText(String text) {
    final t = text.toLowerCase();
    List<String> pool;

    if (_containsAny(
        t, ['stress', 'anxiety', 'overthink', 'panic', 'nervous'])) {
      pool = _videosStress;
    } else if (_containsAny(
        t, ['sleep', 'insomnia', 'tired', 'fatigue', 'exhausted', 'night'])) {
      pool = _videosSleep;
    } else if (_containsAny(t,
        ['money', 'fees', 'rent', 'loan', 'broke', 'trading', 'salary'])) {
      pool = _videosMoney;
    } else if (_containsAny(t, [
      'relationship',
      'girlfriend',
      'boyfriend',
      'breakup',
      'love',
      'marriage',
      'partner'
    ])) {
      pool = _videosRelationship;
    } else if (_containsAny(
        t, ['study', 'exam', 'focus', 'deadline', 'work', 'productivity'])) {
      pool = _videosFocus;
    } else {
      pool = _videosGeneral;
    }

    if (pool.isEmpty) {
      return 'https://www.youtube.com';
    }

    final idx = text.hashCode.abs() % pool.length;
    return pool[idx];
  }

  // ------------------------------------------------
  // Calm tips  (keeps old parameter name: contextHint)
  // ------------------------------------------------
  static Future<List<String>> generateCalmTips({
    String contextHint = '',
    String? hint,
  }) async {
    final effectiveHint = (hint ?? contextHint).trim();
    final key = "calm:$effectiveHint";

    if (_cache.containsKey(key)) {
      final c = _cache[key]!;
      if (DateTime.now().difference(c.timestamp).inHours < 4) {
        try {
          final parsed = jsonDecode(c.response);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "Return ONLY a JSON array of 5 calming tips. Each tip < 10 words."
        },
        {"role": "user", "content": "Context: $effectiveHint"}
      ],
      "max_tokens": 200,
      "temperature": 0.0,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) return ["Unable to fetch tips"];

    final txt = _parse(r.body);
    try {
      final parsed = jsonDecode(txt);
      if (parsed is List) {
        _cache[key] = CachedResponse(
          response: jsonEncode(parsed),
          timestamp: DateTime.now(),
        );
        return parsed.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return [txt];
  }

  // ------------------------------------------------
  // Daily quote (keeps old param name: moodHint)
  // ------------------------------------------------
  static Future<String> generateDailyQuote({
    String moodHint = '',
    String? mood,
  }) async {
    final effectiveMood = (mood ?? moodHint).trim();

    final now = DateTime.now();
    final day = "${now.year}-${now.month}-${now.day}";
    final key = "quote:$day";

    if (_cache.containsKey(key)) {
      return _cache[key]!.response;
    }

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "Give ONE short affirmation (< 18 words). No emojis, no date. Return only sentence."
        },
        {
          "role": "user",
          "content":
              "Write today's affirmation for someone feeling: $effectiveMood."
        }
      ],
      "max_tokens": 60,
      "temperature": 0.7,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) return "You are doing your best today.";

    String txt = _parse(r.body).trim();
    if (txt.startsWith('"') && txt.endsWith('"')) {
      txt = txt.substring(1, txt.length - 1).trim();
    }

    _cache[key] = CachedResponse(response: txt, timestamp: DateTime.now());
    return txt;
  }

  // ------------------------------------------------
  // Medication search
  // ------------------------------------------------
  static Future<String> searchMedication(String med) async {
    final key = "med:${med.toLowerCase().trim()}";

    if (_cache.containsKey(key)) {
      return _cache[key]!.response;
    }

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "Explain medication facts simply. End with: ⚠️ Informational only — not medical advice."
        },
        {"role": "user", "content": "Explain about: $med"}
      ],
      "max_tokens": 500,
      "temperature": 0.2,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) return "Unable to fetch medication info.";

    final txt = _parse(r.body);
    _cache[key] = CachedResponse(response: txt, timestamp: DateTime.now());
    return txt;
  }

  // ------------------------------------------------
  // Fetch past journals (used by diary & insights engine)
  // ------------------------------------------------
  static Future<List<String>> fetchPastJournals(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map((d) => (d.data()['content'] ?? '').toString())
          .where((t) => t.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------
  // Journal pattern analysis with history
  // ------------------------------------------------
  static Future<String> analyzeJournalWithHistory(
      String today, List<String> past) async {
    final history = past.isEmpty
        ? "No past entries."
        : past.map((e) => "- $e").join("\n");

    final prompt = """
You are a soft, friendly emotional analysis AI.

Goals:
- Detect patterns: stress, anxiety, mood drops, sleep issues, conflict, money worry.
- Predict near-future possibilities (logical, not psychic).
- Give supportive advice.
- Medium length responses.
- Light emojis ok.
- Max 180 words.
- End with: "⚠️ Informational only — not medical advice."

ENTRY TODAY:
$today

PAST ENTRIES:
$history
""";

    final body = {
      "messages": [
        {"role": "system", "content": "You give warm emotional summaries."},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 300,
      "temperature": 0.5,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) return "Unable to analyze entry.";

    return _parse(r.body);
  }

  // Simple wrapper (used by some screens)
  static Future<String> analyzeJournal(String content) async {
    return analyzeJournalWithHistory(content, []);
  }

  // ------------------------------------------------
  // AI GAME: Mood Quest (gives a playful challenge)
  // ------------------------------------------------
  static Future<String> generateGameQuest(String moodText) async {
    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "You are a playful mental-wellbeing mini-game AI. "
              "Given how the user feels, create ONE short challenge/game "
              "they can do in 1–3 minutes to feel a bit better. "
              "Make it fun, simple, safe and realistic. Max 40 words."
        },
        {
          "role": "user",
          "content": "The player says they feel: $moodText"
        }
      ],
      "max_tokens": 120,
      "temperature": 0.8,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) {
      return "Couldn’t load a quest right now. Try again in a bit.";
    }
    return _parse(r.body);
  }

  // ------------------------------------------------
  // AI GAME SUGGESTIONS for Insight Engine (2 games)
  // ------------------------------------------------
  static Future<Map<String, String>> suggestGamesFromAI({
    required List<String> tags,
    required int stressScore,
    required String diaryText,
  }) async {
    // Allowed game names (NO Calm Tap here)
    const allowedGames = [
      "Mind Tricks",
      "Memory Match",
      "Color Match",
      "Simon",
      "Mini Sudoku",
      "Stress Ball",
      "Meditation Timer",
      "Odd One Out",
      "XOX Game",
      "Breathing Exercise",
    ];

    final tagText = tags.join(", ");
    final prompt = """
You help pick 2 mini-games for mental wellbeing.

You must choose 2 DISTINCT games from this EXACT list (do NOT invent new names):

${allowedGames.map((g) => "- $g").join("\n")}

Rules:
- Use the tags, stressScore (0-100) and diaryText to decide.
- If stressScore is high or tags mention stress/anxiety -> prefer calming games.
- If tags mention productivity/focus -> include something like Mini Sudoku, Mind Tricks, etc.
- Respond as STRICT JSON with keys: primary, secondary, reason.
- primary and secondary must be EXACTLY one of the allowed names.
- reason is a short explanation (< 30 words).

Example (format only):
{"primary": "Mind Tricks", "secondary": "Mini Sudoku", "reason": "You sound mentally tired, so light logic games are good."}
""";

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "You are a JSON-only assistant. Always return VALID JSON, no extra text."
        },
        {
          "role": "user",
          "content":
              "tags: $tagText\nstressScore: $stressScore\ndiaryText: $diaryText"
        },
        {
          "role": "user",
          "content": prompt,
        }
      ],
      "max_tokens": 220,
      "temperature": 0.6,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) {
      // Fallback pair
      return {
        "primary": "Mind Tricks",
        "secondary": "Mini Sudoku",
      };
    }

    final txt = _parse(r.body).trim();

    try {
      final data = jsonDecode(txt);

      String primary = data['primary']?.toString() ?? "";
      String secondary = data['secondary']?.toString() ?? "";

      bool okPrimary = allowedGames.contains(primary);
      bool okSecondary = allowedGames.contains(secondary);

      if (!okPrimary && allowedGames.isNotEmpty) {
        primary = allowedGames.first;
      }
      if ((!okSecondary || secondary == primary) && allowedGames.length >= 2) {
        // pick a different fallback
        secondary = allowedGames.firstWhere((g) => g != primary, orElse: () => allowedGames[0]);
      }

      return {
        "primary": primary,
        "secondary": secondary,
      };
    } catch (_) {
      // Parsing error fallback
      return {
        "primary": "Mind Tricks",
        "secondary": "Mini Sudoku",
      };
    }
  }

  // ------------------------------------------------------------
  // RELAXATION AI — v1 (Hybrid tone, llama-3.3-70b-instruct)
  // ------------------------------------------------------------
  static Future<Map<String, dynamic>> generateRelaxationSet({
    required String patternInsight,
    required List<String> tags,
    String? suggestedRelaxation,
  }) async {
    final tagText = tags.join(", ");

    final prompt = """
You are an emotional-wellbeing assistant. Tone: warm but structured.

Task:
Based on the user's emotional pattern and tags, generate relaxation routines.

Return STRICT JSON with EXACT keys:

{
  "ai_summary": "short 1–2 line summary",
  "exercises": [
    "exercise 1",
    "exercise 2",
    "exercise 3",
    "exercise 4",
    "exercise 5"
  ],
  "grounding_script": "30-second grounding guidance",
  "reset_task": "tiny reset task"
}

Rules:
- No disclaimers.
- Exercises: short, simple, realistic.
- Grounding script should feel spoken.
- Reset task must be < 15 seconds.
- Tone: gentle, clear, and non-medical.
- Use tags: $tagText
- If suggestedRelaxation exists: include the theme: $suggestedRelaxation

Pattern Insight:
$patternInsight
""";

    final body = {
      "messages": [
        {"role": "system", "content": "Reply ONLY with valid JSON."},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 500,
      "temperature": 0.7,
    };

    final response = await _post("llama-3.3-70b-instruct", body);
    final txt = _parse(response.body);

    try {
      final data = jsonDecode(txt);
      return {
        "ai_summary": data["ai_summary"] ?? "",
        "exercises": List<String>.from(data["exercises"] ?? []),
        "grounding_script": data["grounding_script"] ?? "",
        "reset_task": data["reset_task"] ?? "",
      };
    } catch (e) {
      // Fallback in case JSON fails
      return {
        "ai_summary": "Take a slow breath. Let's reset your mind.",
        "exercises": [
          "Close eyes and inhale for four seconds.",
          "Relax your jaw and unclench your shoulders.",
          "Look around and name three calm colours.",
          "Stretch your neck gently side to side.",
          "Write one sentence about how you feel."
        ],
        "grounding_script":
            "Focus on the floor beneath you. Notice your breath. Let your thoughts settle like dust.",
        "reset_task": "Touch your fingertips together slowly for 5 seconds."
      };
    }
  }

  // ------------------------------------------------
  // HEALTH STATS ANALYSIS
  // ------------------------------------------------
  static Future<String> analyzeHealthTimeline({
    required List<Map<String, dynamic>> illnesses,
    required List<Map<String, dynamic>> months,
  }) async {
    final illnessLines = illnesses.isEmpty
        ? 'No completed illnesses with recovery days.'
        : illnesses.map((m) {
            final name = m['name']?.toString() ?? 'Illness';
            final days = m['days'] ?? 0;
            final start = m['start']?.toString() ?? '';
            final end = m['end']?.toString() ?? '';
            return '- $name: $days day${days == 1 ? '' : 's'} ($start → $end)';
          }).join('\n');

    final monthLines = months.isEmpty
        ? 'No month-level sick-day summary yet.'
        : months.map((m) {
            final label = m['month']?.toString() ?? '';
            final days = m['days'] ?? 0;
            return '- $label: $days sick day${days == 1 ? '' : 's'}';
          }).join('\n');

    final prompt = """
You are a friendly health tracking assistant.

You see a person's illness history and how many days they were unwell.

Goals:
- Summarise patterns in how long they usually stay sick.
- Point out if there are months that look heavier.
- Give 3–6 simple bullet points.
- Then 1 short paragraph of encouragement and general lifestyle tips (non-medical).
- DO NOT guess diagnoses, DO NOT mention specific diseases or treatments.
- Never tell them they are fine or not fine medically.
- Always stay general and supportive.
- Max 220 words.
- End with this exact line:
"⚠️ Informational only — not medical advice."

DATA – ILLNESSES:
$illnessLines

DATA – SICK DAYS PER MONTH:
$monthLines
""";

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              "You analyse health tracking data in a gentle, non-medical way."
        },
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 350,
      "temperature": 0.5,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) {
      return "Unable to generate a health summary right now. Please try again later.";
    }
    return _parse(r.body);
  }

  // ============================================================================
  // NEW AI FUNCTIONS — Deep Analysis (updated selectively)
  // ============================================================================
  //
  // NOTE: The following functions are the ones you asked to update.
  // All other functions in this file are preserved exactly (no removals).

  // --------------------------------------------------------
  // NEW: MASTER INSIGHT ENGINE — returns Today + Pattern JSON structure
  // --------------------------------------------------------
  static Future<Map<String, dynamic>> runInsightEngineAI({
    required String diaryText,
    required String moodText,
    required List<String> tags,
    required int stressScore,
    required bool includeToday,
  }) async {
    final tagLine = tags.join(', ');
    final prompt = """
You are the Insight Engine for a wellbeing app. Read diaryText and moodText and tags, then produce a STRICT JSON output tailored to the user.

Return STRICT JSON with these keys exactly:

{
 "dailyInsight": "short paragraph (<= 100 words)",
 "patternInsight": "short paragraph (<= 100 words)",
 "futurePrediction": "short paragraph (<= 60 words)",
 "stressScore": NUMBER,

 "tags": ["tag1","tag2"],

 "today": {
    "game_primary": "in-app game name or short instruction",
    "game_secondary": "external micro-game suggestion (web or short description)",
    "relax_primary": "in-app relaxation method name/short",
    "relax_secondary": "external relaxation video/article title + source",
    "video_primary_title": "YouTube video title",
    "video_primary_url": "https://www.youtube.com/watch?v=... (optional)",
    "video_secondary_title": "YouTube fallback title",
    "video_secondary_url": "https://www.youtube.com/watch?v=... (optional)"
 },

 "pattern": {
    "game_primary": "",
    "game_secondary": "",
    "relax_primary": "",
    "relax_secondary": "",
    "video_primary_title": "",
    "video_primary_url": "",
    "video_secondary_title": "",
    "video_secondary_url": ""
 }
}

Rules:
- If includeToday is false, still return "today" object but allow empty strings.
- For video URLs: prefer returning a valid YouTube watch URL. If not available, leave url empty and the client will use safe search fallback.
- Keep primary and secondary distinct.
- Use the tags and stressScore and diaryText to tailor suggestions per user and per date-range.
- Return JSON ONLY, no extra text.
""";

    final body = {
      "messages": [
        {"role": "system", "content": "Return ONLY valid JSON."},
        {
          "role": "user",
          "content":
              "diaryText: $diaryText\nmoodText: $moodText\ntags: $tagLine\nstressScore: $stressScore\nincludeToday: $includeToday"
        },
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 1200,
      "temperature": 0.85,
    };

    final r = await _postFallback(body);
    if (r.statusCode != 200) {
      // fallback minimal structure
      return {
        "dailyInsight": "",
        "patternInsight": "",
        "futurePrediction": "",
        "stressScore": stressScore,
        "tags": tags,
        "today": {
          "game_primary": "",
          "game_secondary": "",
          "relax_primary": "",
          "relax_secondary": "",
          "video_primary_title": "",
          "video_primary_url": "",
          "video_secondary_title": "",
          "video_secondary_url": ""
        },
        "pattern": {
          "game_primary": "",
          "game_secondary": "",
          "relax_primary": "",
          "relax_secondary": "",
          "video_primary_title": "",
          "video_primary_url": "",
          "video_secondary_title": "",
          "video_secondary_url": ""
        }
      };
    }

    final txt = _parse(r.body).trim();
    try {
      final jsonResp = jsonDecode(txt);
      // Ensure structure keys exist
      jsonResp['dailyInsight'] ??= '';
      jsonResp['patternInsight'] ??= '';
      jsonResp['futurePrediction'] ??= '';
      jsonResp['stressScore'] ??= stressScore;
      jsonResp['tags'] ??= tags;
      jsonResp['today'] ??= {};
      jsonResp['pattern'] ??= {};
      return Map<String, dynamic>.from(jsonResp);
    } catch (_) {
      // parsing error fallback (minimal)
      return {
        "dailyInsight": "",
        "patternInsight": "",
        "futurePrediction": "",
        "stressScore": stressScore,
        "tags": tags,
        "today": {
          "game_primary": "",
          "game_secondary": "",
          "relax_primary": "",
          "relax_secondary": "",
          "video_primary_title": "",
          "video_primary_url": "",
          "video_secondary_title": "",
          "video_secondary_url": ""
        },
        "pattern": {
          "game_primary": "",
          "game_secondary": "",
          "relax_primary": "",
          "relax_secondary": "",
          "video_primary_title": "",
          "video_primary_url": "",
          "video_secondary_title": "",
          "video_secondary_url": ""
        }
      };
    }
  }

  // --------------------------------------------------------
  // 1) HISTORY-BASED VIDEO SUGGESTION (UPDATED: respect AI url if valid, else fallback)
  // --------------------------------------------------------
  static Future<Map<String, String>> generateHistoryBasedVideo(
      List<String> pastEntries) async {
    final history = pastEntries.isEmpty
        ? "No past entries."
        : pastEntries.map((e) => "- $e").join("\n");

    final prompt = """
Read these past diary entries, detect emotional themes,
and recommend ONE YouTube video. Return JSON with keys: title, url, reason.
If you do not know a valid YouTube watch URL, return url as empty string.
""";

    final body = {
      "messages": [
        {"role": "system", "content": "Return ONLY valid JSON."},
        {"role": "user", "content": history},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 220,
      "temperature": 0.7,
    };

    final r = await _postFallback(body);
    final txt = _parse(r.body);

    try {
      final data = jsonDecode(txt);
      String title = data["title"]?.toString().trim() ?? "";
      String url = data["url"]?.toString().trim() ?? "";
      String reason = data["reason"]?.toString().trim() ?? "";

      // Validate URL; if not valid, fallback to safe search pool derived from history
      if (!_isYoutubeUrl(url)) {
        url = _pickSafeVideoForText(history);
      }

      if (title.isEmpty) title = "Calming Reset";

      return {
        "title": title,
        "url": url,
        "reason": reason,
      };
    } catch (_) {
      return {
        "title": "Calming Reset",
        "url": _pickSafeVideoForText(history),
        "reason": "",
      };
    }
  }

  // --------------------------------------------------------
  // 2) TODAY-BASED VIDEO SUGGESTION (UPDATED: accept AI url if valid, else fallback)
  // --------------------------------------------------------
  static Future<Map<String, String>> generateTodayBasedVideo(
      String todayEntry) async {
    final prompt = """
Read today's diary entry and suggest ONE relevant YouTube video.
Return JSON: { "title": "...", "url": "https://www.youtube.com/watch?v=...", "reason": "..." }
If URL is unknown, return url as empty string.
""";

    final body = {
      "messages": [
        {"role": "system", "content": "Return ONLY JSON."},
        {"role": "user", "content": todayEntry},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 200,
      "temperature": 0.7,
    };

    final r = await _postFallback(body);
    final txt = _parse(r.body);

    try {
      final data = jsonDecode(txt);
      String title = data["title"]?.toString().trim() ?? "";
      String url = data["url"]?.toString().trim() ?? "";
      String reason = data["reason"]?.toString().trim() ?? "";

      if (!_isYoutubeUrl(url)) {
        // fallback to safe search selection based on today's text
        url = _pickSafeVideoForText(todayEntry);
      }

      if (title.isEmpty) title = "Mind Reset";

      return {
        "title": title,
        "url": url,
        "reason": reason,
      };
    } catch (_) {
      return {
        "title": "Mind Reset",
        "url": _pickSafeVideoForText(todayEntry),
        "reason": "",
      };
    }
  }

  // --------------------------------------------------------
  // 3) TODAY-BASED RELAXATION SUGGESTION (kept, minor safety)
  // --------------------------------------------------------
  static Future<String> generateTodayRelaxation(String entry) async {
    final prompt = """
You are a relaxation coach.

Read today's diary entry and return ONLY ONE relaxation technique.

Rules:
- 1–2 short sentences.
- Max 40 words.
- No headings, no bullet points, no analysis.
- Speak directly to the user (e.g. "Try this...").
""";

    final body = {
      "messages": [
        {
          "role": "system",
          "content": "Return ONE short relaxation instruction."
        },
        {"role": "user", "content": entry},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 120,
      "temperature": 0.7,
    };

    final r = await _postFallback(body);
    String txt = _parse(r.body).trim();

    // Hard cap so it matches the small tile heading
    if (txt.length > 220) {
      txt = txt.substring(0, 220).trim();
      if (!txt.endsWith('.')) txt = "$txt...";
    }

    return txt;
  }

  // --------------------------------------------------------
  // 4) TODAY-BASED MICRO-GAME SUGGESTION (kept)
  // --------------------------------------------------------
  static Future<String> generateTodayGame(String entry) async {
    final prompt = """
You are a playful mental wellness coach.

Read today's diary entry and suggest ONE micro-game the user can do in under 2 minutes.

Rules:
- Max 35 words.
- No headings, no bullet list, no long analysis.
- Make it specific and easy to start immediately.
""";

    final body = {
      "messages": [
        {"role": "system", "content": "Return ONE short micro-game idea."},
        {"role": "user", "content": entry},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 100,
      "temperature": 0.8,
    };

    final r = await _postFallback(body);
    String txt = _parse(r.body).trim();

    if (txt.length > 200) {
      txt = txt.substring(0, 200).trim();
      if (!txt.endsWith('.')) txt = "$txt...";
    }

    return txt;
  }
}
