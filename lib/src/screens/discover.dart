// lib/src/screens/discover.dart
// DISCOVER SCREEN v3 (updated)
// - Shows AI-selected video for this analysis
// - Keeps decoy YouTube + news tiles
// - NEW: "You can also search on YouTube for ..." using AI titles
//   → opens YouTube search with the exact AI title text
// - NEW: Shows an extra "Also try" quick card when history/pattern titles exist
//   (keeps everything safe and external; does not embed videos)

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class DiscoverScreen extends StatefulWidget {
  final String? insightVideoUrl;
  final String? insightVideoTitle;

  const DiscoverScreen({
    Key? key,
    this.insightVideoUrl,
    this.insightVideoTitle,
  }) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _loadingPrefs = true;

  String _discoverTip = '';

  String _todayVideoTitle = '';
  String _historyVideoTitle = '';
  String _patternVideoTitle = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _discoverTip = prefs.getString('latest_discover_tip') ??
            "I’ve lined up a few videos based on your recent mood.";

        _todayVideoTitle = prefs.getString('latest_today_video_title') ?? '';
        _historyVideoTitle =
            prefs.getString('latest_history_video_title') ?? '';
        _patternVideoTitle =
            prefs.getString('latest_suggested_video_title') ?? '';

        _loadingPrefs = false;
      });
    } catch (_) {
      setState(() {
        _loadingPrefs = false;
      });
    }
  }

  // -------------------------------------------------
  // Helpers to open URLs
  // -------------------------------------------------

  // Open a URL in the device's browser (Chrome if it's the default)
  Future<void> _openInChrome(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore
    }
  }

  // Open a YouTube video specifically in the YouTube app (fallback to web)
  Future<void> _openInYouTubeApp(String url) async {
    if (url.trim().isEmpty) return;

    // Try to extract video id and open via youtube:// if possible
    String? videoId;
    try {
      final parsed = Uri.tryParse(url);
      if (parsed != null) {
        // youtube.com/watch?v=ID
        videoId = parsed.queryParameters['v'];
        // youtu.be/ID
        if (videoId == null && parsed.host.contains('youtu.be')) {
          videoId = parsed.pathSegments.isNotEmpty ? parsed.pathSegments.last : null;
        }
      }
    } catch (_) {}

    final appUri = videoId != null
        ? Uri.parse('youtube://www.youtube.com/watch?v=$videoId')
        : null;

    // Try opening in YouTube app first
    if (appUri != null) {
      try {
        final ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // fallthrough to open web url
      }
    }

    // Fallback: open the web URL in browser (Chrome)
    await _openInChrome(url);
  }

  // Open a YouTube search page in the browser (Chrome)
  Future<void> _openYoutubeSearchChrome(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final url = "https://www.youtube.com/results?search_query=$encoded";
    await _openInChrome(url);
  }

  // Small helper to render a compact "Also try" suggestion card (search-only)
  Widget _alsoTryCard({required String label, required String query}) {
    return GestureDetector(
      onTap: () => _openYoutubeSearchChrome(query),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------
  // BUILD
  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasInsightVideo = (widget.insightVideoUrl ?? '').isNotEmpty;

    // Title for the main hero card:
    final heroTitle =
        (widget.insightVideoTitle ?? '').trim().isNotEmpty
            ? widget.insightVideoTitle!.trim()
            : "AI picked a video topic for you";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: _loadingPrefs
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerCard(),
                    const SizedBox(height: 16),
                    if (hasInsightVideo) _heroInsightVideoCard(heroTitle),
                    if (hasInsightVideo) const SizedBox(height: 12),

                    // NEW: Secondary quick suggestions (history & pattern) — search-only external items
                    if ((_historyVideoTitle).trim().isNotEmpty ||
                        (_patternVideoTitle).trim().isNotEmpty) ...[
                      GlassCard(
                        opacity: 0.14,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Also try (external suggestions)',
                                style: TextStyle(
                                  color: AppTheme.neonPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_historyVideoTitle.trim().isNotEmpty)
                                _alsoTryCard(
                                  label:
                                      'History suggestion: "${_historyVideoTitle.trim()}"',
                                  query: _historyVideoTitle.trim(),
                                ),
                              if (_historyVideoTitle.trim().isNotEmpty)
                                const SizedBox(height: 8),
                              if (_patternVideoTitle.trim().isNotEmpty)
                                _alsoTryCard(
                                  label:
                                      'Pattern suggestion: "${_patternVideoTitle.trim()}"',
                                  query: _patternVideoTitle.trim(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _aiSearchTopicsCard(),
                    const SizedBox(height: 16),
                    _videoDecoySection(),
                    const SizedBox(height: 16),
                    _newsDecoySection(),
                  ],
                ),
              ),
      ),
    );
  }

  // ----------------- HEADER CARD -----------------

  Widget _headerCard() {
    return GlassCard(
      opacity: 0.16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _discoverTip.isEmpty
              ? 'Videos and articles here are meant to gently support your mood and focus.\nPick one when you have a few minutes.'
              : _discoverTip,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // ----------------- HERO AI VIDEO CARD -----------------

  Widget _heroInsightVideoCard(String heroTitle) {
    final url = widget.insightVideoUrl ?? '';
    final titleForSearch =
        (widget.insightVideoTitle ?? '').trim().isNotEmpty
            ? widget.insightVideoTitle!.trim()
            : heroTitle;

    return GlassCard(
      opacity: 0.20,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI-picked video for this analysis",
              style: TextStyle(
                color: AppTheme.neonCyan,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              heroTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      // THIS opens in the YouTube app (if installed). Fallback -> browser.
                      onPressed: () => _openInYouTubeApp(url),
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Open in YouTube'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    // Search should open in browser (Chrome)
                    onPressed: () => _openYoutubeSearchChrome(titleForSearch),
                    icon: const Icon(Icons.search),
                    label: const Text('Search similar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(120, 44),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // NEW: search using the SAME TITLE in YouTube search bar (opens browser)
            TextButton.icon(
              onPressed: () => _openYoutubeSearchChrome(titleForSearch),
              icon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.greenAccent,
              ),
              label: Text(
                'You can also search on YouTube for: "$titleForSearch"',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- AI SEARCH TOPICS (TODAY + PATTERN) -----------------

  Widget _aiSearchTopicsCard() {
    final List<Widget> chips = [];

    if (_todayVideoTitle.trim().isNotEmpty) {
      chips.add(_searchChip(
        label: 'Today: "${_todayVideoTitle.trim()}"',
        onTap: () => _openYoutubeSearchChrome(_todayVideoTitle),
      ));
    }

    if (_historyVideoTitle.trim().isNotEmpty) {
      chips.add(_searchChip(
        label: 'History: "${_historyVideoTitle.trim()}"',
        onTap: () => _openYoutubeSearchChrome(_historyVideoTitle),
      ));
    }

    if (_patternVideoTitle.trim().isNotEmpty) {
      chips.add(_searchChip(
        label: 'Pattern: "${_patternVideoTitle.trim()}"',
        onTap: () => _openYoutubeSearchChrome(_patternVideoTitle),
      ));
    }

    if (chips.isEmpty) {
      return GlassCard(
        opacity: 0.14,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'AI will show extra YouTube searches here after you run an analysis in the Insight Engine.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return GlassCard(
      opacity: 0.14,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can also search these topics on YouTube',
              style: TextStyle(
                color: AppTheme.neonPurple,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white10,
          border: Border.all(color: Colors.white24, width: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new,
              size: 14,
              color: Colors.greenAccent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- VIDEO DECOYS SECTION -----------------

  final List<Map<String, String>> _videoDecoys = const [
    {
      "title": "Rainy night lofi beats",
      "description": "Soft lofi mix to zone out and breathe.",
      "url": "https://www.youtube.com/watch?v=2OEL4P1Rz04"
    },
    {
      "title": "Calm breathing for stress",
      "description": "Guided breathing reset in under 10 minutes.",
      "url": "https://www.youtube.com/watch?v=j1eYQBrZ7dA"
    },
    {
      "title": "Piano for deep focus",
      "description": "Instrumental track for studying or reading.",
      "url": "https://www.youtube.com/watch?v=lFcSrYw-ARY"
    },
    {
      "title": "Box breathing walkthrough",
      "description": "Slow 4-4-4 breathing practice.",
      "url": "https://www.youtube.com/watch?v=6p_yaNFSYao"
    },
    {
      "title": "Guided mini body scan",
      "description": "Relax your shoulders, jaw and face.",
      "url": "https://www.youtube.com/watch?v=oHBx9nJpFQs"
    },
  ];

  Widget _videoDecoySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Short calming videos',
          style: TextStyle(
            color: AppTheme.neonCyan,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: _videoDecoys.map((v) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                // DECOVY LINKS open in Chrome (not youtube app)
                onTap: () => _openInChrome(v['url'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black26,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              v['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v['description'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ----------------- NEWS DECOYS SECTION -----------------

  final List<Map<String, String>> _newsDecoys = const [
    {
      "title": "Mental health basics",
      "source": "Psychology Today",
      "url": "https://www.psychologytoday.com/"
    },
    {
      "title": "Stress & body connection",
      "source": "Healthline",
      "url": "https://www.healthline.com/"
    },
    {
      "title": "Wellness research & updates",
      "source": "WebMD",
      "url": "https://www.webmd.com/"
    },
    {
      "title": "Health & lifestyle stories",
      "source": "NYTimes Health",
      "url": "https://www.nytimes.com/section/health"
    },
    {
      "title": "Latest medical news",
      "source": "Medical News Today",
      "url": "https://www.medicalnewstoday.com/"
    },
  ];

  Widget _newsDecoySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Articles & mental health reading',
          style: TextStyle(
            color: AppTheme.neonPurple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: _newsDecoys.map((n) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                // News open in Chrome
                onTap: () => _openInChrome(n['url'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        color: Colors.lightBlueAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n['source'] ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
