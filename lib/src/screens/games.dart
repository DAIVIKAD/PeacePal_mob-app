// lib/src/screens/games.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme.dart';
import '../services/groq_service.dart';

// -----------------------------
// GamesScreen (grid)
// -----------------------------
class GamesScreen extends StatelessWidget {
  const GamesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // NOTE: Soundscape (AI future) placed LAST
    final tiles = [
      // 🔁 Mind Tricks
      _buildGameCard(
        context,
        'Mind Tricks',
        Icons.psychology_alt,
        Colors.deepPurpleAccent,
        const MindTricksScreen(),
      ),
      _buildGameCard(
        context,
        'Memory',
        Icons.extension,
        AppTheme.neonPurple,
        const MemoryGame(),
      ),
      _buildGameCard(
        context,
        'Colors',
        Icons.palette,
        Colors.pinkAccent,
        const ColorMatchGame(),
      ),
      _buildGameCard(
        context,
        'Simon',
        Icons.flash_on,
        Colors.cyanAccent,
        const SimonGame(),
      ),
      _buildGameCard(
        context,
        'Mini Sudoku',
        Icons.grid_on,
        Colors.yellowAccent,
        const MiniSudokuScreen(),
      ),
      _buildGameCard(
        context,
        'Stress Ball',
        Icons.circle,
        Colors.greenAccent,
        const StressBallScreen(),
      ),
      _buildGameCard(
        context,
        'Meditation',
        Icons.spa,
        Colors.purpleAccent,
        const MeditationScreen(),
      ),
      _buildGameCard(
        context,
        'Odd One Out',
        Icons.filter_none,
        Colors.orangeAccent,
        const OddOneOutScreen(),
      ),

      // 🔁 Calm Tap removed from grid, XOX Game added instead
      _buildGameCard(
        context,
        'XOX Game',
        Icons.close,
        Colors.lightGreenAccent,
        const XOXGameScreen(),
      ),

      _buildGameCard(
        context,
        'Breathing',
        Icons.air,
        AppTheme.neuralBlue,
        const BreathingGame(),
      ),

      // ⭐ AI Mood Quest
      _buildGameCard(
        context,
        'AI Mood Quest',
        Icons.auto_awesome,
        Colors.cyanAccent,
        const AIMoodQuestGame(),
      ),

      // Soundscape placeholder LAST
      _buildGameCard(
        context,
        'Soundscape',
        Icons.headphones,
        Colors.tealAccent,
        const PlaceholderScreen(title: 'Soundscape (Future AI)'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wellness Games',
          style: TextStyle(color: Colors.pinkAccent),
        ),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🌟 Simple intro
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Choose a wellness mini-game',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Each game is designed to give your brain a tiny reset.\n'
                        'AI Mood Quest uses AI to suggest a fun quest based on how you feel.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Game grid below
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(4),
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: tiles,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => screen),
      ),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------
   Breathing Game
   -------------------------- */
class BreathingGame extends StatefulWidget {
  const BreathingGame({Key? key}) : super(key: key);

  @override
  State<BreathingGame> createState() => _BreathingGameState();
}

class _BreathingGameState extends State<BreathingGame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _phase = 'Breathe In';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )
      ..addListener(() {
        setState(() {
          _phase = _controller.value < 0.5 ? 'Breathe In' : 'Breathe Out';
        });
      })
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breathing Exercise'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: 100 + (_controller.value * 100),
                    height: 100 + (_controller.value * 100),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.neuralGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonCyan.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Text(
                _phase,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   Memory Match
   -------------------------- */
class MemoryGame extends StatefulWidget {
  const MemoryGame({Key? key}) : super(key: key);

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  final List<String> _cards = [
    '😊',
    '😊',
    '🌟',
    '🌟',
    '💙',
    '💙',
    '🌈',
    '🌈',
  ];
  late List<bool> _revealed;
  final List<int> _selected = [];
  int _matches = 0;

  @override
  void initState() {
    super.initState();
    _revealed = List.filled(8, false);
    _cards.shuffle();
  }

  void _onTap(int index) {
    if (_revealed[index] || _selected.length == 2) return;
    setState(() {
      _revealed[index] = true;
      _selected.add(index);
    });
    if (_selected.length == 2) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_cards[_selected[0]] == _cards[_selected[1]]) {
          setState(() => _matches++);
          if (_matches == 4) {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                backgroundColor: AppTheme.cardDark,
                title: const Text(
                  '🎉 You Win!',
                  style: TextStyle(color: AppTheme.neonCyan),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _cards.shuffle();
                        _revealed = List.filled(8, false);
                        _matches = 0;
                      });
                    },
                    child: const Text('Play Again'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _revealed[_selected[0]] = false;
            _revealed[_selected[1]] = false;
          });
        }
        setState(() => _selected.clear());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Match'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Matches: $_matches/4',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: 8,
                itemBuilder: (c, i) {
                  return GestureDetector(
                    onTap: () => _onTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient:
                            _revealed[i] ? AppTheme.neuralGradient : null,
                        color: _revealed[i] ? null : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppTheme.neonCyan.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _revealed[i] ? _cards[i] : '?',
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------
   Color Match Game
   -------------------------- */
class ColorMatchGame extends StatefulWidget {
  const ColorMatchGame({Key? key}) : super(key: key);

  @override
  State<ColorMatchGame> createState() => _ColorMatchGameState();
}

class _ColorMatchGameState extends State<ColorMatchGame> {
  final Random _rand = Random();
  late List<Color> _options;
  late Color _target;
  int _round = 1;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final base = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.yellowAccent,
      Colors.pinkAccent,
    ];
    base.shuffle(_rand);
    _options = base.take(4).toList();
    _target = _options[_rand.nextInt(_options.length)];
    setState(() {});
  }

  void _pick(Color c) {
    final correct = c == _target;
    if (correct) _score++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(correct ? 'Correct ✓' : 'Try next time ✕'),
        duration: const Duration(milliseconds: 700),
      ),
    );
    _round++;
    if (_round > 6) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Round over — Score: $_score/6'),
            backgroundColor: AppTheme.cardDark,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _score = 0;
                    _round = 1;
                    _newRound();
                  });
                },
                child: const Text('Play Again'),
              ),
            ],
          );
        },
      );
    } else {
      _newRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Match'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Round $_round / 6',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      const Text(
                        'Tap the swatch that matches this color',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 120,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _target,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: _options.map((c) {
                    return GestureDetector(
                      onTap: () => _pick(c),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: $_score',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   Simon Game
   -------------------------- */
class SimonGame extends StatefulWidget {
  const SimonGame({Key? key}) : super(key: key);

  @override
  State<SimonGame> createState() => _SimonGameState();
}

class _SimonGameState extends State<SimonGame> {
  final List<Color> _palette = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
  ];
  final List<int> _sequence = [];
  final List<int> _user = [];
  bool _showing = false;
  String _status = 'Press Start';
  int _level = 0;
  final Random _rand = Random();
  int _activeIndex = -1; // -1 = none, 0..3 = flashing tile

  void _start() {
    _sequence.clear();
    _user.clear();
    _level = 0;
    _nextLevel();
  }

  Future<void> _nextLevel() async {
    _level++;
    _status = 'Watch';
    setState(() {});
    _sequence.add(_rand.nextInt(4));
    await _playSequence();
    _status = 'Your turn';
    _user.clear();
    setState(() {});
  }

  Future<void> _playSequence() async {
    _showing = true;
    for (final idx in _sequence) {
      await _flash(idx);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _showing = false;
    _activeIndex = -1;
    setState(() {});
  }

  Future<void> _flash(int idx) async {
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _activeIndex = idx;
    });
    await Future.delayed(const Duration(milliseconds: 420));
    setState(() {
      _activeIndex = -1;
    });
    await Future.delayed(const Duration(milliseconds: 110));
  }

  void _onTap(int idx) {
    if (_showing) return;
    _user.add(idx);
    SystemSound.play(SystemSoundType.click);
    final cur = _user.length - 1;
    if (_user[cur] != _sequence[cur]) {
      _status = 'Wrong — game over';
      setState(() {});
      Future.delayed(
        const Duration(milliseconds: 600),
        () => _showGameOver(),
      );
      return;
    }
    if (_user.length == _sequence.length) {
      _status = 'Good — next';
      setState(() {});
      Future.delayed(
        const Duration(milliseconds: 600),
        _nextLevel,
      );
    } else {
      setState(() {});
    }
  }

  void _showGameOver() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: Text(
            'Game over — Level $_level',
            style: const TextStyle(color: AppTheme.neonCyan),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _status = 'Press Start';
                  _sequence.clear();
                  _user.clear();
                  _level = 0;
                  _activeIndex = -1;
                });
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _start();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  Widget _colorTile(int idx) {
    final isActive = _activeIndex == idx;
    return GestureDetector(
      onTap: () => _onTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: isActive
            ? (Matrix4.identity()..scale(1.08))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _palette[idx].withOpacity(isActive ? 1.0 : 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.14),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                  ),
                ],
          border: Border.all(color: Colors.white24),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simon — Memory'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Text(
                'Level: $_level',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: List.generate(4, (i) => _colorTile(i)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neuralBlue,
                    ),
                    child: const Text('Start'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _sequence.clear();
                        _user.clear();
                        _level = 0;
                        _status = 'Press Start';
                        _activeIndex = -1;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   Calm Tap Game (kept but not shown in grid)
   -------------------------- */
class CalmTapGame extends StatefulWidget {
  const CalmTapGame({Key? key}) : super(key: key);

  @override
  State<CalmTapGame> createState() => _CalmTapGameState();
}

class _CalmTapGameState extends State<CalmTapGame> {
  double _progress = 0.0; // 0.0 to 1.0
  Timer? _decayTimer;
  int _lastTap = 0;

  @override
  void initState() {
    super.initState();
    _decayTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) {
        if (_progress > 0) {
          setState(() {
            _progress = max(0.0, _progress - 0.01);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTap < 200) return;
    _lastTap = now;
    setState(() {
      _progress = min(1.0, _progress + 0.08);
    });
    SystemSound.play(SystemSoundType.click);
    if (_progress >= 1.0) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Calm meter full ✨'),
            content: const Text(
              'Nice — take a deep breath and enjoy the calm.',
            ),
            backgroundColor: AppTheme.cardDark,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _progress = 0.0;
                  });
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calm Tap'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Tap gently to fill the calm meter. Slow is better.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _onTap,
                child: GlassCard(
                  child: SizedBox(
                    width: double.infinity,
                    height: 260,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 160,
                              height: 160,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black12,
                              ),
                            ),
                            Container(
                              width: 120 + (_progress * 80),
                              height: 120 + (_progress * 80),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.neuralGradient,
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Tap gently',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: AppTheme.cardDark,
                color: AppTheme.neonCyan,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _progress = 0.0;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   🧩 Mini Sudoku Screen (4x4)
   -------------------------- */
class MiniSudokuScreen extends StatefulWidget {
  const MiniSudokuScreen({Key? key}) : super(key: key);

  @override
  State<MiniSudokuScreen> createState() => _MiniSudokuScreenState();
}

class _MiniSudokuScreenState extends State<MiniSudokuScreen> {
  // 4x4 solution
  final List<List<int>> _solution = const [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ];

  late List<List<int>> _grid; // 0 = empty
  late List<List<bool>> _fixed; // true = non-editable
  Set<String> _errors = {};

  @override
  void initState() {
    super.initState();
    _initPuzzle();
  }

  void _initPuzzle() {
    // simple puzzle: some cells given, some empty
    _grid = [
      [1, 0, 3, 0],
      [0, 4, 0, 2],
      [0, 1, 0, 3],
      [4, 0, 2, 0],
    ];
    _fixed = List.generate(
      4,
      (r) => List.generate(4, (c) => _grid[r][c] != 0),
    );
    _errors = {};
    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_fixed[row][col]) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int n = 1; n <= 4; n++)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _grid[row][col] = n;
                      _errors.remove('$row-$col');
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neuralBlue,
                  ),
                  child: Text('$n'),
                ),
              IconButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _grid[row][col] = 0;
                    _errors.remove('$row-$col');
                  });
                },
                icon: const Icon(
                  Icons.backspace,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _checkSolution() {
    final newErrors = <String>{};
    bool hasEmpty = false;

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final val = _grid[r][c];
        if (val == 0) {
          hasEmpty = true;
        } else if (val != _solution[r][c]) {
          newErrors.add('$r-$c');
        }
      }
    }

    setState(() {
      _errors = newErrors;
    });

    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some cells are still empty.'),
        ),
      );
      return;
    }

    if (newErrors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfect! Mini Sudoku solved 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some numbers are wrong. Check highlighted cells.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildCell(int r, int c) {
    final val = _grid[r][c];
    final isFixed = _fixed[r][c];
    final isError = _errors.contains('$r-$c');

    Color bg;
    if (isError) {
      bg = Colors.red.withOpacity(0.3);
    } else if (isFixed) {
      bg = Colors.white12;
    } else {
      bg = Colors.black26;
    }

    const border = BorderSide(color: Colors.white24, width: 1);

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border.color, width: border.width),
        ),
        child: Center(
          child: Text(
            val == 0 ? '' : '$val',
            style: TextStyle(
              color: isFixed ? Colors.cyanAccent : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Sudoku (4x4)'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Rules',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Fill the grid with numbers 1–4.\nEach row, column, and 2x2 box must contain all numbers 1–4 with no repeats.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: GlassCard(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                    ),
                    itemCount: 16,
                    itemBuilder: (ctx, index) {
                      final r = index ~/ 4;
                      final c = index % 4;
                      return _buildCell(r, c);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkSolution,
                    icon: const Icon(Icons.check),
                    label: const Text('Check'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neuralBlue,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _initPuzzle,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   Meditation (simple countdown timer)
   -------------------------- */
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({Key? key}) : super(key: key);

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  int _seconds = 120;
  Timer? _timer;
  bool _running = false;

  void _startStop() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 0) {
        t.cancel();
        setState(() => _running = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session complete')),
        );
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _seconds = 120;
      _running = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meditation Timer'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '$mm:$ss',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: _startStop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neuralBlue,
                    ),
                    child: Text(_running ? 'Stop' : 'Start'),
                  ),
                  OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   🧠 Mind Tricks Game
   -------------------------- */

class _MindTrickQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _MindTrickQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class MindTricksScreen extends StatefulWidget {
  const MindTricksScreen({Key? key}) : super(key: key);

  @override
  State<MindTricksScreen> createState() => _MindTricksScreenState();
}

class _MindTricksScreenState extends State<MindTricksScreen> {
  final List<_MindTrickQuestion> _questions = const [
    _MindTrickQuestion(
      question:
          'You\'re running a race and you pass the person in 2nd place. What place are you in now?',
      options: ['1st place', '2nd place', '3rd place'],
      correctIndex: 1,
      explanation:
          'You took the other person\'s position, so you\'re now in 2nd place — not 1st.',
    ),
    _MindTrickQuestion(
      question:
          'A farmer has 17 sheep. All but 9 run away. How many sheep are left?',
      options: ['8', '9', '0'],
      correctIndex: 1,
      explanation:
          '“All but 9” means 9 are left. It doesn\'t say they all ran away.',
    ),
    _MindTrickQuestion(
      question:
          'Some months have 30 days, some have 31. How many months have 28 days?',
      options: ['1', '2', '12'],
      correctIndex: 2,
      explanation:
          'All 12 months have at least 28 days. February just has exactly 28 in common years.',
    ),
    _MindTrickQuestion(
      question:
          'If a doctor gives you 3 pills and tells you to take one every 30 minutes, how long will they last?',
      options: ['1 hour', '1.5 hours', '2 hours'],
      correctIndex: 0,
      explanation:
          'You take the first pill now, the second after 30 minutes, the third after another 30 minutes — that\'s 1 hour total.',
    ),
    _MindTrickQuestion(
      question:
          'You enter a dark room with a single match and see a candle, an oil lamp, and a fireplace. What do you light first?',
      options: ['The candle', 'The lamp', 'The match'],
      correctIndex: 2,
      explanation:
          'You must light the match before you can light anything else.',
    ),
  ];

  int _currentIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedIndex = index;
      _answered = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (!_answered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an answer first 🙂')),
      );
      return;
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _answered = false;
      });
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: const Text(
              'Mind Tricks — Result',
              style: TextStyle(color: AppTheme.neonCyan),
            ),
            content: Text(
              'Score: $_score / ${_questions.length}\nNice brain workout!',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _currentIndex = 0;
                    _score = 0;
                    _selectedIndex = null;
                    _answered = false;
                  });
                },
                child: const Text('Play Again'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];

    Color optionColor(int idx) {
      if (!_answered) return AppTheme.neuralBlue;
      if (idx == q.correctIndex) return Colors.green;
      if (_selectedIndex == idx) return Colors.redAccent;
      return AppTheme.cardDark;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind Tricks'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Score: $_score',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    q.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: q.options.length,
                  itemBuilder: (ctx, idx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () => _selectOption(idx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: optionColor(idx),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            q.options[idx],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_answered)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      q.explanation,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonPurple,
                ),
                child: Text(
                  _currentIndex == _questions.length - 1
                      ? 'Finish'
                      : 'Next',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   🧠 Odd One Out Game
   -------------------------- */

class _OddOneItem {
  final List<String> items;
  final int correctIndex;
  final String explanation;

  const _OddOneItem({
    required this.items,
    required this.correctIndex,
    required this.explanation,
  });
}

class OddOneOutScreen extends StatefulWidget {
  const OddOneOutScreen({Key? key}) : super(key: key);

  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen> {
  final List<_OddOneItem> _list = const [
    _OddOneItem(
      items: ['Cat', 'Dog', 'Cow', 'Car'],
      correctIndex: 3,
      explanation: 'Car is not an animal.',
    ),
    _OddOneItem(
      items: ['Blue', 'Red', 'Green', 'Banana'],
      correctIndex: 3,
      explanation: 'Banana is not a color.',
    ),
    _OddOneItem(
      items: ['Apple', 'Mango', 'Orange', 'Potato'],
      correctIndex: 3,
      explanation: 'Potato is a vegetable, not a fruit.',
    ),
    _OddOneItem(
      items: ['Pen', 'Pencil', 'Eraser', 'Notebook'],
      correctIndex: 2,
      explanation: 'Eraser is used for removing, others are for writing.',
    ),
  ];

  int _index = 0;
  int? _selected;
  int _score = 0;

  void _choose(int i) {
    if (_selected != null) return;
    setState(() => _selected = i);

    if (i == _list[_index].correctIndex) {
      _score++;
    }
  }

  void _next() {
    if (_selected == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose one 🙂')));
      return;
    }

    if (_index < _list.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text(
            'Odd One Out – Result',
            style: TextStyle(color: AppTheme.neonCyan),
          ),
          content: Text(
            'Score: $_score / ${_list.length}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _index = 0;
                  _selected = null;
                  _score = 0;
                });
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _list[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odd One Out'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Which one doesn’t belong?',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(item.items.length, (i) {
                bool correct = i == item.correctIndex;
                bool wrong = _selected == i && !correct;

                Color bg = AppTheme.neuralBlue;
                if (_selected != null) {
                  if (correct) bg = Colors.green;
                  if (wrong) bg = Colors.redAccent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    onPressed: () => _choose(i),
                    style: ElevatedButton.styleFrom(backgroundColor: bg),
                    child: Text(
                      item.items[i],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonPurple,
                ),
                child: Text(_index == _list.length - 1 ? 'Finish' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   Stress Ball (simple interaction)
   -------------------------- */
class StressBallScreen extends StatefulWidget {
  const StressBallScreen({Key? key}) : super(key: key);

  @override
  State<StressBallScreen> createState() => _StressBallScreenState();
}

class _StressBallScreenState extends State<StressBallScreen> {
  double _size = 140;

  void _squeeze() {
    setState(() => _size = max(60, _size - 18));
    Future.delayed(const Duration(milliseconds: 350), () {
      setState(() => _size = min(160, _size + 22));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stress Ball'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Center(
          child: GestureDetector(
            onTap: _squeeze,
            child: GlassCard(
              child: SizedBox(
                width: 260,
                height: 360,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.neuralGradient,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tap to squeeze',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   ⭐ AI Mood Quest
   -------------------------- */

class AIMoodQuestGame extends StatefulWidget {
  const AIMoodQuestGame({Key? key}) : super(key: key);

  @override
  State<AIMoodQuestGame> createState() => _AIMoodQuestGameState();
}

class _AIMoodQuestGameState extends State<AIMoodQuestGame> {
  final TextEditingController _moodCtrl = TextEditingController();
  bool _loading = false;
  String? _quest;

  Future<void> _generateQuest() async {
    final text = _moodCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tell the AI how you feel first 🙂')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _quest = null;
    });

    final result = await GroqAIService.generateGameQuest(text);

    setState(() {
      _quest = result;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _moodCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mood Quest'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'According to your recent feelings…',
                        style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'AI Mood Quest reads how you feel right now and suggests '
                        'one tiny, playful quest — only about games and actions you can do in 1–3 minutes.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How are you feeling?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _moodCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText:
                              'Example:\nTired after college and a bit anxious about tomorrow…',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Get my quest'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.neuralBlue,
                          ),
                          onPressed: _loading ? null : _generateQuest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                )
              else if (_quest != null)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎮 Suggested mini-quest',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _quest!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Try this quest for 1–3 minutes, then notice how your mood shifts.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   NEW: XOX Game (Tic-Tac-Toe)
   -------------------------- */

class XOXGameScreen extends StatefulWidget {
  const XOXGameScreen({Key? key}) : super(key: key);

  @override
  State<XOXGameScreen> createState() => _XOXGameScreenState();
}

class _XOXGameScreenState extends State<XOXGameScreen> {
  List<String> _board = List.filled(9, '');
  String _current = 'X';
  String? _winner;

  void _tap(int index) {
    if (_board[index].isNotEmpty || _winner != null) return;
    setState(() {
      _board[index] = _current;
      _current = _current == 'X' ? 'O' : 'X';
      _winner = _checkWinner();
    });

    if (_winner != null) {
      _showResult(_winner!);
    }
  }

  String? _checkWinner() {
    const wins = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final w in wins) {
      final a = _board[w[0]];
      final b = _board[w[1]];
      final c = _board[w[2]];
      if (a.isNotEmpty && a == b && b == c) return a;
    }
    if (!_board.contains('')) return 'draw';
    return null;
  }

  void _showResult(String result) {
    String msg;
    if (result == 'draw') {
      msg = 'It\'s a draw!';
    } else {
      msg = 'Player $result wins!';
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'XOX Result',
          style: TextStyle(color: AppTheme.neonCyan),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _board = List.filled(9, '');
                _current = 'X';
                _winner = null;
              });
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  Widget _tile(int index) {
    final val = _board[index];
    return GestureDetector(
      onTap: () => _tap(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(
          child: Text(
            val,
            style: TextStyle(
              color: val == 'X' ? Colors.cyanAccent : Colors.pinkAccent,
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _winner == null
        ? 'Turn: Player $_current'
        : (_winner == 'draw' ? 'Draw' : 'Winner: $_winner');

    return Scaffold(
      appBar: AppBar(
        title: const Text('XOX Game'),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GlassCard(
                    child: GridView.builder(
                      itemCount: 9,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                      ),
                      itemBuilder: (ctx, i) => _tile(i),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
   PlaceholderScreen
   -------------------------- */
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.darkBase,
      ),
      body: AnimatedNeuralBackground(
        child: Center(
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.construction,
                  size: 80,
                  color: AppTheme.neonCyan,
                ),
                SizedBox(height: 20),
                Text(
                  '🚀 Future Enhancement',
                  style: TextStyle(
                    color: AppTheme.neonCyan,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Planned: AI-driven soundscapes and adaptive audio. Coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
