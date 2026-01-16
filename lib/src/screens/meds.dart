// lib/src/screens/meds.dart
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme.dart';
import '../services/groq_service.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

class SearchMedsScreen extends StatefulWidget {
  const SearchMedsScreen({Key? key}) : super(key: key);
  @override
  State<SearchMedsScreen> createState() => _SearchMedsScreenState();
}

class _SearchMedsScreenState extends State<SearchMedsScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  String? _info;

  Future<void> _search(String med) async {
    if (med.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _info = null;
    });
    final res = await GroqAIService.searchMedication(med.trim());
    setState(() {
      _info = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_loading) {
      bodyContent = const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan)));
    } else if (_info == null) {
      bodyContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_information, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            Text('Search for any medication', style: TextStyle(color: Colors.white54, fontSize: 18)),
            SizedBox(height: 10),
            Text('💊 Powered by Groq AI', style: TextStyle(color: AppTheme.neonCyan, fontSize: 14)),
          ],
        ),
      );
    } else {
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Medication Information', style: TextStyle(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(_info!, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search Medications', style: TextStyle(color: Colors.blueAccent)), backgroundColor: AppTheme.darkBase),
      body: AnimatedNeuralBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter medication name...',
                          hintStyle: TextStyle(color: Colors.white54),
                          prefixIcon: Icon(Icons.medication, color: Colors.blueAccent),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _search,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.neuralGradient,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _search(_searchCtrl.text),
                      icon: const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      ),
    );
  }
}

// MyMedications + MedicationDetail omitted for brevity — keep them as before or ask me to paste next.
