// lib/src/widgets/ai_recommendation_header.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import 'glass_card.dart';

class AiRecommendationHeader extends StatefulWidget {
  final String contextLabel; // e.g. "relaxation", "games"

  const AiRecommendationHeader({
    Key? key,
    required this.contextLabel,
  }) : super(key: key);

  @override
  State<AiRecommendationHeader> createState() => _AiRecommendationHeaderState();
}

class _AiRecommendationHeaderState extends State<AiRecommendationHeader> {
  String? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('latest_pattern_insight');
    if (!mounted) return;
    setState(() => _summary = text);
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null || _summary!.trim().isEmpty) {
      return GlassCard(
        opacity: 0.14,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'According to your recent AI analysis, this section '
            '(${widget.contextLabel}) can help.\n'
            'Write in your Personal AI Diary to get more tailored suggestions.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }

    final short = _summary!.length > 260
        ? _summary!.substring(0, 260) + '...'
        : _summary!;

    return GlassCard(
      opacity: 0.14,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'According to your recent AI analysis…',
              style: TextStyle(
                color: AppTheme.neonCyan,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              short,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
