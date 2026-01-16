// lib/src/screens/mood_chart.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

class MoodTrendsChart extends StatelessWidget {
  const MoodTrendsChart({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Please sign in to view mood trends.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(60) // recent moods; we’ll reduce to last 7 days by date
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load mood data.\n'
                'Check Firestore indexes for the "moods" collection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No mood data yet.\nStart logging your moods!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // ----------------------------------------------------------
        // Group by calendar day.
        // Because docs are DESC, first mood per date = latest that day
        // ----------------------------------------------------------
        final Map<String, Map<String, dynamic>> byDay = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          final ts = data['timestamp'] as Timestamp?;
          if (ts == null) continue;

          final dt = ts.toDate().toLocal();
          final dateOnly = DateTime(dt.year, dt.month, dt.day);

          // stable key like 2025-12-03
          final key = DateFormat('yyyy-MM-dd').format(dateOnly);

          if (byDay.containsKey(key)) {
            // we already stored the latest mood for this day
            continue;
          }

          final value = data['value'];
          final doubleVal = (value is num)
              ? value.toDouble()
              : double.tryParse(value?.toString() ?? '3') ?? 3.0;

          byDay[key] = {
            'date': dateOnly,
            'value': doubleVal,
          };
        }

        var entries = byDay.entries.toList();

        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No mood data available',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        // Sort ASC by date
        entries.sort((a, b) => a.key.compareTo(b.key));

        // Only last 7 days
        if (entries.length > 7) {
          entries = entries.sublist(entries.length - 7);
        }

        // Build chart points
        final List<FlSpot> spots = [];
        for (int i = 0; i < entries.length; i++) {
          final v = entries[i].value['value'] as double;
          spots.add(FlSpot(i.toDouble(), v));
        }

        // X-axis labels
        final Map<int, String> bottomTitles = {};
        for (int i = 0; i < entries.length; i++) {
          final dt = entries[i].value['date'] as DateTime;
          bottomTitles[i] = DateFormat('MMM dd').format(dt);
        }

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 1,
                  maxY: 5,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) {
                            return const SizedBox.shrink();
                          }
                          final idx = value.toInt();
                          final label = bottomTitles[idx];
                          if (label == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.neonCyan,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'One mood per day • Last 7 days',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
