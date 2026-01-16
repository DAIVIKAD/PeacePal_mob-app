// lib/src/screens/reminders.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../services/notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _medNameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _medNameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _addReminder() async {
    if (_medNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medication name')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();

      // Build DateTime from today + picked time
      var scheduledAt = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // If already passed today, schedule for tomorrow
      if (scheduledAt.isBefore(now)) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }

      // Deterministic ID
      final notifId = scheduledAt.millisecondsSinceEpoch ~/ 1000;
      final medName = _medNameController.text.trim();

      // Save Firestore doc
      await FirebaseFirestore.instance.collection('reminders').add({
        'userId': user.uid,
        'title': medName,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'notificationId': notifId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 1️⃣ Show pinned "Reminder set" notif
      final timeLabel = DateFormat('hh:mm a').format(scheduledAt);
      await NotificationService.showPinnedSetupNotification(
        id: notifId,
        title: 'Reminder set',
        body: 'We’ll remind you at $timeLabel to take $medName',
      );

      // 2️⃣ Schedule actual reminder at that time (same id so it replaces pinned)
      await NotificationService.scheduleReminder(
        id: notifId,
        title: 'Medication Reminder',
        body: 'Time to take $medName 💊',
        scheduledAt: scheduledAt,
      );

      _medNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder saved & notification scheduled'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error adding reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving reminder: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a medication reminder',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medNameController,
                        decoration: const InputDecoration(
                          hintText: 'Medication name',
                          filled: true,
                          fillColor: Colors.black12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Time: ${_formatTimeOfDay(_selectedTime)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _pickTime,
                            child: const Text('Pick time'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _addReminder,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.alarm_add),
                          label: Text(_saving ? 'Saving...' : 'Save Reminder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.neuralBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Saved reminders will also show in the Notifications tab.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
