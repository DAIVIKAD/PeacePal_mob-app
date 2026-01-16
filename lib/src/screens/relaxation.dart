// lib/src/screens/relaxation.dart
//
// Relaxation Hub v5 — INDIAN RITUALS + FULL AI VERSION
// - Top priority: Indian focus / discipline rituals
//      • AI pipeline: Insight Engine -> tags + pattern
//      • This screen uses tags + pattern to pick 1–3 rituals daily
// - Old AI plan (summary + exercises + grounding + reset + video)
//   is shown BELOW the new rituals section.
// - Uses GroqAIService.generateRelaxationSet() as before.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

import '../services/groq_service.dart'; // AI import
import 'discover.dart';
import 'personal_ai_diary.dart';
import 'insight_engine_screen.dart'; // for "Open AI Insight Engine" action

class RelaxationScreen extends StatefulWidget {
  const RelaxationScreen({Key? key}) : super(key: key);

  @override
  State<RelaxationScreen> createState() => _RelaxationScreenState();
}

class _RelaxationScreenState extends State<RelaxationScreen> {
  bool _loading = true;

  // OLD AI PLAN FIELDS
  String _aiSummary = "";
  List<String> _exercises = [];
  String _grounding = "";
  String _resetTask = "";
  String? _videoUrl;

  // NEW: Indian ritual picks for today (still computed, but UI always shows all)
  List<_IndianPractice> _indianPractices = [];

  @override
  void initState() {
    super.initState();
    _loadAI();
  }

  Future<void> _loadAI() async {
    setState(() {
      _loading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    final pattern = prefs.getString('latest_pattern_insight') ?? "";
    final suggestedRelax = prefs.getString('latest_suggested_relaxation');
    final tagsRaw = prefs.getStringList('latest_tags') ?? [];
    final video = prefs.getString('latest_suggested_video');

    _videoUrl = video;

    if (pattern.trim().isEmpty) {
      // No AI context yet → only Indian rituals + empty AI plan
      setState(() {
        _aiSummary = "";
        _exercises = [];
        _grounding = "";
        _resetTask = "";
        _indianPractices = [];
        _loading = false;
      });
      return;
    }

    // -------- NEW: compute daily Indian rituals from pattern + tags -------
    final indianPicks = _computeDailyIndianPractices(pattern, tagsRaw);

    // -------- OLD: fetch AI relaxation set (unchanged logic) -------------
    final ai = await GroqAIService.generateRelaxationSet(
      patternInsight: pattern,
      tags: tagsRaw,
      suggestedRelaxation: suggestedRelax,
    );

    setState(() {
      _aiSummary = ai["ai_summary"] ?? "";
      _exercises = List<String>.from(ai["exercises"] ?? []);
      _grounding = ai["grounding_script"] ?? "";
      _resetTask = ai["reset_task"] ?? "";
      _indianPractices = indianPicks;
      _loading = false;
    });
  }

  bool get _hasAIData =>
      _indianPractices.isNotEmpty || // new section counts as data
      _aiSummary.trim().isNotEmpty ||
      _exercises.isNotEmpty ||
      _grounding.trim().isNotEmpty ||
      _resetTask.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relaxation',
          style: TextStyle(color: Colors.greenAccent),
        ),
        backgroundColor: AppTheme.darkBase,
        actions: [
          IconButton(
            tooltip: 'Refresh AI plan',
            icon: const Icon(Icons.refresh, color: Colors.greenAccent),
            onPressed: _loadAI,
          ),
        ],
      ),
      body: AnimatedNeuralBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              )
            : (_hasAIData ? _buildAIContent(context) : _buildEmptyState()),
      ),
    );
  }

  // ------------------------------------------------------------
  // MAIN LAYOUTS
  // ------------------------------------------------------------

  Widget _buildAIContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // 1️⃣ TOP PRIORITY: Indian rituals (ALWAYS SHOWN, all of them)
        _buildIndianRitualsSection(context),
        const SizedBox(height: 18),

        // 2️⃣ BELOW: original AI relaxation plan
        _buildSummary(),     // heading: "Suggested in today's AI analysis"
        const SizedBox(height: 14),

        _buildExercises(),
        const SizedBox(height: 14),

        _buildGrounding(),
        const SizedBox(height: 14),

        _buildReset(),
        const SizedBox(height: 18),

        if (_videoUrl != null && _videoUrl!.trim().isNotEmpty) ...[
          _buildVideoTile(),
          const SizedBox(height: 18),
        ],

        _buildDiaryButton(),
      ],
    );
  }

  /// When there is no pattern insight yet (user never ran Insight Engine)
  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Still show Indian rituals even if AI has no pattern yet
        _buildIndianRitualsSection(context),
        const SizedBox(height: 18),
        GlassCard(
          opacity: 0.16,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No AI relaxation plan yet',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'To get personalised exercises, first:\n'
                  '1. Write a few entries in Personal AI Diary.\n'
                  '2. Run the AI Insight Engine.\n\n'
                  'Then tap the refresh icon here.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InsightEngineScreen()),
            );
          },
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Text('Open AI Insight Engine'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neuralBlue,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        _buildDiaryButton(),
      ],
    );
  }

  // ------------------------------------------------------------
  // NEW: INDIAN RITUALS SECTION (ALWAYS VISIBLE, SHOW ALL)
  // ------------------------------------------------------------

  Widget _buildIndianRitualsSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Small square-ish tiles
    final tileWidth = (width - 18 * 2 - 12) / 2; // 2 per row with some gap

    return GlassCard(
      opacity: 0.18,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ancient Indian Focus Rituals',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These rituals come from Indian discipline traditions.\n'
              'Pick 1–3 to try today — AI uses your mood later to highlight which ones matter most.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              // ✅ Always show ALL practices (no hiding)
              children: _allIndianPractices.map((p) {
                return SizedBox(
                  width: tileWidth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.example,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Informational only — not medical advice.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // OLD AI PLAN WIDGETS (NOW BELOW RITUALS)
  // ------------------------------------------------------------

  Widget _buildSummary() {
    return GlassCard(
      opacity: 0.16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ New heading above AI content
            const Text(
              "Suggested in today's AI analysis",
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _aiSummary.isEmpty
                  ? 'Write a few Personal AI Diary entries and run the AI Insight Engine to get personalised relaxation tips.'
                  : _aiSummary,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercises() {
    return GlassCard(
      opacity: 0.14,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personalised Exercises (AI)',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (_exercises.isEmpty)
              const Text(
                'No exercises yet — refresh after running the AI Insight Engine.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              )
            else
              ..._exercises.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $e',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrounding() {
    return GlassCard(
      opacity: 0.14,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grounding Script (30 sec)',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _grounding.isEmpty
                  ? 'Grounding guidance will appear here after AI generates your plan.'
                  : _grounding,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReset() {
    return GlassCard(
      opacity: 0.14,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Reset Task',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _resetTask.isEmpty
                  ? 'A tiny reset task will appear once AI has enough context.'
                  : _resetTask,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTile() {
    return GlassCard(
      opacity: 0.12,
      child: ListTile(
        title: const Text(
          'AI Suggested Video',
          style: TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          _videoUrl!,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: const Icon(Icons.open_in_new, color: Colors.white54),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiscoverScreen(insightVideoUrl: _videoUrl),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiaryButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PersonalAIDiaryScreen()),
        );
      },
      icon: const Icon(Icons.menu_book_outlined),
      label: const Text('Open Personal AI Diary'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPER: pick 1–3 Indian rituals based on tags + pattern
  // (Uses AI pipeline output: tags + pattern insight, but no extra API call)
  // NOTE: UI now ALWAYS shows all rituals; this is still used as "today’s picks"
  // in case you want to highlight or log it later.
  // ------------------------------------------------------------

  List<_IndianPractice> _computeDailyIndianPractices(
      String patternInsight, List<String> tagsRaw) {
    final tags = tagsRaw.map((t) => t.toLowerCase()).toList();
    final pattern = patternInsight.toLowerCase();

    bool has(String word) {
      return tags.any((t) => t.contains(word)) || pattern.contains(word);
    }

    final List<_IndianPractice> picked = [];

    void addById(String id) {
      final p = _allIndianPractices.firstWhere(
        (e) => e.id == id,
        orElse: () => _allIndianPractices.first,
      );
      if (!picked.any((x) => x.id == p.id)) picked.add(p);
    }

    // Stress / anxiety / overthinking → breath + focus + cold reset
    if (has('stress') || has('anxiety') || has('overthink')) {
      addById('anulom_vilom');
      addById('tratak');
      addById('cold_bath');
    }

    // Productivity / focus / exams / work
    if (has('productivity') || has('focus') || has('study')) {
      addById('brahma_muhurta');
      addById('surya_namaskar');
      addById('tapasya');
    }

    // Sleep / fatigue / tired
    if (has('sleep') || has('insomnia') || has('tired') || has('fatigue')) {
      addById('brahma_muhurta');
      addById('anulom_vilom');
      addById('surya_namaskar');
    }

    // Discipline / habits / routine
    if (has('discipline') || has('habits') || has('routine')) {
      addById('tapasya');
      addById('maun_vrat');
      addById('brahma_muhurta');
    }

    // If nothing matched, start with a default good trio
    if (picked.isEmpty) {
      picked
        ..add(_allIndianPractices
            .firstWhere((p) => p.id == 'brahma_muhurta'))
        ..add(_allIndianPractices.firstWhere((p) => p.id == 'anulom_vilom'))
        ..add(_allIndianPractices.firstWhere((p) => p.id == 'surya_namaskar'));
    }

    // Limit to max 3; if <3, fill with other random-ish ones based on day
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

    int idx = 0;
    while (picked.length < 3 && picked.length < _allIndianPractices.length) {
      final candidate =
          _allIndianPractices[(dayOfYear + idx) % _allIndianPractices.length];
      if (!picked.any((p) => p.id == candidate.id)) {
        picked.add(candidate);
      }
      idx++;
    }

    return picked.take(3).toList();
  }
}

// ------------------------------------------------------------
// DATA: Indian practices definitions
// ------------------------------------------------------------

class _IndianPractice {
  final String id;
  final String title;
  final String subtitle;
  final String example;

  const _IndianPractice({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.example,
  });
}

const List<_IndianPractice> _allIndianPractices = [
  _IndianPractice(
    id: 'brahma_muhurta',
    title: '1. Brahma Muhurta',
    subtitle: 'Wake up 1–1.5 hours before sunrise.\nHighest willpower & clarity.',
    example: 'Walk or meditate for 10 minutes.\nYour whole day changes.',
  ),
  _IndianPractice(
    id: 'cold_bath',
    title: '2. Cold Water Bath (Snān)',
    subtitle: 'Cold water resets the brain.\nInstant dopamine + discipline boost.',
    example: 'Finish your shower with 30 sec cold water every morning.',
  ),
  _IndianPractice(
    id: 'anulom_vilom',
    title: '3. Anulom–Vilom Prāṇāyāma',
    subtitle: 'Calm breath = controlled emotions.',
    example: 'Do 20 slow breaths before touching your phone → zero anxiety.',
  ),
  _IndianPractice(
    id: 'surya_namaskar',
    title: '4. Surya Namaskar',
    subtitle: 'Mind + body alignment.\nDestroys mental fog.',
    example: 'Do just 5 rounds daily → energy for the whole day.',
  ),
  _IndianPractice(
    id: 'maun_vrat',
    title: '5. Maun Vrat (Silence Practice)',
    subtitle: 'Silence for focus and inner strength.',
    example: '1 hour daily with no phone & no talking in the morning.',
  ),
  _IndianPractice(
    id: 'tapasya',
    title: '6. Tapasya',
    subtitle:
        'Discomfort training.\nDiscipline = choosing what is right over what is easy.',
    example: 'Try a 12-hour eating window or light fasting once a week.',
  ),
  _IndianPractice(
    id: 'tratak',
    title: '7. Tratak (Candle Focus)',
    subtitle:
        'Stare at a candle flame for 2–5 minutes.\nSharpens concentration.',
    example:
        'Use before study or work to kill overthinking.\nStop if eyes feel uncomfortable.',
  ),
];
