// lib/src/screens/profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _email = '';
  String _genderIcon = "male";
  bool _loading = false;

  bool _showJournalPreview = false;
  bool _showMedicationPreview = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD USER DATA
  // ============================================================
  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _email = user.email ?? "");

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameCtrl.text = data['name'] ?? "";
        _genderIcon = data['genderIcon'] ?? "male";
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          "name": user.displayName ?? "",
          "email": user.email,
          "createdAt": FieldValue.serverTimestamp(),
          "genderIcon": "male",
        });
        _nameCtrl.text = user.displayName ?? "";
      }
      setState(() {});
    } catch (e) {
      _showSnack("Could not load profile: $e", true);
    }
  }

  // ============================================================
  // UPDATE NAME
  // ============================================================
  Future<void> _updateName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      _showSnack("Please enter a name", true);
      return;
    }

    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "name": newName,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(newName);
      await user.reload();

      _showSnack("✅ Name updated successfully!", false);
    } catch (e) {
      _showSnack("Error: $e", true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cur = TextEditingController();
    final newP = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.darkBase,
        title: const Text("Change Password",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cur,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Current Password",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newP,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "New Password",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: cur.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newP.text.trim());

      _showSnack("Password updated successfully!", false);
    } on FirebaseAuthException catch (e) {
      _showSnack("Failed: ${e.message}", true);
    }
  }

  // ============================================================
  // UPDATE PROFILE ICON
  // ============================================================
  Future<void> _changeProfileIcon() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text("Choose Profile Icon",
            style: TextStyle(color: AppTheme.neonCyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.male, color: Colors.blue, size: 30),
              title: const Text("Male", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, "male"),
            ),
            ListTile(
              leading: const Icon(Icons.female, color: Colors.pink, size: 30),
              title:
                  const Text("Female", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, "female"),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "genderIcon": selected
      }, SetOptions(merge: true));

      setState(() => _genderIcon = selected);
      _showSnack("Profile icon updated!", false);
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================
  void _showSnack(String msg, bool err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red.shade800 : Colors.green.shade700,
      ),
    );
  }

  // ============================================================
  // SAVE CSV
  // ============================================================
  Future<String> _saveCsv(String filename, String csv) async {
    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), "_");

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$filename");

    await file.writeAsString(csv);
    return file.path;
  }

  // ============================================================
  // DOWNLOAD JOURNAL CSV
  // ============================================================
  Future<void> _downloadJournalData() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection("journals")
          .where("userId", isEqualTo: user.uid)
          .orderBy("timestamp", descending: true)
          .get();

      if (snap.docs.isEmpty) {
        _showSnack("No journal entries found", true);
        return;
      }

      final rows = [
        ["Date", "Content", "AI Insight"]
      ];

      for (var doc in snap.docs) {
        final data = doc.data();
        String date = "N/A";

        if (data["timestamp"] is Timestamp) {
          date = DateFormat("yyyy-MM-dd HH:mm")
              .format((data["timestamp"] as Timestamp).toDate());
        }

        rows.add([
          date,
          data["content"] ?? "",
          data["aiInsight"] ?? "",
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final path = await _saveCsv(
          "PeacePal_Journals_${DateTime.now().millisecondsSinceEpoch}.csv",
          csv);

      _showSnack("Saved to $path", false);
      OpenFile.open(path);
    } catch (e) {
      _showSnack("Export failed: $e", true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // NEW MEDICATION CSV
  // ============================================================
  Future<void> _downloadMedicationData() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection("reminders")
          .where("userId", isEqualTo: user.uid)
          .orderBy("createdAt", descending: true)
          .get();

      if (snap.docs.isEmpty) {
        _showSnack("No medication reminders found", true);
        return;
      }

      final rows = [
        ["Medication", "Scheduled Time", "Created Date"]
      ];

      for (final doc in snap.docs) {
        final data = doc.data();

        final med = data["title"] ?? "";

        String scheduled = "N/A";
        if (data["scheduledAt"] is Timestamp) {
          scheduled = DateFormat("yyyy-MM-dd HH:mm")
              .format((data["scheduledAt"] as Timestamp).toDate());
        }

        String created = "N/A";
        if (data["createdAt"] is Timestamp) {
          created = DateFormat("yyyy-MM-dd HH:mm")
              .format((data["createdAt"] as Timestamp).toDate());
        }

        rows.add([med, scheduled, created]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final path = await _saveCsv(
          "PeacePal_Medications_${DateTime.now().millisecondsSinceEpoch}.csv",
          csv);

      _showSnack("Saved to $path", false);
      OpenFile.open(path);
    } catch (e) {
      _showSnack("Export failed: $e", true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // JOURNAL PREVIEW
  // ============================================================
  Widget _buildJournalPreview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text("Sign in to view journals",
          style: TextStyle(color: Colors.white54));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("journals")
          .where("userId", isEqualTo: user.uid)
          .orderBy("timestamp", descending: true)
          .limit(15)
          .snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        if (snap.data!.docs.isEmpty) {
          return const Text("No entries found",
              style: TextStyle(color: Colors.white54));
        }

        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            DateTime time = DateTime.now();
            if (data["timestamp"] is Timestamp) {
              time = (data["timestamp"] as Timestamp).toDate();
            }

            final content = data["content"] ?? "";
            final ai = data["aiInsight"] ?? data["aiInsightDaily"] ?? "";

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat("yyyy-MM-dd HH:mm").format(time),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      content.length > 120
                          ? "${content.substring(0, 120)}..."
                          : content,
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (ai.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text("💡 $ai",
                            style: const TextStyle(
                                color: AppTheme.neonCyan, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // NEW MEDICATION PREVIEW
  // ============================================================
  Widget _buildMedicationPreview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text("Sign in to view medication data",
          style: TextStyle(color: Colors.white54));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reminders")
          .where("userId", isEqualTo: user.uid)
          .orderBy("createdAt", descending: true)
          .limit(15)
          .snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        if (snap.data!.docs.isEmpty) {
          return const Text("No reminders found",
              style: TextStyle(color: Colors.white54));
        }

        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            String scheduled = "N/A";
            if (data["scheduledAt"] is Timestamp) {
              scheduled = DateFormat("yyyy-MM-dd HH:mm")
                  .format((data["scheduledAt"] as Timestamp).toDate());
            }

            final med = data["title"] ?? "";

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.medication, color: AppTheme.neonCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text("Scheduled: $scheduled",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBase,
        title: const Text("Profile",
            style: TextStyle(color: AppTheme.neonCyan)),
      ),
      body: AnimatedNeuralBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _changeProfileIcon,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.neuralGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonCyan.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    _genderIcon == "male" ? Icons.male : Icons.female,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(_email,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),

              const SizedBox(height: 40),

              // UPDATE NAME + PASSWORD
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Update Name",
                        style: TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon:
                            Icon(Icons.person, color: AppTheme.neonCyan),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppTheme.neuralGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ElevatedButton(
                        onPressed: _loading ? null : _updateName,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent),
                        child: const Text("Update Name"),
                      ),
                    ),

                    const SizedBox(height: 15),

                    OutlinedButton.icon(
                      onPressed: _loading ? null : _changePassword,
                      icon:
                          const Icon(Icons.vpn_key, color: AppTheme.neonCyan),
                      label: const Text("Change Password",
                          style: TextStyle(color: AppTheme.neonCyan)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.neonCyan),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // DOWNLOAD SECTION
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Download Data",
                        style: TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _showJournalPreview = true);
                              await _downloadJournalData();
                            },
                      icon: const Icon(Icons.download),
                      label: const Text("Download Journal Data"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _showMedicationPreview = true);
                              await _downloadMedicationData();
                            },
                      icon: const Icon(Icons.download),
                      label: const Text("Download Medication Data"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (_showJournalPreview)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Journal Entries Preview",
                          style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildJournalPreview(),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              if (_showMedicationPreview)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Medication Reminders Preview",
                          style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildMedicationPreview(),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 55),
                ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title:
            const Text("Logout", style: TextStyle(color: Colors.redAccent)),
        content:
            const Text("Are you sure?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}
