// lib/src/screens/insight_engine_screen.dart
// ===============================================
// AI INSIGHT ENGINE v5.2 (UI updated to use Today + Pattern structured AI output)
// - Removes old static suggestion fields
// - Shows primary + secondary suggestions for Game, Relaxation, Video
// - Secondary suggestions open external DiscoverScreen (if URL) or YouTube search
// - Cleans up small card layout to avoid RenderFlex overflow
// ===============================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

import '../services/insights_engine_service.dart';
import 'games.dart';
import 'relaxation.dart';
import 'discover.dart';

class InsightEngineScreen extends StatefulWidget {
  const InsightEngineScreen({Key? key}) : super(key: key);

  @override
  State<InsightEngineScreen> createState() => _InsightEngineScreenState();
}

class _InsightEngineScreenState extends State<InsightEngineScreen> {
  bool _isLoading = false;

  Map<String, dynamic>? _result; // AI output (expects dailyInsight, patternInsight, today{}, pattern{}, stressScore, tags)
  List<Map<String, dynamic>> _moodLogs = []; // moods used for analysis
  String _moodSummary = "No mood data";

  // For CSV export
  String _rawDiaryText = '';
  List<Map<String, dynamic>> _rawMoodLogs = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  // ----------------------------------------
  // Date Helpers
  // ----------------------------------------

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    return DateFormat('MMM dd, yyyy').format(d);
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _toDate;
        }
      });
    }
  }

  Widget _pickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.neonCyan,
          onPrimary: Colors.black,
          surface: AppTheme.darkBase,
          onSurface: Colors.white,
        ),
      ),
      child: child!,
    );
  }

  // ----------------------------------------
  // Check if selected date range includes TODAY
  // ----------------------------------------

  bool _rangeIncludesToday() {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);

    final isSameAsFrom = today.isAtSameMomentAs(from);
    final isSameAsTo = today.isAtSameMomentAs(to);
    final between = today.isAfter(from) && today.isBefore(to);

    return isSameAsFrom || isSameAsTo || between;
  }

  // ----------------------------------------
  // Core: Analyze diary + moods
  // ----------------------------------------

  Future<void> _runInsights() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both From and To dates')),
      );
      return;
    }

    final from = DateTime(
        _fromDate!.year, _fromDate!.month, _fromDate!.day, 0, 0, 0);
    final to =
        DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);

    if (to.isBefore(from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"To" date must be after "From" date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _moodLogs = [];
      _moodSummary = "No mood data";
      _rawDiaryText = '';
      _rawMoodLogs = [];
    });

    try {
      // ---- Fetch Diary Entries ----
      final journalSnap = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('timestamp')
          .get();

      final diaryText = journalSnap.docs
          .map((d) => d['content']?.toString() ?? "")
          .where((t) => t.trim().isNotEmpty)
          .join("\n\n---\n\n");

      if (diaryText.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No diary entries in this range')),
        );
        return;
      }

      _rawDiaryText = diaryText;

      // ---- Fetch Mood Logs ----
      final moodSnap = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('timestamp')
          .get();

      _moodLogs = moodSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final ts = data['timestamp'] as Timestamp?;
        final dt = ts?.toDate().toLocal();
        final dateStr = dt != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(dt)
            : 'Unknown';

        final valueRaw = data['value'];
        final doubleVal = (valueRaw is num)
            ? valueRaw.toDouble()
            : double.tryParse(valueRaw?.toString() ?? '') ?? 3.0;

        final map = {
          "emoji": data["emoji"] ?? "",
          "label": data["label"] ?? "",
          "value": doubleVal,
          "timestamp": ts,
          "date": dateStr,
        };
        return map;
      }).toList();

      _rawMoodLogs = List<Map<String, dynamic>>.from(_moodLogs);

      // ---- Create Mood Summary ----
      _moodSummary = _createMoodSummary();

      // ---- Build AI Input ----
      final moodLines = _moodLogs.isEmpty
          ? "No mood logs found."
          : _moodLogs
              .map((m) =>
                  "${m['date']} → ${m['emoji']} ${m['label']} (${m['value']}/5)")
              .join("\n");

      final combinedText = """
### DIARY ENTRIES:
$diaryText

### MOOD LOGS:
$moodLines

### INSTRUCTION:
Analyze the combined diary entries and mood logs.
Focus on emotional tone, stress, money worries, conflict, sleep, productivity and mood drift over time.
Return balanced, non-clinical insights, and include Today + Pattern suggestions with primary + secondary items for game, relaxation, and video.
""";

      // ---- Send to AI Engine (your service) ----
      // NOTE: InsightsEngine.analyzeEntry should return the new structured JSON:
      // { dailyInsight, patternInsight, futurePrediction, stressScore, tags, today: {...}, pattern: {...} }
      final ai = await InsightsEngine.analyzeEntry(user.uid, combinedText);

      setState(() {
        _result = ai;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI analysis failed: $e')),
      );
    }
  }

  // Create mood summary based on average mood
  String _createMoodSummary() {
    if (_moodLogs.isEmpty) return "No mood logs found";

    final avg = _moodLogs
            .map((m) => m['value'] as double)
            .fold<double>(0, (a, b) => a + b) /
        _moodLogs.length;

    if (avg >= 4.0) return "Mostly Positive 😊";
    if (avg >= 2.5) return "Mixed / Neutral 😐";
    return "Low Mood Detected 😢";
  }

  // ----------------------------------------
  // Common tiny helper
  // ----------------------------------------

  String _safeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
  }

  // helper to open external suggestions (videos or web). If url looks like a full url, open it; otherwise use it as a YouTube search.
  void _openExternalSuggestion(String text, {String? fallbackQuery}) {
    final trimmed = text.trim();
    String url = trimmed;
    if (trimmed.isEmpty) {
      if ((fallbackQuery ?? '').isNotEmpty) {
        url =
            'https://www.youtube.com/results?search_query=${Uri.encodeComponent(fallbackQuery!)}';
      } else {
        url = 'https://www.youtube.com';
      }
    } else {
      // if text looks like a URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        url = trimmed;
      } else {
        // treat as search query/title
        url =
            'https://www.youtube.com/results?search_query=${Uri.encodeComponent(trimmed)}';
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverScreen(
          insightVideoUrl: url,
          insightVideoTitle: trimmed.isNotEmpty ? trimmed : (fallbackQuery ?? 'Search'),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  //  SAVE CSV TO STORAGE (Android/iOS-safe)
  // ------------------------------------------------------------

  Future<String> _saveInsightReport(
      String filename, String contents) async {
    final safe = _safeFileName(filename);

    // iOS / macOS → app documents
    if (Platform.isIOS || Platform.isMacOS) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/$safe");
      await file.writeAsString(contents);
      return file.path;
    }

    // Android
    if (Platform.isAndroid) {
      Directory? dir;
      try {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }

        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (dirs != null && dirs.isNotEmpty) {
          dir = dirs.first;
        }
      } catch (_) {}

      dir ??= await getApplicationDocumentsDirectory();

      final file = File("${dir.path}/$safe");
      await file.writeAsString(contents);
      return file.path;
    }

    // Fallback
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$safe");
    await file.writeAsString(contents);
    return file.path;
  }

  // ------------------------------------------------------------
  //  DOWNLOAD REPORT BUTTON + CSV EXPORT
  // ------------------------------------------------------------

  Widget _downloadReportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.download),
        label: const Text("Download Full AI Report"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: _downloadAIReport,
      ),
    );
  }

  Future<void> _downloadAIReport() async {
    if (_result == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first.")),
      );
      return;
    }

    try {
      final rows = <List<dynamic>>[];

      rows.add(["PeacePal AI Insight Engine Report"]);
      rows.add(["Generated At", DateTime.now().toString()]);
      rows.add(["User ID", user.uid]);
      rows.add([]);

      rows.add(["Date Range"]);
      rows.add([
        _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : "-",
        "to",
        _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : "-",
      ]);
      rows.add([]);

      rows.add(["Mood Summary", _moodSummary]);
      rows.add(["Stress Score", _result?["stressScore"] ?? ""]);
      rows.add(["Daily Insight", _result?["dailyInsight"] ?? ""]);
      rows.add(["Pattern Insight", _result?["patternInsight"] ?? ""]);

      // Add structured suggestions if present
      final today = (_result?['today'] ?? {}) as Map<String, dynamic>;
      final pattern = (_result?['pattern'] ?? {}) as Map<String, dynamic>;

      rows.add([]);
      rows.add(["TODAY SUGGESTIONS"]);
      rows.add(["Game Primary", today['game_primary'] ?? ""]);
      rows.add(["Game Secondary", today['game_secondary'] ?? ""]);
      rows.add(["Relax Primary", today['relax_primary'] ?? ""]);
      rows.add(["Relax Secondary", today['relax_secondary'] ?? ""]);
      rows.add(["Video Primary Title", today['video_primary_title'] ?? ""]);
      rows.add(["Video Primary URL", today['video_primary_url'] ?? ""]);
      rows.add(["Video Secondary Title", today['video_secondary_title'] ?? ""]);
      rows.add(["Video Secondary URL", today['video_secondary_url'] ?? ""]);

      rows.add([]);
      rows.add(["PATTERN SUGGESTIONS"]);
      rows.add(["Game Primary", pattern['game_primary'] ?? ""]);
      rows.add(["Game Secondary", pattern['game_secondary'] ?? ""]);
      rows.add(["Relax Primary", pattern['relax_primary'] ?? ""]);
      rows.add(["Relax Secondary", pattern['relax_secondary'] ?? ""]);
      rows.add(["Video Primary Title", pattern['video_primary_title'] ?? ""]);
      rows.add(["Video Primary URL", pattern['video_primary_url'] ?? ""]);
      rows.add(["Video Secondary Title", pattern['video_secondary_title'] ?? ""]);
      rows.add(["Video Secondary URL", pattern['video_secondary_url'] ?? ""]);

      rows.add([]);

      // TAGS
      final tags = (_result?['tags'] ?? []) as List<dynamic>;
      rows.add(["Detected Tags"]);
      if (tags.isEmpty) {
        rows.add(["None"]);
      } else {
        for (var t in tags) {
          rows.add(["- ${t.toString()}"]);
        }
      }

      rows.add([]);
      rows.add(["Diary Entries Used"]);
      rows.add([
        _rawDiaryText.trim().isEmpty
            ? "No text captured"
            : _rawDiaryText.trim()
      ]);
      rows.add([]);

      // RAW MOOD LOGS
      rows.add(["Mood Entries Used"]);
      if (_rawMoodLogs.isEmpty) {
        rows.add(["No mood logs in this range"]);
      } else {
        rows.add(["Date", "Emoji", "Label", "Value"]);
        for (final m in _rawMoodLogs) {
          rows.add([
            m["date"] ?? "",
            m["emoji"] ?? "",
            m["label"] ?? "",
            m["value"]?.toString() ?? "",
          ]);
        }
      }

      final csv = const ListToCsvConverter().convert(rows);

      final filename =
          "PeacePal_AI_Report_${DateTime.now().millisecondsSinceEpoch}.csv";

      final path = await _saveInsightReport(filename, csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Saved AI report to:\n$path")),
      );

      try {
        await OpenFile.open(path);
      } catch (_) {
        // ignore open failure; file is still saved
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Report export failed: $e")),
      );
    }
  }

  // ----------------------------------------
  // UI
  // ----------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insight Engine'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _introCard(),
              const SizedBox(height: 16),
              _dateSelectorCard(),
              const SizedBox(height: 16),
              if (_isLoading)
                Center(
                  child: Column(
                    children: const [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.neonCyan),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Analyzing your diary + mood...',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else if (_result != null)
                Column(
                  children: [
                    _moodSummaryCard(),
                    const SizedBox(height: 16),
                    _analysisAndSuggestionsCard(),
                    const SizedBox(height: 16),
                    _downloadReportButton(),
                  ],
                )
              else
                _emptyStateCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------- INTRO CARD ---------------------

  Widget _introCard() {
    return GlassCard(
      opacity: 0.14,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'The AI Insight Engine reads your Personal AI Diary + Mood logs.\n\n'
          'Select a From and To date. AI will detect:\n'
          '• mood patterns\n'
          '• emotional drift\n'
          '• stress level\n'
          '• suggested game / relaxation / video (primary + secondary)',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
      ),
    );
  }

  // --------------------- DATE SELECTOR ---------------------

  Widget _dateSelectorCard() {
    return GlassCard(
      opacity: 0.12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analyze diary + mood by date range',
              style: TextStyle(
                color: AppTheme.neonPurple,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                    label: "From",
                    date: _fromDate,
                    onTap: _pickFromDate,
                    icon: Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateTile(
                    label: "To",
                    date: _toDate,
                    onTap: _pickToDate,
                    icon: Icons.calendar_month,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Analyze Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neuralBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _runInsights,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white10,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.neonCyan),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: ${_formatDate(date)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------- EMPTY STATE ---------------------

  Widget _emptyStateCard() {
    return GlassCard(
      opacity: 0.12,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Pick a From and To date.\n\n'
          'AI will read all your diary + mood logs inside the selected range.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }

  // --------------------- MOOD SUMMARY CARD ---------------------

  Widget _moodSummaryCard() {
    return GlassCard(
      opacity: 0.16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.mood, color: Colors.yellowAccent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mood Summary: $_moodSummary',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// --------------------- MAIN ANALYSIS + SUGGESTIONS CARD (REPLACE THIS ENTIRE SECTION) ---------------------

Widget _analysisAndSuggestionsCard() {
  final daily = _result?['dailyInsight'] ?? 'No daily insight';
  final pattern = _result?['patternInsight'] ?? 'No pattern insight';
  final futurePrediction =
      (_result?['futurePrediction'] ?? '').toString().trim();

  final tags = (_result?['tags'] ?? []) as List<dynamic>;
  final stressRaw = _result?['stressScore'];
  final stress = (stressRaw is int) ? stressRaw : int.tryParse('$stressRaw') ?? 0;

  // Access structured suggestion maps
  final today = (_result?['today'] ?? {}) as Map<String, dynamic>;
  final patternMap = (_result?['pattern'] ?? {}) as Map<String, dynamic>;

  // Today's keys (titles/headings) used to decide stacking
  final todayHeadingCandidates = <String>[
    (today['relax_primary'] ?? '').toString(),
    (today['relax_secondary'] ?? '').toString(),
    (today['game_primary'] ?? '').toString(),
    (today['game_secondary'] ?? '').toString(),
    (today['video_primary_title'] ?? '').toString(),
    (today['video_secondary_title'] ?? '').toString(),
  ];

  // If any heading is long, we'll stack tiles vertically (rectangular)
  final bool longHeading =
      todayHeadingCandidates.any((s) => s.trim().length > 24);

  // Determine whether to show the "today" section (only when within range AND there is at least one today suggestion)
  final todayHasAny = todayHeadingCandidates.any((s) => s.trim().isNotEmpty) ||
      (today['video_primary_url'] ?? '').toString().trim().isNotEmpty ||
      (today['video_secondary_url'] ?? '').toString().trim().isNotEmpty;

  final showTodaySection = todayHasAny && _rangeIncludesToday();

  return GlassCard(
    opacity: 0.16,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall mood line
          Text(
            'Overall mood: $_moodSummary',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // 1) TODAY'S ENTRIES ANALYSED
          if (showTodaySection) ...[
            const Text(
              "Today's entries analysed – here’s what I suggest",
              style: TextStyle(
                color: AppTheme.neonCyan,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Show daily insight as concise bullet points
            ..._buildBulletPoints(daily).map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: w,
                )),

            const SizedBox(height: 8),

            // NOTE: If any tile heading is long we automatically convert the compact three-tile
            // row into stacked rectangular tiles (one-per-row) so long headings fit and avoid overflow.
            if (longHeading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Note: Large headings may overflow in compact tiles — switching tiles to stacked rectangles fixes that.',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),

            // --- Tiles: either a Compact Row (default) or Stacked Rectangles if headings are long
            if (!longHeading)
              Row(
                children: [
                  // Relax tile (compact)
                  Expanded(
                    child: _smallSuggestionCardWithSecondary(
                      icon: Icons.self_improvement,
                      heading: "Relax",
                      primary: (today['relax_primary'] ?? '').toString(),
                      secondary: (today['relax_secondary'] ?? '').toString(),
                      primaryTap: () {
                        if ((today['relax_primary'] ?? '').toString().trim().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RelaxationScreen(),
                            ),
                          );
                        } else if ((today['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                          _openExternalSuggestion((today['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
                        }
                      },
                      secondaryTap: () {
                        if ((today['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                          _openExternalSuggestion((today['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Game tile (compact)
                  Expanded(
                    child: _smallSuggestionCardWithSecondary(
                      icon: Icons.videogame_asset_rounded,
                      heading: "Game",
                      primary: (today['game_primary'] ?? '').toString(),
                      secondary: (today['game_secondary'] ?? '').toString(),
                      primaryTap: () {
                        if ((today['game_primary'] ?? '').toString().trim().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GamesScreen(),
                            ),
                          );
                        } else if ((today['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                          _openExternalSuggestion((today['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
                        }
                      },
                      secondaryTap: () {
                        if ((today['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                          _openExternalSuggestion((today['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Discover composite tile (compact)
                  Expanded(
                    child: _discoverMiniCardsStructured(
                      todayTitle: (today['video_primary_title'] ?? '').toString(),
                      todayUrl: (today['video_primary_url'] ?? '').toString(),
                      todaySecondaryTitle: (today['video_secondary_title'] ?? '').toString(),
                      todaySecondaryUrl: (today['video_secondary_url'] ?? '').toString(),
                      patternTitle: (patternMap['video_primary_title'] ?? '').toString(),
                      patternUrl: (patternMap['video_primary_url'] ?? '').toString(),
                      tags: tags.map((t) => t.toString()).toList(),
                    ),
                  ),
                ],
              )
            else
              // stacked rectangular tiles (one-by-one) when headings are long
              Column(
                children: [
                  const SizedBox(height: 6),
                  _todaySuggestionTileTwoLines(
                    icon: Icons.self_improvement,
                    title: "Relax (today)",
                    primary: (today['relax_primary'] ?? '').toString(),
                    secondary: (today['relax_secondary'] ?? '').toString(),
                    onPrimaryTap: () {
                      if ((today['relax_primary'] ?? '').toString().trim().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RelaxationScreen()),
                        );
                      } else if ((today['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                        _openExternalSuggestion((today['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
                      }
                    },
                    onSecondaryTap: () {
                      if ((today['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                        _openExternalSuggestion((today['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _todaySuggestionTileTwoLines(
                    icon: Icons.games_outlined,
                    title: "Game (today)",
                    primary: (today['game_primary'] ?? '').toString(),
                    secondary: (today['game_secondary'] ?? '').toString(),
                    onPrimaryTap: () {
                      if ((today['game_primary'] ?? '').toString().trim().isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesScreen()));
                      } else if ((today['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                        _openExternalSuggestion((today['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
                      }
                    },
                    onSecondaryTap: () {
                      if ((today['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                        _openExternalSuggestion((today['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _todaySuggestionTileTwoLines(
                    icon: Icons.play_circle,
                    title: "Video suggestions (today)",
                    primary: (today['video_primary_title'] ?? '').toString(),
                    secondary: (today['video_secondary_title'] ?? '').toString(),
                    onPrimaryTap: () {
                      final u = (today['video_primary_url'] ?? '').toString();
                      if (u.trim().isNotEmpty) {
                        _openExternalSuggestion(u, fallbackQuery: (today['video_primary_title'] ?? '').toString());
                      } else {
                        _openExternalSuggestion((today['video_primary_title'] ?? '').toString(), fallbackQuery: 'video');
                      }
                    },
                    onSecondaryTap: () {
                      final u = (today['video_secondary_url'] ?? '').toString();
                      if (u.trim().isNotEmpty) {
                        _openExternalSuggestion(u, fallbackQuery: (today['video_secondary_title'] ?? '').toString());
                      } else {
                        _openExternalSuggestion((today['video_secondary_title'] ?? '').toString(), fallbackQuery: 'video');
                      }
                    },
                  ),
                ],
              ),

            const SizedBox(height: 14),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
          ],

          // 2) PATTERN DETECTED SECTION
          const Text(
            'Pattern detected from your entries',
            style: TextStyle(
              color: AppTheme.neonPurple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pattern.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),

          // Pattern-based suggestion tiles (overall) - show primary + secondary
          _todaySuggestionTileTwoLines(
            icon: Icons.self_improvement,
            title: "Relaxation (overall pattern)",
            primary: (patternMap['relax_primary'] ?? '').toString(),
            secondary: (patternMap['relax_secondary'] ?? '').toString(),
            onPrimaryTap: () {
              if ((patternMap['relax_primary'] ?? '').toString().trim().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RelaxationScreen(),
                  ),
                );
              } else if ((patternMap['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                _openExternalSuggestion((patternMap['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
              }
            },
            onSecondaryTap: () {
              if ((patternMap['relax_secondary'] ?? '').toString().trim().isNotEmpty) {
                _openExternalSuggestion((patternMap['relax_secondary'] ?? '').toString(), fallbackQuery: 'relaxation');
              }
            },
          ),
          const SizedBox(height: 8),
          _todaySuggestionTileTwoLines(
            icon: Icons.games_outlined,
            title: "Micro-game (overall pattern)",
            primary: (patternMap['game_primary'] ?? '').toString(),
            secondary: (patternMap['game_secondary'] ?? '').toString(),
            onPrimaryTap: () {
              if ((patternMap['game_primary'] ?? '').toString().trim().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GamesScreen(),
                  ),
                );
              } else if ((patternMap['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                _openExternalSuggestion((patternMap['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
              }
            },
            onSecondaryTap: () {
              if ((patternMap['game_secondary'] ?? '').toString().trim().isNotEmpty) {
                _openExternalSuggestion((patternMap['game_secondary'] ?? '').toString(), fallbackQuery: 'micro game');
              }
            },
          ),
          const SizedBox(height: 8),
          if ((patternMap['video_primary_url'] ?? '').toString().trim().isNotEmpty ||
              (patternMap['video_secondary_url'] ?? '').toString().trim().isNotEmpty ||
              (patternMap['video_primary_title'] ?? '').toString().trim().isNotEmpty ||
              (patternMap['video_secondary_title'] ?? '').toString().trim().isNotEmpty)
            _todaySuggestionTileTwoLines(
              icon: Icons.play_circle,
              title: "Discover videos (overall pattern)",
              primary: (patternMap['video_primary_title'] ?? '').toString(),
              secondary: (patternMap['video_secondary_title'] ?? '').toString(),
              onPrimaryTap: () {
                final u = (patternMap['video_primary_url'] ?? '').toString();
                if (u.trim().isNotEmpty) {
                  _openExternalSuggestion(u, fallbackQuery: (patternMap['video_primary_title'] ?? '').toString());
                } else {
                  _openExternalSuggestion((patternMap['video_primary_title'] ?? '').toString(), fallbackQuery: 'video');
                }
              },
              onSecondaryTap: () {
                final u = (patternMap['video_secondary_url'] ?? '').toString();
                if (u.trim().isNotEmpty) {
                  _openExternalSuggestion(u, fallbackQuery: (patternMap['video_secondary_title'] ?? '').toString());
                } else {
                  _openExternalSuggestion((patternMap['video_secondary_title'] ?? '').toString(), fallbackQuery: 'video');
                }
              },
            ),
          const SizedBox(height: 14),

          // 3) PREDICTED FUTURE (if present)
          if (futurePrediction.isNotEmpty) ...[
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              'Predicted future (if these patterns continue)',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              futurePrediction,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // TAGS + STRESS
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          const Text(
            'Detected themes:',
            style: TextStyle(
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Text(
                  t.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Stress Score: $stress / 100',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (stress.clamp(0, 100)) / 100,
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                stress < 35
                    ? Colors.greenAccent
                    : (stress < 70 ? Colors.orangeAccent : Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick buttons (keep same)
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GamesScreen()),
              );
            },
            icon: const Icon(Icons.sports_esports),
            label: const Text('Open Games'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RelaxationScreen()),
              );
            },
            icon: const Icon(Icons.self_improvement),
            label: const Text('Open Relaxation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '⚠️ Informational only — not medical advice.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}

// --------------------- TILE HELPERS (keeps existing look + behaviour) ---------------------

Widget _todaySuggestionTileTwoLines({
  required IconData icon,
  required String title,
  required String primary,
  required String secondary,
  VoidCallback? onPrimaryTap,
  VoidCallback? onSecondaryTap,
}) {
  return GestureDetector(
    onTap: onPrimaryTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonCyan.withOpacity(0.18),
            ),
            child: Icon(icon, color: AppTheme.neonCyan, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (primary.trim().isNotEmpty)
                  InkWell(
                    onTap: onPrimaryTap,
                    child: Text(
                      "1) ${primary.trim()}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (secondary.trim().isNotEmpty) const SizedBox(height: 4),
                if (secondary.trim().isNotEmpty)
                  InkWell(
                    onTap: onSecondaryTap,
                    child: Text(
                      "2) ${secondary.trim()}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Small card used in today's three tiles row (compact) with primary + secondary
Widget _smallSuggestionCardWithSecondary({
  required IconData icon,
  required String heading,
  required String primary,
  required String secondary,
  VoidCallback? primaryTap,
  VoidCallback? secondaryTap,
}) {
  return InkWell(
    onTap: primaryTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonCyan.withOpacity(0.16),
            ),
            child: Icon(icon, size: 20, color: AppTheme.neonCyan),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (primary.trim().isNotEmpty)
                  GestureDetector(
                    onTap: primaryTap,
                    child: Text(
                      "1) ${primary.trim()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (secondary.trim().isNotEmpty) const SizedBox(height: 6),
                if (secondary.trim().isNotEmpty)
                  GestureDetector(
                    onTap: secondaryTap,
                    child: Text(
                      "2) ${secondary.trim()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Discover composite: shows primary video, secondary video, search row
Widget _discoverMiniCardsStructured({
  required String todayTitle,
  required String todayUrl,
  required String todaySecondaryTitle,
  required String todaySecondaryUrl,
  required String patternTitle,
  required String patternUrl,
  required List<String> tags,
}) {
  // Build a reasonable fallback search query
  String query = '';
  if (todayTitle.isNotEmpty) {
    query = todayTitle;
  } else if (todaySecondaryTitle.isNotEmpty) {
    query = todaySecondaryTitle;
  } else if (patternTitle.isNotEmpty) {
    query = patternTitle;
  } else if (tags.isNotEmpty) {
    query = tags.join(' ');
  } else {
    query = 'calming guided meditation';
  }

  final searchUrl =
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';

  return Container(
    height: 96,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24, width: 0.8),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonCyan.withOpacity(0.16),
            ),
            child: const Icon(Icons.play_circle_fill, color: AppTheme.neonCyan),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Today video
              Flexible(
                fit: FlexFit.tight,
                child: _tinyDiscoverRow(
                  title: 'Primary',
                  subtitle: todayTitle.isNotEmpty ? todayTitle : (todayUrl.isNotEmpty ? 'Play suggested video' : 'No primary video'),
                  onTap: () {
                    if (todayUrl.isNotEmpty) {
                      _openExternalSuggestion(todayUrl, fallbackQuery: todayTitle);
                    } else if (todayTitle.isNotEmpty) {
                      _openExternalSuggestion(todayTitle, fallbackQuery: todayTitle);
                    } else {
                      _openExternalSuggestion(query, fallbackQuery: query);
                    }
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Secondary Today video
              Flexible(
                fit: FlexFit.tight,
                child: _tinyDiscoverRow(
                  title: 'Secondary',
                  subtitle: todaySecondaryTitle.isNotEmpty ? todaySecondaryTitle : (todaySecondaryUrl.isNotEmpty ? 'Play fallback video' : 'No secondary video'),
                  onTap: () {
                    if (todaySecondaryUrl.isNotEmpty) {
                      _openExternalSuggestion(todaySecondaryUrl, fallbackQuery: todaySecondaryTitle);
                    } else if (todaySecondaryTitle.isNotEmpty) {
                      _openExternalSuggestion(todaySecondaryTitle, fallbackQuery: todaySecondaryTitle);
                    } else if (patternUrl.isNotEmpty) {
                      _openExternalSuggestion(patternUrl, fallbackQuery: patternTitle);
                    } else {
                      _openExternalSuggestion(query, fallbackQuery: query);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Tiny single-line discover row used inside the composite
Widget _tinyDiscoverRow({
  required String title,
  required String subtitle,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.open_in_new, color: Colors.white38, size: 14),
      ],
    ),
  );
}

// --------------------- HELPER: Convert AI text into short bullet widgets ---------------------
List<Widget> _buildBulletPoints(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) {
    return [const Text('', style: TextStyle())];
  }

  // Split into sentences or lines, keep up to 4 bullets
  final candidates = <String>[];

  // Try splitting by sentences first using String.split with RegExp
  final sentenceSplitter = RegExp(r'(?<=[.!?])\s+');
  final sentences = cleaned.split(sentenceSplitter);
  for (var s in sentences) {
    final t = s.trim();
    if (t.isNotEmpty) {
      candidates.add(t);
    }
    if (candidates.length >= 4) break;
  }

  // Fallback: split by newlines if sentences not helpful
  if (candidates.isEmpty) {
    final lines = cleaned.split('\n');
    for (var l in lines) {
      final t = l.trim();
      if (t.isNotEmpty) {
        candidates.add(t);
      }
      if (candidates.length >= 4) break;
    }
  }

  // Limit bullet length to avoid huge lines
  return candidates.map((c) {
    final short = c.length > 140 ? c.substring(0, 137).trim() + '...' : c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: Icon(Icons.circle, size: 6, color: Colors.white70),
        ),
        Expanded(
          child: Text(
            short,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }).toList();
}
}