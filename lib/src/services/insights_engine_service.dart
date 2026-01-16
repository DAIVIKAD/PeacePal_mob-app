// lib/src/services/insights_engine_service.dart
// ==========================================================
//   INSIGHTS ENGINE v3.1 — Updated structured output + daily rotation
//   • Returns structured 'today' and 'pattern' maps with primary+secondary
//   • Primary = in-app suggestion when possible
//   • Secondary = external suggestion (YouTube search / article / task / external game name)
//   • Daily rotation uses (userId + date) to pick varied secondary suggestions
// ==========================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'groq_service.dart';

class InsightsEngine {
  InsightsEngine._();

  // ==========================================================
  // MAIN ANALYSIS ENTRYPOINT
  // ==========================================================
  static Future<Map<String, dynamic>> analyzeEntry(
      String userId, String content) async {
    final tags = _detectTags(content);
    final stressScore = _estimateStressScore(content);
    final history = await _fetchPastDiaryTexts(userId);

    // DAILY INSIGHT
    String dailyInsight;
    try {
      dailyInsight = await GroqAIService.analyzeJournal(content);
    } catch (_) {
      dailyInsight = "AI can't analyse right now.";
    }

    // PATTERN INSIGHT
    String patternInsight;
    try {
      patternInsight =
          await GroqAIService.analyzeJournalWithHistory(content, history);
    } catch (_) {
      patternInsight = "Pattern analysis unavailable.";
    }

    // OLD-STYLE suggestions (kept for compatibility)
    final suggestions =
        await _buildAISuggestions(tags, stressScore, content.toLowerCase());

    // AI-driven video / relaxation / game (today + history)
    Map<String, String> todayVideo = {};
    Map<String, String> historyVideo = {};
    String todayRelaxation = "";
    String todayGame = "";

    try {
      todayVideo = await GroqAIService.generateTodayBasedVideo(content);
    } catch (_) {}

    try {
      historyVideo = await GroqAIService.generateHistoryBasedVideo(history);
    } catch (_) {}

    try {
      todayRelaxation = await GroqAIService.generateTodayRelaxation(content);
    } catch (_) {}

    try {
      todayGame = await GroqAIService.generateTodayGame(content);
    } catch (_) {}

    // B-TYPE EXTRA SUGGESTIONS (Mixed External)
    final bYoutube = _generateYouTubeSuggestion(tags);
    final bArticle = _generateArticleSuggestion(tags);
    final bTask = _generateTaskSuggestion(tags);
    final bSecondGame = _generateSecondaryGame(tags);
    final bSecondRelax = _generateSecondaryRelaxation(tags);

    // DAILY ROTATION SEED (varies by user + day)
    final now = DateTime.now();
    final seed = (userId.hashCode.abs() + now.year + now.month + now.day);
    final rand = Random(seed);

    // --------------------
    // BUILD TODAY STRUCTURED SUGGESTIONS
    // --------------------
    // Game primary: prefer in-app micro-game suggestion from todayGame (short text)
    String today_game_primary = todayGame.trim().isNotEmpty ? todayGame.trim() : (suggestions['suggestedGamePrimary'] ?? "Mind Tricks");
    // Game secondary: external micro-game name (from bSecondGame) or a rotated allowedGames fallback
    String today_game_secondary = bSecondGame['name'] ?? _rotateListElement(_fallbackGameList(), rand.nextInt(100));

    // Relaxation primary: prefer today's short relaxation (in-app)
    String today_relax_primary = todayRelaxation.trim().isNotEmpty ? todayRelaxation.trim() : (suggestions['suggestedRelaxation'] ?? "Breathing exercise");
    // Relaxation secondary: external short technique from bSecondRelax
    String today_relax_secondary = bSecondRelax['name'] ?? _rotateListElement(_fallbackRelaxList(), rand.nextInt(100));

    // Video primary: prefer today's AI-picked video (title + safe url)
    String today_video_primary_title = (todayVideo['title'] ?? '').toString().trim();
    String today_video_primary_url = (todayVideo['url'] ?? '').toString().trim();
    if (today_video_primary_url.isEmpty) {
      // fall back to suggestions or historyVideo or safe pick
      today_video_primary_url = (suggestions['suggestedVideo'] ?? '').toString();
      today_video_primary_title = (suggestions['suggestedVideoTitle'] ?? '').toString();
      if (today_video_primary_url.isEmpty && historyVideo['url'] != null) {
        today_video_primary_url = historyVideo['url'] ?? '';
        today_video_primary_title = historyVideo['title'] ?? '';
      }
    }

    // Video secondary: external youtube search (bYoutube) or rotated general search term
    String today_video_secondary_title = (bYoutube['title'] ?? '').toString();
    String today_video_secondary_url = (bYoutube['url'] ?? '').toString();
    if (today_video_secondary_url.isEmpty) {
      final fallbackQuery = today_video_primary_title.isNotEmpty
          ? today_video_primary_title
          : (tags.isNotEmpty ? tags.join(' ') : 'calming guided meditation');
      today_video_secondary_url =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(fallbackQuery)}';
      today_video_secondary_title = fallbackQuery;
    }

    // --------------------
    // BUILD PATTERN STRUCTURED SUGGESTIONS (overall)
    // --------------------
    // Pattern game: use suggestions primary/secondary from _buildAISuggestions if present
    String pattern_game_primary = (suggestions['suggestedGamePrimary'] ?? '').toString();
    String pattern_game_secondary = (suggestions['suggestedGameSecondary'] ?? '').toString();
    if (pattern_game_primary.isEmpty) pattern_game_primary = _rotateListElement(_fallbackGameList(), rand.nextInt(100));
    if (pattern_game_secondary.isEmpty) pattern_game_secondary = bSecondGame['name'] ?? _rotateListElement(_fallbackGameList(), rand.nextInt(100) + 1);

    // Pattern relaxation: primary from suggestions, secondary from bSecondRelax
    String pattern_relax_primary = (suggestions['suggestedRelaxation'] ?? '').toString();
    if (pattern_relax_primary.isEmpty) {
      // choose by tags
      if (tags.contains('stress') || tags.contains('anxiety')) {
        pattern_relax_primary = "Box-breathing (4-4-4)";
      } else if (tags.contains('sleep issues')) {
        pattern_relax_primary = "Body-scan before bed";
      } else {
        pattern_relax_primary = "2-minute grounding";
      }
    }
    String pattern_relax_secondary = bSecondRelax['name'] ?? _rotateListElement(_fallbackRelaxList(), rand.nextInt(100) + 1);

    // Pattern video: primary use suggestions['suggestedVideo'] or historyVideo, secondary use bYoutube
    String pattern_video_primary_url = (suggestions['suggestedVideo'] ?? '').toString();
    String pattern_video_primary_title = (suggestions['suggestedVideoTitle'] ?? '').toString();

    if (pattern_video_primary_url.isEmpty) {
      if (historyVideo['url'] != null && historyVideo['url']!.isNotEmpty) {
        pattern_video_primary_url = historyVideo['url']!;
        pattern_video_primary_title = historyVideo['title'] ?? '';
      } else {
        // fallback pick from tag-based pools (use GroqAIService._pickSafeVideoForText equivalent via public API not accessible here)
        final tagBased = _generateYouTubeSuggestion(tags);
        pattern_video_primary_url = tagBased['url'] ?? '';
        pattern_video_primary_title = tagBased['title'] ?? '';
      }
    }

    String pattern_video_secondary_url = (bYoutube['url'] ?? '').toString();
    String pattern_video_secondary_title = (bYoutube['title'] ?? '').toString();
    if (pattern_video_secondary_url.isEmpty) {
      final fallbackQuery = pattern_video_primary_title.isNotEmpty
          ? pattern_video_primary_title
          : (tags.isNotEmpty ? tags.join(' ') : 'calming guided meditation');
      pattern_video_secondary_url =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(fallbackQuery)}';
      pattern_video_secondary_title = fallbackQuery;
    }

    // ==========================================================
    // SAVE INTO SHARED PREFS (KEEP OLD KEYS + add structured keys)
    // ==========================================================
    try {
      final prefs = await SharedPreferences.getInstance();

      prefs.setString('latest_pattern_insight', patternInsight);
      prefs.setString('latest_suggested_game',
          (suggestions['suggestedGame'] ?? '').toString());
      prefs.setString('latest_suggested_relaxation',
          (suggestions['suggestedRelaxation'] ?? '').toString());
      prefs.setString('latest_suggested_video',
          (suggestions['suggestedVideo'] ?? '').toString());
      prefs.setString('latest_suggested_video_title',
          (suggestions['suggestedVideoTitle'] ?? '').toString());
      prefs.setString('latest_discover_tip',
          (suggestions['discoverTip'] ?? '').toString());

      prefs.setString('latest_today_video_url', today_video_primary_url);
      prefs.setString('latest_today_video_title', today_video_primary_title);

      prefs.setString('latest_history_video_url', historyVideo['url'] ?? '');
      prefs.setString('latest_history_video_title', historyVideo['title'] ?? '');
    } catch (_) {}

    // RETURN FULL AI PAYLOAD (structured)
    return {
      "dailyInsight": dailyInsight,
      "patternInsight": patternInsight,
      "tags": tags,
      "stressScore": stressScore,
      // Legacy fields (kept)
      ...suggestions,

      // TODAY structured map (primary = in-app when possible, secondary = external)
      "today": {
        "game_primary": today_game_primary,
        "game_secondary": today_game_secondary,
        "relax_primary": today_relax_primary,
        "relax_secondary": today_relax_secondary,
        "video_primary_title": today_video_primary_title,
        "video_primary_url": today_video_primary_url,
        "video_secondary_title": today_video_secondary_title,
        "video_secondary_url": today_video_secondary_url,
      },

      // PATTERN structured map (overall suggestions)
      "pattern": {
        "game_primary": pattern_game_primary,
        "game_secondary": pattern_game_secondary,
        "relax_primary": pattern_relax_primary,
        "relax_secondary": pattern_relax_secondary,
        "video_primary_title": pattern_video_primary_title,
        "video_primary_url": pattern_video_primary_url,
        "video_secondary_title": pattern_video_secondary_title,
        "video_secondary_url": pattern_video_secondary_url,
      },

      // Backwards-compatible single fields for any screens still using them
      "todayGame": todayGame,
      "todayRelaxation": todayRelaxation,
      "todayVideoUrl": today_video_primary_url,
      "todayVideoTitle": today_video_primary_title,
    };
  }

  // ==========================================================
  // Helper: rotate list element safely
  // ==========================================================
  static String _rotateListElement(List<String> list, int seed) {
    if (list.isEmpty) return '';
    return list[seed % list.length];
  }

  static List<String> _fallbackGameList() {
    return [
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
  }

  static List<String> _fallbackRelaxList() {
    return [
      "Box breathing (4-4-4)",
      "Progressive muscle release",
      "Body-scan mini",
      "2-minute gratitude pause",
      "Shoulder release stretch",
      "Palm tracing calm",
      "Grounding 5-4-3-2-1",
      "Slow-counted exhale",
    ];
  }

  // ==========================================================
  // TAG DETECTION
  // ==========================================================
  static List<String> _detectTags(String text) {
    final t = text.toLowerCase();
    final tags = <String>{};

    if (t.contains("stress") || t.contains("pressure")) tags.add("stress");
    if (t.contains("anxiety") || t.contains("panic")) tags.add("anxiety");
    if (t.contains("sad") || t.contains("depressed")) tags.add("low mood");
    if (t.contains("fight") || t.contains("argument")) tags.add("conflict");
    if (t.contains("sleep") || t.contains("tired")) tags.add("sleep issues");
    if (t.contains("money") || t.contains("rent")) tags.add("money worry");
    if (t.contains("study") || t.contains("exam")) tags.add("productivity");

    if (tags.isEmpty) tags.add("general");
    return tags.toList();
  }

  // ==========================================================
  // STRESS SCORE
  // ==========================================================
  static int _estimateStressScore(String t) {
    t = t.toLowerCase();
    double score = 30;

    const neg = {
      "stress": 15, "anxiety": 12, "panic": 12,
      "sad": 10, "lonely": 10, "fight": 6,
      "money": 7, "tired": 8, "exhausted": 10,
    };

    const pos = {
      "calm": -10, "relaxed": -10,
      "hopeful": -6, "grateful": -6,
    };

    neg.forEach((w, v) { if (t.contains(w)) score += v; });
    pos.forEach((w, v) { if (t.contains(w)) score += v; });

    return max(0, min(100, score.round()));
  }

  // ==========================================================
  // FETCH LAST 10 DIARY ENTRIES
  // ==========================================================
  static Future<List<String>> _fetchPastDiaryTexts(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map((d) => d.data()['content']?.toString() ?? '')
          .where((t) => t.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================================
  // OLD PATTERN SUGGESTION ENGINE (KEPT WITH SMALL ADJUST)
  // ==========================================================
  static Future<Map<String, dynamic>> _buildAISuggestions(
      List<String> tags, int stress, String text) async {
    String primaryGame = "Mind Tricks";
    String secondaryGame = "Mini Sudoku";

    try {
      final g = await GroqAIService.suggestGamesFromAI(
        tags: tags,
        stressScore: stress,
        diaryText: text,
      );
      primaryGame = g['primary'] ?? primaryGame;
      secondaryGame = g['secondary'] ?? secondaryGame;
    } catch (_) {}

    final gameLine = "$primaryGame — also try $secondaryGame";

    String relax = "Breathing exercise";

    if (tags.contains("stress") || tags.contains("anxiety"))
      relax = "Calm slow breathing (4-4-4)";
    else if (tags.contains("sleep issues"))
      relax = "Body-scan before sleep";
    else if (tags.contains("low mood"))
      relax = "2-minute gratitude pause";

    // DEPRECATED static video removed; use Groq selections / tag pools instead
    String video = "";
    String videoTitle = "";

    final discoverTip = "Your Discover page is refreshed with videos matching your mood.";

    return {
      "suggestedGame": gameLine,
      "suggestedGamePrimary": primaryGame,
      "suggestedGameSecondary": secondaryGame,
      "suggestedRelaxation": relax,
      "suggestedVideo": video,
      "suggestedVideoTitle": videoTitle,
      "discoverTip": discoverTip,
    };
  }

  // ==========================================================
  // B-TYPE MIXED EXTRA SUGGESTIONS (KEPT)
  // ==========================================================

  static Map<String, String> _generateYouTubeSuggestion(List<String> tags) {
    final random = Random();
    final keywords = {
      "stress": ["calm down fast", "breath focus reset", "box breathing tutorial"],
      "anxiety": ["stop panic cycle", "anxiety grounding", "1 minute calm"],
      "sleep issues": ["sleep meditation", "deep sleep music", "night routine calm"],
      "low mood": ["motivation short", "feel better quick", "uplift mood"],
      "general": ["self-care reminders", "mindfulness short"]
    };

    final list = keywords[tags.first] ?? keywords["general"]!;
    final term = list[random.nextInt(list.length)];

    return {
      "title": term,
      "url": "https://www.youtube.com/results?search_query=${Uri.encodeComponent(term)}"
    };
  }

  static Map<String, String> _generateArticleSuggestion(List<String> tags) {
    final random = Random();

    final articles = {
      "stress": [
        "https://www.psychologytoday.com/us/basics/stress",
        "https://www.healthline.com/health/stress"
      ],
      "anxiety": [
        "https://www.healthline.com/health/anxiety",
        "https://psychcentral.com/anxiety"
      ],
      "sleep issues": [
        "https://www.sleepfoundation.org/",
        "https://www.healthline.com/health/insomnia"
      ],
      "low mood": [
        "https://psychcentral.com/depression",
        "https://www.healthline.com/health/depression"
      ],
      "general": ["https://www.healthline.com/", "https://psychcentral.com/"]
    };

    final pick = articles[tags.first] ?? articles["general"]!;
    return {"url": pick[random.nextInt(pick.length)]};
  }

  static Map<String, String> _generateTaskSuggestion(List<String> tags) {
    final random = Random();

    final tasks = {
      "stress": [
        "Do a 30-second deep breath reset",
        "Look around & name 5 objects — grounding"
      ],
      "anxiety": [
        "Do the 5-4-3-2-1 grounding technique",
        "Drink a glass of water slowly"
      ],
      "sleep issues": [
        "Avoid screen for 5 minutes",
        "Stretch neck + shoulders for 20 seconds"
      ],
      "low mood": [
        "Write 1 thing that went right today",
        "Stand up + open your window for fresh air"
      ],
      "general": ["Blink slowly 5 times", "Sit straight for 10 seconds"]
    };

    final pick = tasks[tags.first] ?? tasks["general"]!;
    return {"task": pick[random.nextInt(pick.length)]};
  }

  static Map<String, String> _generateSecondaryGame(List<String> tags) {
    final random = Random();

    final games = {
      "stress": ["Breath Popper", "Color Focus Match"],
      "anxiety": ["Circle Tap Calm", "Mind Loop Breaker"],
      "low mood": ["Happy Tile Flip", "Gratitude Tap"],
      "sleep issues": ["Slow Tap Rhythm", "Calm Sort Mini"],
      "general": ["Mini Zen Tiles", "Simple Tap Focus"]
    };

    final list = games[tags.first] ?? games["general"]!;
    return {"name": list[random.nextInt(list.length)]};
  }

  static Map<String, String> _generateSecondaryRelaxation(List<String> tags) {
    final random = Random();

    final relax = {
      "stress": ["Shoulder release", "3-count breathing"],
      "anxiety": ["Palm tracing calm", "Butterfly tapping"],
      "sleep issues": ["Slow body unwind", "4-7-8 pre-sleep breath"],
      "low mood": ["Gentle self-hug", "1 minute grounding"],
      "general": ["Mini mindfulness", "Slow breath cycle"]
    };

    final list = relax[tags.first] ?? relax["general"]!;
    return {"name": list[random.nextInt(list.length)]};
  }
}
