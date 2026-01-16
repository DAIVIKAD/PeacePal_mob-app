// lib/src/screens/my_medications.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class MyMedicationsScreen extends StatelessWidget {
  const MyMedicationsScreen({Key? key}) : super(key: key);

  // ---------- COMMON HELPERS ----------

  String _formatShort(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  DateTime _stripTime(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  // ---------- ADD HEALTH LOG (HEALTH JOURNEY) ----------
  Future<void> _showAddHealthLogDialog(BuildContext context) async {
    final illnessController = TextEditingController();
    final medicationController = TextEditingController();
    final notesController = TextEditingController();
    final doctorController = TextEditingController();
    final hospitalController = TextEditingController();
    String severity = 'Mild';

    DateTime? startDate;
    DateTime? endDate;

    String formatDate(DateTime? d) {
      if (d == null) return 'Pick date';
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickStartDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: startDate ?? now,
                firstDate: DateTime(2020),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  startDate = picked;
                  if (endDate != null && endDate!.isBefore(startDate!)) {
                    endDate = null;
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: endDate ?? startDate ?? now,
                firstDate: startDate ?? DateTime(2020),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  endDate = picked;
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.darkBase.withOpacity(0.94),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Log Health Event',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: illnessController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Illness / Condition',
                        hintText: 'e.g. Viral fever, migraine, anxiety episode',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: medicationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Medication used',
                        hintText: 'e.g. Dolo 650, Antacid, etc.',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Severity:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          dropdownColor: AppTheme.darkBase,
                          value: severity,
                          iconEnabledColor: AppTheme.neonCyan,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 'Mild',
                              child: Text('Mild'),
                            ),
                            DropdownMenuItem(
                              value: 'Moderate',
                              child: Text('Moderate'),
                            ),
                            DropdownMenuItem(
                              value: 'Severe',
                              child: Text('Severe'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                severity = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Start date:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: pickStartDate,
                          child: Text(
                            formatDate(startDate),
                            style: const TextStyle(color: Colors.tealAccent),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'End date:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: pickEndDate,
                          child: Text(
                            endDate == null
                                ? 'Ongoing / Not yet'
                                : formatDate(endDate),
                            style: TextStyle(
                              color: endDate == null
                                  ? Colors.white54
                                  : Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: doctorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Doctor (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hospitalController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Hospital / Clinic (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Notes (symptoms, triggers, what helped)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    if (illnessController.text.trim().isEmpty) return;

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      Navigator.of(dialogCtx).pop();
                      return;
                    }

                    int? recoveredDays;
                    if (startDate != null && endDate != null) {
                      final s = _stripTime(startDate!);
                      final e = _stripTime(endDate!);
                      recoveredDays = e.difference(s).inDays + 1;
                    }

                    final bool active = endDate == null;

                    await FirebaseFirestore.instance
                        .collection('health_logs')
                        .add({
                      'userId': user.uid,
                      'illnessName': illnessController.text.trim(),
                      'medication': medicationController.text.trim(),
                      'severity': severity,
                      'startDate': startDate,
                      'endDate': endDate,
                      'recoveredDays': recoveredDays,
                      'doctor': doctorController.text.trim(),
                      'hospital': hospitalController.text.trim(),
                      'notes': notesController.text.trim(),
                      'active': active,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- EDIT HEALTH LOG ----------
  Future<void> _showEditHealthLogDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final illnessController =
        TextEditingController(text: data['illnessName']?.toString() ?? '');
    final medicationController =
        TextEditingController(text: data['medication']?.toString() ?? '');
    final notesController =
        TextEditingController(text: data['notes']?.toString() ?? '');
    final doctorController =
        TextEditingController(text: data['doctor']?.toString() ?? '');
    final hospitalController =
        TextEditingController(text: data['hospital']?.toString() ?? '');
    String severity = (data['severity'] ?? 'Mild') as String;

    DateTime? startDate =
        (data['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate =
        (data['endDate'] as Timestamp?)?.toDate();

    String formatDate(DateTime? d) {
      if (d == null) return 'Pick date';
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickStartDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: startDate ?? now,
                firstDate: DateTime(2020),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  startDate = picked;
                  if (endDate != null && endDate!.isBefore(startDate!)) {
                    endDate = null;
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: endDate ?? startDate ?? now,
                firstDate: startDate ?? DateTime(2020),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  endDate = picked;
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.darkBase.withOpacity(0.94),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Edit Health Event',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: illnessController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Illness / Condition',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: medicationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Medication used',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Severity:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          dropdownColor: AppTheme.darkBase,
                          value: severity,
                          iconEnabledColor: AppTheme.neonCyan,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 'Mild',
                              child: Text('Mild'),
                            ),
                            DropdownMenuItem(
                              value: 'Moderate',
                              child: Text('Moderate'),
                            ),
                            DropdownMenuItem(
                              value: 'Severe',
                              child: Text('Severe'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                severity = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Start date:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: pickStartDate,
                          child: Text(
                            formatDate(startDate),
                            style: const TextStyle(color: Colors.tealAccent),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'End date:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: pickEndDate,
                          child: Text(
                            endDate == null
                                ? 'Ongoing / Not yet'
                                : formatDate(endDate),
                            style: TextStyle(
                              color: endDate == null
                                  ? Colors.white54
                                  : Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: doctorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Doctor (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hospitalController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Hospital / Clinic (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Notes (symptoms, triggers, what helped)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    if (illnessController.text.trim().isEmpty) return;

                    int? recoveredDays;
                    bool active = true;

                    if (startDate != null && endDate != null) {
                      final s = _stripTime(startDate!);
                      final e = _stripTime(endDate!);
                      recoveredDays = e.difference(s).inDays + 1;
                      active = false;
                    } else {
                      recoveredDays = null;
                      active = endDate == null;
                    }

                    await FirebaseFirestore.instance
                        .collection('health_logs')
                        .doc(docId)
                        .update({
                      'illnessName': illnessController.text.trim(),
                      'medication': medicationController.text.trim(),
                      'severity': severity,
                      'startDate': startDate,
                      'endDate': endDate,
                      'recoveredDays': recoveredDays,
                      'doctor': doctorController.text.trim(),
                      'hospital': hospitalController.text.trim(),
                      'notes': notesController.text.trim(),
                      'active': active,
                    });

                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- TOGGLE ACTIVE / RECOVERED ----------
  Future<void> _toggleActive(
    String docId,
    bool newValue,
    DateTime? startDate,
  ) async {
    // newValue == true  -> mark as ongoing
    // newValue == false -> mark as recovered TODAY (auto endDate)
    if (newValue) {
      await FirebaseFirestore.instance
          .collection('health_logs')
          .doc(docId)
          .update({
        'active': true,
        'endDate': null,
        'recoveredDays': null,
      });
    } else {
      final today = DateTime.now();
      final end = DateTime(today.year, today.month, today.day);
      int? recoveredDays;

      if (startDate != null) {
        final s = DateTime(startDate.year, startDate.month, startDate.day);
        recoveredDays = end.difference(s).inDays + 1;
      }

      await FirebaseFirestore.instance
          .collection('health_logs')
          .doc(docId)
          .update({
        'active': false,
        'endDate': end,
        'recoveredDays': recoveredDays,
      });
    }
  }

  Future<void> _deleteHealthLog(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBase.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete record?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove this illness / health event from your history.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('health_logs')
          .doc(docId)
          .delete();
    }
  }

  // ---------- MAIN UI ----------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Journey'),
        backgroundColor: AppTheme.darkBase,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHealthLogDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Log event'),
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: user == null
              ? Center(
                  child: GlassCard(
                    opacity: 0.15,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock_outline,
                              size: 64, color: Colors.tealAccent),
                          SizedBox(height: 12),
                          Text(
                            'Please log in to view your health history.',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      opacity: 0.12,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: const [
                            Icon(Icons.health_and_safety,
                                size: 40, color: Colors.tealAccent),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Log your illnesses, medications, and recovery time to visualize your health journey.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('health_logs')
                            .where('userId', isEqualTo: user.uid)
                            .orderBy('startDate', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: GlassCard(
                                opacity: 0.1,
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.monitor_heart,
                                          size: 72,
                                          color: Colors.tealAccent),
                                      SizedBox(height: 12),
                                      Text(
                                        'Your health logs will appear here.\nTap "Log event" to get started.',
                                        style:
                                            TextStyle(color: Colors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data =
                                  doc.data() as Map<String, dynamic>;

                              final illness =
                                  (data['illnessName'] ?? '') as String;
                              final medication =
                                  (data['medication'] ?? '') as String;
                              final severity =
                                  (data['severity'] ?? '') as String;
                              final notes =
                                  (data['notes'] ?? '') as String;
                              final doctor =
                                  (data['doctor'] ?? '') as String;
                              final hospital =
                                  (data['hospital'] ?? '') as String;
                              final active = data['active'] == true;

                              final Timestamp? startTs =
                                  data['startDate'] as Timestamp?;
                              final Timestamp? endTs =
                                  data['endDate'] as Timestamp?;
                              final DateTime? startDate =
                                  startTs?.toDate();
                              final DateTime? endDate = endTs?.toDate();

                              final int? recoveredDays =
                                  data['recoveredDays'] as int?;

                              return GestureDetector(
                                onLongPress: () =>
                                    _deleteHealthLog(context, doc.id),
                                child: GlassCard(
                                  opacity: active ? 0.18 : 0.08,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          active ? Icons.sick : Icons.healing,
                                          size: 40,
                                          color: active
                                              ? Colors.orangeAccent
                                              : Colors.tealAccent,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                illness.isEmpty
                                                    ? 'Health event'
                                                    : illness,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                              if (medication.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Medication: $medication',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  if (severity.isNotEmpty)
                                                    Chip(
                                                      label: Text(
                                                        severity,
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 12),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white12,
                                                    ),
                                                  if (startDate != null)
                                                    Chip(
                                                      label: Text(
                                                        'From: ${_formatShort(startDate)}',
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 12),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white12,
                                                    ),
                                                  if (endDate != null)
                                                    Chip(
                                                      label: Text(
                                                        'To: ${_formatShort(endDate)}',
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 12),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white12,
                                                    ),
                                                  if (recoveredDays != null)
                                                    Chip(
                                                      label: Text(
                                                        'Recovered in $recoveredDays days',
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 12),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white12,
                                                    ),
                                                  Chip(
                                                    label: Text(
                                                      active
                                                          ? 'Ongoing'
                                                          : 'Recovered',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: active
                                                            ? Colors
                                                                .orangeAccent
                                                            : Colors
                                                                .tealAccent,
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.white10,
                                                  ),
                                                ],
                                              ),
                                              if (doctor.isNotEmpty ||
                                                  hospital.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  [
                                                    if (doctor.isNotEmpty)
                                                      'Dr. $doctor',
                                                    if (hospital.isNotEmpty)
                                                      hospital,
                                                  ].join(' • '),
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                              if (notes.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  notes,
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Column with switch + edit + delete button
                                        Column(
                                          children: [
                                            Switch(
                                              value: active,
                                              onChanged: (val) =>
                                                  _toggleActive(
                                                doc.id,
                                                val,
                                                startDate,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Edit this log',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.tealAccent,
                                              ),
                                              onPressed: () => _showEditHealthLogDialog(
                                                context,
                                                doc.id,
                                                data,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete this log',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  _deleteHealthLog(
                                                      context, doc.id),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
