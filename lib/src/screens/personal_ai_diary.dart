// lib/src/screens/personal_ai_diary.dart
//
// Personal AI Diary
// - Flip-book style pages for past entries
// - AI analysis using GroqAIService (daily + pattern)
// - Local tag detection per entry
// - Saves latest pattern insight into SharedPreferences

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme.dart';
import '../services/groq_service.dart'; // ✅ ONLY import, no class GroqAIService here

class PersonalAIDiaryScreen extends StatefulWidget {
  const PersonalAIDiaryScreen({Key? key}) : super(key: key);

  @override
  State<PersonalAIDiaryScreen> createState() => _PersonalAIDiaryScreenState();
}

class _PersonalAIDiaryScreenState extends State<PersonalAIDiaryScreen>
    with SingleTickerProviderStateMixin {
  final _contentCtrl = TextEditingController();
  bool _isSaving = false;
  String? _todayInsight;
  List<String> _todaySuggestions = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // TAG EXTRACTION (local, fast, works offline)
  // ---------------------------------------------------------

  Map<String, dynamic> _extractTags(String raw) {
    final text = raw.toLowerCase();

    bool containsAny(List<String> words) =>
        words.any((w) => text.contains(w.toLowerCase()));

    final positiveWords = [
      'happy',
      'grateful',
      'excited',
      'calm',
      'peaceful',
      'good',
      'better',
      'relieved',
      'proud',
      'hopeful',
    ];
    final negativeWords = [
      'sad',
      'anxious',
      'anxiety',
      'stressed',
      'angry',
      'upset',
      'tired',
      'exhausted',
      'lonely',
      'depressed',
      'bad',
      'worried',
    ];

    int posScore =
        positiveWords.fold(0, (sum, w) => sum + (text.contains(w) ? 1 : 0));
    int negScore =
        negativeWords.fold(0, (sum, w) => sum + (text.contains(w) ? 1 : 0));

    String moodTag;
    if (posScore == 0 && negScore == 0) {
      moodTag = 'neutral/unknown';
    } else if (posScore > negScore) {
      moodTag = 'mostly positive';
    } else if (negScore > posScore) {
      moodTag = 'mostly negative';
    } else {
      moodTag = 'mixed';
    }

    final moneyWorry = containsAny([
      'money',
      'broke',
      'salary',
      'pay',
      'fees',
      'rent',
      'loan',
      'debt',
      'emi',
      'credit card',
      'spent too much',
      'shopping',
    ]);

    final socialConflict = containsAny([
      'fight',
      'argue',
      'argument',
      'conflict',
      'shouted',
      'ignored',
      'breakup',
      'broke up',
      'ghosted',
      'misunderstanding',
      'friendship problem',
      'relationship issue',
    ]);

    final healthComplaints = containsAny([
      'sick',
      'ill',
      'headache',
      'fever',
      'cold',
      'cough',
      'stomach',
      'pain',
      'doctor',
      'hospital',
      'clinic',
      'medication',
      'medicine',
    ]);

    final productivity = containsAny([
      'study',
      'studied',
      'assignment',
      'project',
      'work',
      'productive',
      'wasted time',
      'procrastinate',
      'deadline',
      'exam',
    ]);

    final sleepPatterns = containsAny([
      'sleep',
      'slept',
      'insomnia',
      'awake',
      'couldn\'t sleep',
      'late night',
      'all nighter',
      'overslept',
      'nightmare',
      'dream',
    ]);

    return {
      'moodTag': moodTag,
      'tagMoneyWorry': moneyWorry,
      'tagSocialConflict': socialConflict,
      'tagHealthComplaints': healthComplaints,
      'tagProductivity': productivity,
      'tagSleepPatterns': sleepPatterns,
    };
  }

  // ---------------------------------------------------------
  // APP SUGGESTIONS based on tags
  // ---------------------------------------------------------

  List<String> _buildAppSuggestions(Map<String, dynamic> tags) {
    final suggestions = <String>[];

    final mood = (tags['moodTag'] ?? '').toString();
    if (mood.contains('negative') || mood.contains('mixed')) {
      suggestions.add(
          'Play Calm Tap or do a breathing exercise in Relaxation.');
    }

    if (tags['tagMoneyWorry'] == true) {
      suggestions.add(
          'Open Discover and explore videos on budgeting or money stress relief.');
    }

    if (tags['tagSocialConflict'] == true) {
      suggestions.add(
          'Try Mind Tricks or a short relaxation before responding to people.');
    }

    if (tags['tagHealthComplaints'] == true) {
      suggestions.add(
          'Use Health Journey to log symptoms and medication for your doctor.');
    }

    if (tags['tagProductivity'] == true) {
      suggestions.add(
          'Play Mini Sudoku or Mind Tricks to reset your focus quickly.');
    }

    if (tags['tagSleepPatterns'] == true) {
      suggestions.add(
          'Use Relaxation micro-exercises and breathing at night to support sleep.');
    }

    if (suggestions.isEmpty) {
      suggestions.add(
          'Explore Games or Relaxation whenever you want a small mental break.');
    }

    return suggestions;
  }

  // ---------------------------------------------------------
  // SAVE ENTRY + CALL AI
  // ---------------------------------------------------------

  Future<void> _saveEntry() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save your diary.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tags = _extractTags(text);

      final pastEntries = await GroqAIService.fetchPastJournals(user.uid);

      final dailyInsight = await GroqAIService.analyzeJournal(text);

      final patternInsight =
          await GroqAIService.analyzeJournalWithHistory(text, pastEntries);

      await FirebaseFirestore.instance.collection('journals').add({
        'userId': user.uid,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'aiInsightDaily': dailyInsight,
        'moodTag': tags['moodTag'],
        'tagMoneyWorry': tags['tagMoneyWorry'],
        'tagSocialConflict': tags['tagSocialConflict'],
        'tagHealthComplaints': tags['tagHealthComplaints'],
        'tagProductivity': tags['tagProductivity'],
        'tagSleepPatterns': tags['tagSleepPatterns'],
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('latest_pattern_insight', patternInsight);

      final appSuggestions = _buildAppSuggestions(tags);

      setState(() {
        _todayInsight = dailyInsight;
        _todaySuggestions = appSuggestions;
        _isSaving = false;
        _contentCtrl.clear();
      });

      _showDailyInsightDialog(dailyInsight);
      _showPatternDialog(patternInsight);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diary saved with AI insights.')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _showDailyInsightDialog(String insight) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppTheme.cardDark,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 52, color: AppTheme.neonCyan),
              const SizedBox(height: 10),
              const Text(
                'Today\'s AI Insight',
                style: TextStyle(
                  color: AppTheme.neonCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                insight,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neuralBlue,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatternDialog(String insight) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppTheme.darkBase,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights, size: 52, color: AppTheme.neonPurple),
              const SizedBox(height: 10),
              const Text(
                'Pattern Insight',
                style: TextStyle(
                  color: AppTheme.neonPurple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                insight,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neuralBlue,
                      ),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('pattern_saved')
                              .add({
                            'userId': user.uid,
                            'insight': insight,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personal AI Diary',
          style: TextStyle(color: AppTheme.neonPurple),
        ),
        backgroundColor: AppTheme.darkBase,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.neonCyan,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.neonCyan,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Write'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Pages'),
          ],
        ),
      ),
      body: AnimatedNeuralBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWriteTab(),
            _buildPagesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildWriteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            opacity: 0.12,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Personal AI Diary',
                    style: TextStyle(
                      color: AppTheme.neonCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Write freely. Each entry is auto-tagged and analyzed by the AI Insight Engine.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _contentCtrl,
                maxLines: 12,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText:
                      'Dear me,\nToday I felt... (mood, people, studies, money, health, sleep...)',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _isSaving
              ? Column(
                  children: const [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Saving & analyzing your diary...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.psychology_outlined),
                    label: const Text('Save & Analyze'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neuralBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _saveEntry,
                  ),
                ),
          const SizedBox(height: 20),
          if (_todayInsight != null || _todaySuggestions.isNotEmpty)
            GlassCard(
              opacity: 0.12,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_todayInsight != null) ...[
                      Row(
                        children: const [
                          Icon(Icons.psychology,
                              color: AppTheme.neonCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Today\'s AI Insight',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _todayInsight!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_todaySuggestions.isNotEmpty) ...[
                      Row(
                        children: const [
                          Icon(Icons.sports_esports,
                              color: Colors.pinkAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'App Suggestions',
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._todaySuggestions.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // PAGES TAB – FLIPBOOK + NOTEBOOK UI
  // ---------------------------------------------------------

  Widget _buildPagesTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view your diary pages.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: GlassCard(
              opacity: 0.12,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Unable to load diary pages.\n'
                  'If Firestore shows an index link in the debug console, tap it once to create the index.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
            ),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: GlassCard(
              opacity: 0.12,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.menu_book_outlined,
                        size: 64, color: AppTheme.neonCyan),
                    SizedBox(height: 10),
                    Text(
                      'No diary pages yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Write your first entry in the "Write" tab. It will appear here like a flip-book.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final docs = snap.data!.docs;

        // ✅ Start from the latest page (last index)
        final pageController = PageController(initialPage: docs.length - 1);

        return Column(
          children: [
            const SizedBox(height: 12),
            Text(
              'Swipe or use arrows to flip through your pages.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  GlassCard(
                    opacity: 0.14,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: docs.length,
                        itemBuilder: (ctx, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          // ✅ include doc id inside tags so page has id available
                          final dataWithId = {
                            ...data,
                            'id': doc.id,
                          };
                          final content =
                              (dataWithId['content'] ?? '').toString();
                          final aiInsight =
                              (dataWithId['aiInsightDaily'] ?? '').toString();
                          final ts = dataWithId['timestamp'];
                          final date = ts is Timestamp ? ts.toDate() : DateTime.now();

                          final pageNumber = index + 1;
                          final totalPages = docs.length;

                          final page = _buildDiaryPage(
                            content: content,
                            aiInsight: aiInsight,
                            dateTime: date,
                            pageNumber: pageNumber,
                            totalPages: totalPages,
                            tags: dataWithId,
                          );

                          // 🎞️ Flipbook-style slight 3D page turn
                          return AnimatedBuilder(
                            animation: pageController,
                            builder: (context, child) {
                              double value = 0;
                              if (pageController.position.hasContentDimensions) {
                                value =
                                    (pageController.page ?? 0) - index.toDouble();
                              } else {
                                value = (pageController.initialPage - index)
                                    .toDouble();
                              }
                              value = value.clamp(-1.0, 1.0);

                              final tilt = 0.20 * value;
                              final scale = 1 - (value.abs() * 0.04);

                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(tilt)
                                  ..scale(scale),
                                child: child,
                              );
                            },
                            child: page,
                          );
                        },
                      ),
                    ),
                  ),

                  // ⬅ LEFT ARROW
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () {
                          final current =
                              (pageController.page ?? docs.length - 1).round();
                          final prev =
                              (current - 1).clamp(0, docs.length - 1);
                          if (prev != current) {
                            pageController.animateToPage(
                              prev,
                              duration:
                                  const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  // ➡ RIGHT ARROW
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () {
                          final current =
                              (pageController.page ?? docs.length - 1).round();
                          final next =
                              (current + 1).clamp(0, docs.length - 1);
                          if (next != current) {
                            pageController.animateToPage(
                              next,
                              duration:
                                  const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // SINGLE NOTEBOOK PAGE WITH STICKY TAGS
  // ---------------------------------------------------------

  Widget _buildTagSticker(
    String label, {
    Color color = const Color(0xFFFFF3C2),
    double angle = -0.10,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.brown.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDiaryPage({
    required String content,
    required String aiInsight,
    required DateTime dateTime,
    required int pageNumber,
    required int totalPages,
    required Map<String, dynamic> tags,
  }) {
    final dateStr = DateFormat('MMM dd, yyyy').format(dateTime);
    final timeStr = DateFormat('hh:mm a').format(dateTime);
    final moodTag = (tags['moodTag'] ?? 'neutral/unknown').toString();

    // Allow edit for 48 hours only
    final canEdit = DateTime.now().difference(dateTime).inHours < 48;

    final stickers = <Widget>[];

    // Mood sticker (primary)
    stickers.add(
      _buildTagSticker(
        'Mood: $moodTag',
        color: const Color(0xFFCCE7FF),
        angle: -0.06,
      ),
    );

    if (tags['tagMoneyWorry'] == true) {
      stickers.add(
        _buildTagSticker(
          'Money worry',
          color: const Color(0xFFFFF3C2),
          angle: 0.04,
        ),
      );
    }
    if (tags['tagSocialConflict'] == true) {
      stickers.add(
        _buildTagSticker(
          'Social conflict',
          color: const Color(0xFFFFD6E5),
          angle: -0.03,
        ),
      );
    }
    if (tags['tagHealthComplaints'] == true) {
      stickers.add(
        _buildTagSticker(
          'Health',
          color: const Color(0xFFCFFFE3),
          angle: 0.05,
        ),
      );
    }
    if (tags['tagProductivity'] == true) {
      stickers.add(
        _buildTagSticker(
          'Productivity',
          color: const Color(0xFFD9D2FF),
          angle: -0.02,
        ),
      );
    }
    if (tags['tagSleepPatterns'] == true) {
      stickers.add(
        _buildTagSticker(
          'Sleep',
          color: const Color(0xFFFFE0F0),
          angle: 0.02,
        ),
      );
    }

    // per-page deleting notifier (keeps UI responsive)
    final ValueNotifier<bool> isDeleting = ValueNotifier<bool>(false);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F0E8), // notebook paper
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: _NotebookPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EDIT + DELETE row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: canEdit
                                ? Colors.brown.shade700
                                : Colors.grey),
                        onPressed: () {
                          if (!canEdit) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppTheme.darkBase,
                                title: const Text("Editing Disabled",
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  "You can edit an entry only for 48 hours.\nThis prevents fake data manipulation.",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("OK",
                                        style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          _showEditDialog(tags['id'] as String, content);
                        },
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: isDeleting,
                        builder: (context, deleting, _) {
                          return IconButton(
                            icon: deleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.delete, color: Colors.red.shade400),
                            onPressed: deleting
                                ? null
                                : () => _confirmDeletePage(
                                      tags['id'] as String,
                                      isDeleting,
                                      content,
                                    ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Date & time row
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$dateStr • $timeStr',
                        style: TextStyle(
                          color: Colors.brown.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Page $pageNumber of $totalPages',
                        style: TextStyle(
                          color: Colors.brown.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Sticky tag row
                  if (stickers.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: stickers),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Main diary content on lined paper
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.only(right: 6, bottom: 6, top: 2),
                      child: Text(
                        content,
                        style: TextStyle(
                          color: Colors.brown.shade900,
                          fontSize: 14,
                          height: 1.45, // tuned to match line spacing
                        ),
                      ),
                    ),
                  ),
                  if (aiInsight.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'AI note for this page:',
                      style: TextStyle(
                        color: AppTheme.neuralBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      padding:
                          const EdgeInsets.only(right: 6, bottom: 2, top: 2),
                      child: Text(
                        aiInsight,
                        style: TextStyle(
                          color: Colors.brown.shade800,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // DELETE + ANIMATION + EDIT HANDLERS
  // ---------------------------------------------------------

  Future<void> _confirmDeletePage(
    String docId,
    ValueNotifier<bool> isDeleting,
    String content,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBase,
        title: const Text("Delete Entry?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this diary page?\nThis action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok != true) return;

    isDeleting.value = true;

    try {
      // play strike-through overlay animation
      await _playStrikeOutAnimation(content);

      // delete from firestore
      await FirebaseFirestore.instance.collection('journals').doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diary page deleted.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> _playStrikeOutAnimation(String content) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(builder: (context) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Container(
            alignment: Alignment.center,
            color: Colors.black.withOpacity(0.0),
            child: _StrikeOverlay(text: content),
          ),
        ),
      );
    });

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 850));
    entry.remove();
  }

  Future<void> _showEditDialog(String docId, String originalText) async {
    final editCtrl = TextEditingController(text: originalText);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBase,
        title: const Text('Edit Entry', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: editCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Edit your entry',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.blueAccent)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text('Save', style: TextStyle(color: Colors.greenAccent)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final newText = editCtrl.text.trim();
    if (newText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry cannot be empty.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('journals').doc(docId).update({
        'content': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  // ---------------------------------------------------------
  // SINGLE NOTEBOOK PAINTER
  // ---------------------------------------------------------
}

class _StrikeOverlay extends StatefulWidget {
  final String text;
  const _StrikeOverlay({Key? key, required this.text}) : super(key: key);

  @override
  State<_StrikeOverlay> createState() => _StrikeOverlayState();
}

class _StrikeOverlayState extends State<_StrikeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctr;
  late final Animation<double> _lineProgress;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _lineProgress = CurvedAnimation(parent: _ctr, curve: Curves.easeInOut);
    _fade = CurvedAnimation(parent: _ctr, curve: Curves.easeOut);
    _ctr.forward();
  }

  @override
  void dispose() {
    _ctr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_fade),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _lineProgress,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _StrikePainter(progress: _lineProgress.value),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 12,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: const Offset(0, 0.6),
                ).animate(CurvedAnimation(parent: _ctr, curve: Curves.easeIn)),
                child: const Icon(Icons.restore_from_trash, size: 42, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  final double progress;
  _StrikePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final start = Offset(size.width * 0.1, size.height * 0.5);
    final end = Offset(size.width * 0.9, size.height * 0.5);

    final cur = Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;
    canvas.drawLine(start, cur, paint);
  }

  @override
  bool shouldRepaint(covariant _StrikePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------
// Custom painter to draw notebook-style horizontal lines
// ---------------------------------------------------------

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal rules
    final linePaint = Paint()
      ..color = const Color(0xFFCFB8A4).withOpacity(0.40)
      ..strokeWidth = 1;

    const double lineHeight = 22.0;
    const double contentTop = 86.0; // first line
    const double bottomPadding = 24.0;

    for (double y = contentTop; y < size.height - bottomPadding; y += lineHeight) {
      canvas.drawLine(
        Offset(20, y),
        Offset(size.width - 20, y),
        linePaint,
      );
    }

    // Left margin line
    final marginPaint = Paint()
      ..color = const Color(0xFFDA8A8A).withOpacity(0.8)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(48, contentTop - 10),
      Offset(48, size.height - bottomPadding),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
