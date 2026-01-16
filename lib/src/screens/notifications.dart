// lib/src/screens/notifications.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  String _formatDateTime(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    final date =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please sign in to view notifications',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('reminders')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();

              if (docs.isEmpty) {
                return Center(
                  child: GlassCard(
                    opacity: 0.1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.notifications_active,
                          size: 72,
                          color: AppTheme.neonCyan,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort descending by scheduledAt (newest first)
              docs.sort((a, b) {
                final ad = (a.data() as Map<String, dynamic>)['scheduledAt']
                    as Timestamp?;
                final bd = (b.data() as Map<String, dynamic>)['scheduledAt']
                    as Timestamp?;
                if (ad == null && bd == null) return 0;
                if (ad == null) return 1;
                if (bd == null) return -1;
                return bd.toDate().compareTo(ad.toDate());
              });

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;

                  final title = data['title']?.toString() ?? 'Untitled';
                  final scheduled = data['scheduledAt'] as Timestamp?;

                  // Safely extract notificationId in ANY format
                  final notifIdRaw = data['notificationId'];
                  int? notifId;
                  if (notifIdRaw is int) {
                    notifId = notifIdRaw;
                  } else if (notifIdRaw is num) {
                    notifId = notifIdRaw.toInt();
                  } else if (notifIdRaw is String) {
                    final parsed = int.tryParse(notifIdRaw);
                    if (parsed != null) notifId = parsed;
                  }

                  final timeStr = scheduled != null
                      ? _formatDateTime(scheduled)
                      : 'No time';

                  final now = DateTime.now().toUtc();
                  final isPast = scheduled != null &&
                      scheduled.toDate().toUtc().isBefore(now);

                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isPast ? Icons.history : Icons.notifications_active,
                        color: isPast ? Colors.redAccent : AppTheme.neonCyan,
                        size: 30,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        timeStr,
                        style: TextStyle(
                          color: isPast ? Colors.redAccent : Colors.white70,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          try {
                            // 1️⃣ Cancel scheduled/local notification if we have an ID
                            if (notifId != null) {
                              await NotificationService.cancelById(notifId);
                            }

                            // 2️⃣ Remove from Firestore so it disappears from list
                            await firestore
                                .collection('reminders')
                                .doc(d.id)
                                .delete();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Reminder deleted"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Failed to delete: $e"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
