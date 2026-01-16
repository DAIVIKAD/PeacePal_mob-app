// lib/src/screens/health_stats.dart
import 'dart:math';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

import '../theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../services/groq_service.dart';

class HealthStatsScreen extends StatelessWidget {
  const HealthStatsScreen({Key? key}) : super(key: key);

  // ---------- FILE SAVE HELPER (like insight engine) ----------

  String _safeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
  }

  Future<String> _saveHealthReport(String filename, String contents) async {
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

   Future<void> _downloadHealthReport(
    BuildContext context, {
    required String aiText,
    required List<_HealthLog> completedEntries,
    required List<_MonthStat> monthlyStats,
    required int totalEvents,
    required int completedCount,
    required String recoverySummary,
    required String monthSummaryDetail,
    required int sickDaysThisMonth,
  }) async {
    try {
      final rows = <List<dynamic>>[];

      // 5 fixed columns so everything lines up:
      // [Section, Item, Detail 1, Detail 2, Detail 3]
      rows.add(["Section", "Item", "Detail 1", "Detail 2", "Detail 3"]);

      // ---- META ----
      rows.add([
        "META",
        "Generated At",
        DateTime.now().toIso8601String(),
        "",
        ""
      ]);

      // ---- COUNTS ----
      rows.add(["COUNTS", "Total health events", totalEvents, "", ""]);
      rows.add([
        "COUNTS",
        "Completed illnesses (recovered)",
        completedCount,
        "",
        ""
      ]);
      rows.add([
        "COUNTS",
        "Sick days this month",
        sickDaysThisMonth,
        "",
        ""
      ]);

      // ---- RECOVERY SUMMARY (HUMAN TEXT) ----
      rows.add([
        "SUMMARY",
        "Recovery overview",
        recoverySummary,
        "",
        ""
      ]);
      if (monthSummaryDetail.isNotEmpty) {
        rows.add([
          "SUMMARY",
          "Heaviest month",
          monthSummaryDetail,
          "",
          ""
        ]);
      }

      // ---- SICK DAYS PER MONTH (TABLE) ----
      rows.add(["", "", "", "", ""]);
      rows.add(["MONTH_TABLE", "Header", "Month", "Sick days", ""]);
      if (monthlyStats.isEmpty) {
        rows.add(["MONTH_TABLE", "Row", "No data yet", "0", ""]);
      } else {
        for (final m in monthlyStats) {
          rows.add([
            "MONTH_TABLE",
            "Row",
            m.label,
            m.days,
            "",
          ]);
        }
      }

      // ---- COMPLETED ILLNESSES (TABLE) ----
      rows.add(["", "", "", "", ""]);
      rows.add([
        "ILLNESS_TABLE",
        "Header",
        "Illness name",
        "Start → End",
        "Days sick"
      ]);

      String fmt(DateTime? d) {
        if (d == null) return '';
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }

      if (completedEntries.isEmpty) {
        rows.add([
          "ILLNESS_TABLE",
          "Row",
          "No completed illnesses yet",
          "",
          ""
        ]);
      } else {
        for (int i = 0; i < completedEntries.length; i++) {
          final e = completedEntries[i];
          rows.add([
            "ILLNESS_TABLE",
            "Row #${i + 1}",
            e.illnessName,
            '${fmt(e.startDate)} → ${fmt(e.endDate)}',
            '${e.recoveredDays ?? ''}',
          ]);
        }
      }

      // ---- AI TEXT (split into lines) ----
      rows.add(["", "", "", "", ""]);
      rows.add(["AI_SUMMARY", "Header", "AI-generated health overview", "", ""]);

      final lines = aiText
          .replaceAll('\r', '')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final line in lines) {
        rows.add(["AI_SUMMARY", "Line", line, "", ""]);
      }

      // Convert to CSV
      final csv = const ListToCsvConverter().convert(rows);
      final filename =
          "PeacePal_Health_Report_${DateTime.now().millisecondsSinceEpoch}.csv";

      final path = await _saveHealthReport(filename, csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Saved health report to:\n$path")),
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

  // ---------- AI DIALOG ----------

  Future<void> _showHealthAiDialog(
    BuildContext context, {
    required List<_HealthLog> completedEntries,
    required List<_MonthStat> monthlyStats,
    required int totalEvents,
    required int completedCount,
    required String recoverySummary,
    required String monthSummaryDetail,
    required int sickDaysThisMonth,
  }) async {
    String? aiText;
    bool isLoading = true;
    bool requested = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // Trigger AI call only once
            if (!requested) {
              requested = true;
              Future(() async {
                final illnesses = completedEntries.map((e) {
                  String fmt(DateTime? d) {
                    if (d == null) return '';
                    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  }

                  return {
                    "name": e.illnessName,
                    "days": e.recoveredDays ?? 0,
                    "start": fmt(e.startDate),
                    "end": fmt(e.endDate),
                  };
                }).toList();

                final months = monthlyStats
                    .map((m) => {"month": m.label, "days": m.days})
                    .toList();

                final text = await GroqAIService.analyzeHealthTimeline(
                  illnesses: illnesses,
                  months: months,
                );

                setState(() {
                  aiText = text;
                  isLoading = false;
                });
              });
            }

            return AlertDialog(
              backgroundColor: AppTheme.darkBase.withOpacity(0.96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'AI Health Overview',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: isLoading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(height: 12),
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.tealAccent,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Reading your health logs…',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This summary is based only on what you logged in PeacePal.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (aiText != null)
                              Text(
                                aiText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              actions: [
                if (!isLoading && aiText != null)
                  TextButton.icon(
                    onPressed: () => _downloadHealthReport(
                      context,
                      aiText: aiText!,
                      completedEntries: completedEntries,
                      monthlyStats: monthlyStats,
                      totalEvents: totalEvents,
                      completedCount: completedCount,
                      recoverySummary: recoverySummary,
                      monthSummaryDetail: monthSummaryDetail,
                      sickDaysThisMonth: sickDaysThisMonth,
                    ),
                    icon: const Icon(Icons.download, color: Colors.tealAccent),
                    label: const Text(
                      'Download CSV report',
                      style: TextStyle(color: Colors.tealAccent),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- MAIN UI ----------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Stats'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: user == null
              ? Center(
                  child: GlassCard(
                    opacity: 0.15,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Colors.tealAccent,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Please log in to see your health stats.',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('health_logs')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('startDate', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: GlassCard(
                          opacity: 0.12,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.query_stats,
                                  size: 72,
                                  color: Colors.tealAccent,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No health logs yet.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add your illness events in "Health Journey".\nWe’ll turn them into simple charts here.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // -------- Build model list from Firestore --------
                    final List<_HealthLog> entries = [];
                    for (final doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;

                      final Timestamp? startTs =
                          data['startDate'] as Timestamp?;
                      final Timestamp? endTs = data['endDate'] as Timestamp?;
                      final DateTime? startDate = startTs?.toDate();
                      final DateTime? endDate = endTs?.toDate();

                      entries.add(
                        _HealthLog(
                          illnessName:
                              (data['illnessName'] ?? 'Illness') as String,
                          recoveredDays: data['recoveredDays'] as int?,
                          startDate: startDate,
                          endDate: endDate,
                        ),
                      );
                    }

                    // completed illnesses (with recovery days)
                    final completedEntries = entries
                        .where((e) =>
                            e.recoveredDays != null && e.recoveredDays! > 0)
                        .toList();

                    final recoveryData =
                        _buildRecoveryChartData(completedEntries);
                    final monthlyStats = _buildMonthlyIllnessBars(entries);

                    // ---------- high-level summaries ----------
                    final now = DateTime.now();
                    const monthNames = [
                      '',
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    final currentMonthLabel =
                        '${monthNames[now.month]} ${now.year}';

                    int sickDaysThisMonth = 0;
                    for (final m in monthlyStats) {
                      if (m.label == currentMonthLabel) {
                        sickDaysThisMonth = m.days;
                        break;
                      }
                    }

                    int completedCount = 0;
                    int totalRecoveryDays = 0;
                    int longestRecovery = 0;
                    int shortestRecovery = 9999;

                    for (final e in completedEntries) {
                      final d = e.recoveredDays!;
                      completedCount++;
                      totalRecoveryDays += d;
                      if (d > longestRecovery) longestRecovery = d;
                      if (d < shortestRecovery) shortestRecovery = d;
                    }

                    final double avgRecoveryDays = completedCount > 0
                        ? totalRecoveryDays / completedCount
                        : 0;

                    final String topMonthSummary =
                        sickDaysThisMonth == 0
                            ? '😷 You haven’t logged any sick days this month yet.'
                            : '😷 This month you were sick for $sickDaysThisMonth day${sickDaysThisMonth == 1 ? '' : 's'}.';

                    final int totalEvents = entries.length;
                    final String topEventsSummary = totalEvents == 0
                        ? '📝 No health events logged yet.'
                        : '📝 You’ve logged $totalEvents health event${totalEvents == 1 ? '' : 's'} so far.';

                    String recoverySummary;
                    if (completedCount == 0) {
                      recoverySummary =
                          'Once you mark some illnesses as recovered, this will show\nhow many days you usually take to get better.';
                    } else {
                      final avgRounded =
                          avgRecoveryDays.toStringAsFixed(1).replaceAll('.0', '');
                      recoverySummary =
                          'Most of your recent illnesses lasted about $avgRounded day${avgRecoveryDays == 1 ? '' : 's'}.\n'
                          'Shortest illness: $shortestRecovery day${shortestRecovery == 1 ? '' : 's'}  •  Longest: $longestRecovery day${longestRecovery == 1 ? '' : 's'}.';
                    }

                    String monthSummaryDetail = '';
                    if (monthlyStats.isNotEmpty) {
                      int maxMonthDays = 0;
                      String maxMonthLabel = '';
                      for (final m in monthlyStats) {
                        if (m.days > maxMonthDays) {
                          maxMonthDays = m.days;
                          maxMonthLabel = m.label;
                        }
                      }
                      monthSummaryDetail =
                          'Your heaviest recent month was $maxMonthLabel with $maxMonthDays sick day${maxMonthDays == 1 ? '' : 's'}.';
                    }

                    // Legend for chart
                    final List<String> recoveryLegend = [];
                    for (int i = 0; i < completedEntries.length; i++) {
                      final e = completedEntries[i];
                      final days = e.recoveredDays ?? 0;
                      recoveryLegend.add(
                        'Illness #${i + 1}: ${_shortIllnessLabelFull(e.illnessName)} – $days day${days == 1 ? '' : 's'}',
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // ===== TOP SUMMARY CARD =====
                          GlassCard(
                            opacity: 0.18,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topMonthSummary,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    topEventsSummary,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (completedCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💊 Illnesses with a clear recovery: $completedCount',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showHealthAiDialog(
                                        context,
                                        completedEntries: completedEntries,
                                        monthlyStats: monthlyStats,
                                        totalEvents: totalEvents,
                                        completedCount: completedCount,
                                        recoverySummary: recoverySummary,
                                        monthSummaryDetail:
                                            monthSummaryDetail,
                                        sickDaysThisMonth: sickDaysThisMonth,
                                      ),
                                      icon: const Icon(
                                        Icons.psychology,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'AI Health Report',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.tealAccent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ===== RECOVERY SPEED CARD =====
                          GlassCard(
                            opacity: 0.18,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'How long your illnesses lasted',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.tealAccent,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Each point is one illness you fully recovered from.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Left to right: Illness #1, #2, #3…   •   Upwards: days you were unwell',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 220,
                                    child: recoveryData.spots.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'After you mark some illnesses as recovered,\nthis chart will show how many days they lasted.',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : LineChart(
                                            LineChartData(
                                              minX: 0,
                                              maxX: recoveryData.spots.length
                                                      .toDouble() -
                                                  1,
                                              minY: 0,
                                              maxY: recoveryData.maxY,
                                              clipData: FlClipData.all(),
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: true,
                                                horizontalInterval:
                                                    recoveryData.maxY <= 10
                                                        ? 1
                                                        : (recoveryData.maxY <=
                                                                50
                                                            ? 5
                                                            : 10),
                                                getDrawingHorizontalLine:
                                                    (value) => FlLine(
                                                  color: Colors.white10,
                                                  strokeWidth: 1,
                                                ),
                                                getDrawingVerticalLine:
                                                    (value) => FlLine(
                                                  color: Colors.white10,
                                                  strokeWidth: 1,
                                                ),
                                              ),
                                              borderData:
                                                  FlBorderData(show: true),
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 32,
                                                    getTitlesWidget:
                                                        (value, meta) {
                                                      return Text(
                                                        value
                                                            .toInt()
                                                            .toString(),
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.white60,
                                                          fontSize: 11,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 40,
                                                    getTitlesWidget:
                                                        (value, meta) {
                                                      final index =
                                                          value.toInt();
                                                      if (index < 0 ||
                                                          index >=
                                                              recoveryData
                                                                  .labels
                                                                  .length) {
                                                        return const SizedBox
                                                            .shrink();
                                                      }
                                                      final label =
                                                          recoveryData
                                                              .labels[index];
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .only(
                                                                top: 4.0),
                                                        child: Text(
                                                          label,
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 10,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                                rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                              ),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: recoveryData.spots,
                                                  isCurved: false,
                                                  barWidth: 3,
                                                  color: Colors.tealAccent,
                                                  dotData:
                                                      FlDotData(show: true),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    recoverySummary,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (recoveryLegend.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'What each point means:',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: recoveryLegend
                                          .map(
                                            (line) => Text(
                                              '• $line',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ===== ILLNESS DAYS PER MONTH CARD =====
                          GlassCard(
                            opacity: 0.18,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sick days each month',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.tealAccent,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'This is a rough view of how many days you were unwell in each month.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Left to right: months   •   Upwards: total sick days that month',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 220,
                                    child: monthlyStats.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'As you log more health events,\nthis will show which months were heavier for you.',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : BarChart(
                                            BarChartData(
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: true,
                                                getDrawingHorizontalLine:
                                                    (value) => FlLine(
                                                  color: Colors.white10,
                                                  strokeWidth: 1,
                                                ),
                                                getDrawingVerticalLine:
                                                    (value) => FlLine(
                                                  color: Colors.white10,
                                                  strokeWidth: 1,
                                                ),
                                              ),
                                              borderData:
                                                  FlBorderData(show: true),
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 32,
                                                    getTitlesWidget:
                                                        (value, meta) {
                                                      return Text(
                                                        value
                                                            .toInt()
                                                            .toString(),
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.white60,
                                                          fontSize: 11,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 36,
                                                    getTitlesWidget:
                                                        (value, meta) {
                                                      final monthIndex =
                                                          value.toInt();
                                                      if (monthIndex < 0 ||
                                                          monthIndex >=
                                                              monthlyStats
                                                                  .length) {
                                                        return const SizedBox
                                                            .shrink();
                                                      }
                                                      final label =
                                                          monthlyStats[
                                                                  monthIndex]
                                                              .label;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .only(
                                                                top: 4.0),
                                                        child: Text(
                                                          label,
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 10,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                                rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                              ),
                                              barGroups: List.generate(
                                                monthlyStats.length,
                                                (index) =>
                                                    BarChartGroupData(
                                                  x: index,
                                                  barRods: [
                                                    BarChartRodData(
                                                      toY: monthlyStats[index]
                                                          .days
                                                          .toDouble(),
                                                      width: 14,
                                                      color: Colors.tealAccent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (monthSummaryDetail.isNotEmpty)
                                    Text(
                                      monthSummaryDetail,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ---------- Helper data classes & builders ----------

class _HealthLog {
  final String illnessName;
  final int? recoveredDays;
  final DateTime? startDate;
  final DateTime? endDate;

  _HealthLog({
    required this.illnessName,
    this.recoveredDays,
    this.startDate,
    this.endDate,
  });
}

/// For monthly sickness chart
class _MonthStat {
  final String label; // e.g. "Oct 2025"
  final int days;

  _MonthStat({required this.label, required this.days});
}

/// For recovery chart
class _RecoveryChartData {
  final List<FlSpot> spots;
  final List<String> labels;
  final double maxY;

  const _RecoveryChartData({
    required this.spots,
    required this.labels,
    required this.maxY,
  });
}

/// Short label on chart (Illness #1, #2…)
String _shortIllnessLabelForChart(int index) => 'Illness #${index + 1}';

/// Full illness name for legend
String _shortIllnessLabelFull(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'Illness';
  if (name.length <= 24) return name;
  return '${name.substring(0, 23)}…';
}

/// Build data for "recovered days per illness"
_RecoveryChartData _buildRecoveryChartData(List<_HealthLog> completed) {
  if (completed.isEmpty) {
    return const _RecoveryChartData(spots: [], labels: [], maxY: 5);
  }

  int maxDays = 0;
  final List<FlSpot> spots = [];

  for (int i = 0; i < completed.length; i++) {
    final d = completed[i].recoveredDays ?? 0;
    maxDays = max(maxDays, d);
    spots.add(FlSpot(i.toDouble(), d.toDouble()));
  }

  final double maxY = max(5, maxDays + 5).toDouble();
  final labels = List<String>.generate(
    completed.length,
    (i) => _shortIllnessLabelForChart(i),
  );

  return _RecoveryChartData(spots: spots, labels: labels, maxY: maxY);
}

/// Build sorted month stats for bar chart
List<_MonthStat> _buildMonthlyIllnessBars(List<_HealthLog> entries) {
  if (entries.isEmpty) return [];

  final Map<String, int> bucket = {}; // "YYYY-MM" -> days
  final now = DateTime.now();

  for (final e in entries) {
    if (e.startDate == null) continue;
    final start = e.startDate!;
    final end = e.endDate ?? now;
    int days = end.difference(start).inDays + 1;
    if (days < 1) days = 1;

    final key =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
    bucket[key] = (bucket[key] ?? 0) + days;
  }

  if (bucket.isEmpty) return [];

  final monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  final sortedKeys = bucket.keys.toList()..sort(); // "YYYY-MM"

  final List<_MonthStat> result = [];
  for (final key in sortedKeys) {
    final parts = key.split('-'); // [YYYY, MM]
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final label = '${monthNames[month]} $year';
    result.add(_MonthStat(label: label, days: bucket[key]!));
  }

  return result;
}
