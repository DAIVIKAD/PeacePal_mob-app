// lib/src/screens/dashboard.dart
// -------------------------------------------------------
// PEACEPAL SUPER-DASHBOARD
// AI Insight Engine | Weekly Wellness Score | Crisis Alerts
// -------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

import '../services/groq_service.dart';

import 'mood_chart.dart';
import 'insight_engine_screen.dart';
import 'discover.dart';
import 'relaxation.dart';
import 'games.dart';
import 'notifications.dart';
import 'healthJourney.dart';
import 'health_stats.dart';
import 'meds.dart';
import 'reminders.dart';
import 'profile.dart';
import 'personal_ai_diary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  String _currentDate = '';
  String _dailyQuote = '';
  int _notificationCount = 0;
  double _weeklyScore = 0.0;
  bool _loadingQuote = false;
  bool _loadingScore = false;
  String _crisisTrigger = "";

  late AnimationController _orb;

  @override
  void initState() {
    super.initState();
    _currentDate = DateFormat('EEEE, MMMM dd').format(DateTime.now());

    _orb = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _loadNotifications();
    _loadDailyQuote();
    _loadWeeklyScore();
    _detectCrisisTriggers();
  }

  @override
  void dispose() {
    _orb.dispose();
    super.dispose();
  }

  // ============================================================
  // NOTIFICATIONS BADGE
  // ============================================================
  Future<void> _loadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: user.uid)
        .where('completed', isEqualTo: false)
        .get();

    if (!mounted) return;
    setState(() => _notificationCount = snap.docs.length);
  }

  // ============================================================
  // DAILY QUOTE
  // ============================================================
  Future<void> _loadDailyQuote() async {
    if (!mounted) return;
    setState(() => _loadingQuote = true);

    try {
      final q = await GroqAIService.generateDailyQuote();
      if (!mounted) return;
      setState(() => _dailyQuote = q);
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  // ============================================================
  // WEEKLY WELLNESS SCORE
  // ============================================================
  Future<void> _loadWeeklyScore() async {
    if (!mounted) return;

    setState(() => _loadingScore = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Recent journals
      final journalSnap = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      // Recent moods
      final moods = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      int moodScore = 0;
      for (var d in moods.docs) {
        final val = d.data()['value'] ?? 3;
        final num? safeNum =
            (val is num) ? val : num.tryParse(val.toString());
        moodScore += (safeNum ?? 3).toInt();
      }

      int emotionalFlags = 0;
      for (var e in journalSnap.docs) {
        final text = (e.data()['content'] ?? '').toString().toLowerCase();
        if (text.contains("tired") ||
            text.contains("worthless") ||
            text.contains("angry") ||
            text.contains("alone")) {
          emotionalFlags++;
        }
      }

      final double rawScore =
          (moodScore * 3 + (20 - emotionalFlags) * 2).toDouble();
      final double finalScore = rawScore.clamp(0, 100);

      if (!mounted) return;
      setState(() => _weeklyScore = finalScore);
    } catch (e) {
      setState(() => _weeklyScore = 0.0);
    } finally {
      if (mounted) setState(() => _loadingScore = false);
    }
  }

  // ============================================================
  // CRISIS WORD DETECTION
  // ============================================================
  Future<void> _detectCrisisTriggers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final journals = await FirebaseFirestore.instance
        .collection('journals')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    int negativePatterns = 0;
    for (var d in journals.docs) {
      final text = (d.data()['content'] ?? '').toString().toLowerCase();
      if (text.contains("fight") ||
          text.contains("argument") ||
          text.contains("anxious") ||
          text.contains("fear") ||
          text.contains("money") ||
          text.contains("sad")) {
        negativePatterns++;
      }
    }

    if (negativePatterns >= 3) {
      if (!mounted) return;
      setState(() {
        _crisisTrigger =
            "⚠️ AI detected repeated stress/conflict patterns.";
      });
    }
  }
  // ============================================================
  // QUICK MOOD ENTRY (emoji bottom sheet)
  // ============================================================
  Future<void> _openMoodQuickEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to log mood.')),
      );
      return;
    }

    final moodOptions = [
      {'emoji': '😄', 'label': 'Very Happy', 'value': 5},
      {'emoji': '🙂', 'label': 'Good', 'value': 4},
      {'emoji': '😐', 'label': 'Okay', 'value': 3},
      {'emoji': '☹️', 'label': 'Low', 'value': 2},
      {'emoji': '😢', 'label': 'Very Low', 'value': 1},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkBase.withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Log your mood for today',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 10,
                children: moodOptions.map((m) {
                  final emoji = m['emoji'] as String;
                  final label = m['label'] as String;
                  final value = m['value'] as int;

                  return InkWell(
                    onTap: () async {
                      Navigator.of(ctx).pop();

                      final now = DateTime.now();
                      final dateKey =
                          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                      await FirebaseFirestore.instance
                          .collection('moods')
                          .add({
                        'userId': user.uid,
                        'emoji': emoji,
                        'label': label,
                        'value': value,
                        'timestamp': FieldValue.serverTimestamp(),
                        'date': dateKey, // ✅ REQUIRED for mood chart
                      });

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Mood logged: $emoji $label')),
                      );

                      _loadWeeklyScore(); // refresh score
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),
              const Text(
                'You can see trends in the mood chart on the dashboard.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedNeuralBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadNotifications();
              await _loadWeeklyScore();
              await _loadDailyQuote();
              await _detectCrisisTriggers();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildAppBar(),
                  const SizedBox(height: 10),

                  _buildDate(),
                  const SizedBox(height: 20),

                  _buildDailyQuoteCard(),
                  const SizedBox(height: 20),

                  _buildWeeklyScoreCard(),

                  if (_crisisTrigger.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCrisisAlert(),
                  ],

                  const SizedBox(height: 20),
                  _buildMoodSphere(),

                  const SizedBox(height: 20),
                  _buildAIInsightEngineTile(),

                  const SizedBox(height: 20),
                  _buildMoodTrends(),

                  const SizedBox(height: 20),
                  _buildMainMenu(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- APP BAR + HEADER ------------------
  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShaderMask(
          shaderCallback: (b) => AppTheme.neuralGradient.createShader(b),
          child: const Text(
            "PeacePal",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppTheme.neonCyan),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: AppTheme.neonCyan),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDate() => Text(
        _currentDate,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      );

  Widget _buildDailyQuoteCard() {
    return GlassCard(
      opacity: 0.12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loadingQuote
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.neonCyan),
              )
            : Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppTheme.neonCyan, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _dailyQuote,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWeeklyScoreCard() {
    return GlassCard(
      opacity: 0.12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loadingScore
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.neonCyan),
              )
            : Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Weekly AI Wellness Score: ${_weeklyScore.toStringAsFixed(1)} / 100",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCrisisAlert() {
    return GlassCard(
      opacity: 0.12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _crisisTrigger,
          style: const TextStyle(color: Colors.redAccent, fontSize: 15),
        ),
      ),
    );
  }

  // ---------------- MOOD SPHERE ------------------
  Widget _buildMoodSphere() {
    return GlassCard(
      opacity: 0.12,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "How are you feeling today?",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _openMoodQuickEntry,
            child: AnimatedBuilder(
              animation: _orb,
              builder: (_, __) => Transform.scale(
                scale: 0.92 + (_orb.value * 0.1),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.neuralGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonCyan.withOpacity(0.4),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sentiment_satisfied_alt,
                      size: 60, color: Colors.white),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            "Tap the orb to log today's mood.",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  // ---------------- AI INSIGHT ENGINE TILE ------------------
  Widget _buildAIInsightEngineTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InsightEngineScreen()),
        );
      },
      child: GlassCard(
        opacity: 0.12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.neonCyan.withOpacity(0.2),
                ),
                child: const Icon(Icons.psychology_outlined,
                    color: AppTheme.neonCyan, size: 28),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  "AI Insight Engine\nAnalyze emotional patterns, relationships, money stress & more",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- MOOD TRENDS CHART ------------------
  Widget _buildMoodTrends() {
    return GlassCard(
      opacity: 0.12,
      child: const SizedBox(
        height: 220,
        child: MoodTrendsChart(),
      ),
    );
  }

  // ---------------- MAIN MENU ------------------
  Widget _buildMainMenu() {
    return Column(
      children: [
        _menuTile(
          "Personal AI Diary",
          Icons.book_outlined,
          AppTheme.neonPurple,
          () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PersonalAIDiaryScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Discover",
          Icons.explore_outlined,
          AppTheme.neonCyan,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiscoverScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Relaxation",
          Icons.self_improvement,
          Colors.greenAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RelaxationScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Games",
          Icons.games_outlined,
          Colors.pinkAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GamesScreen()),
          ),
        ),
        const SizedBox(height: 25),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Medication & Health",
            style: TextStyle(
              color: Colors.orangeAccent.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),

        _menuTile(
          "Reminders",
          Icons.alarm,
          Colors.orangeAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Search Meds",
          Icons.search,
          Colors.blueAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchMedsScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Health Journey",
          Icons.health_and_safety,
          Colors.tealAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyMedicationsScreen()),
          ),
        ),
        const SizedBox(height: 15),

        _menuTile(
          "Health Stats",
          Icons.query_stats,
          AppTheme.neonCyan,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HealthStatsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _menuTile(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        opacity: 0.08,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
