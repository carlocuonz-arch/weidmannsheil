import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class BlatterPage extends StatefulWidget {
  final bool isGhostMode;

  const BlatterPage({super.key, required this.isGhostMode});

  @override
  State<BlatterPage> createState() => _BlatterPageState();
}

class _BlatterPageState extends State<BlatterPage> {
  // Der Audio-Spieler
  final AudioPlayer _player = AudioPlayer();

  // Status-Variablen für unseren Player
  bool _isPlaying = false;
  bool _isLooping = false;
  String? _currentTitle; // Welches Tier läuft gerade?
  double _volume = 1.0; // Lautstärke (0.0 - 1.0)

  // OPTIMIERTE TIER-LISTE MIT BESSEREN ICONS & FARBEN
  final List<Map<String, dynamic>> animals = [
    {"name": "Hirsch", "icon": Icons.place, "desc": "Röhren (Brunft)", "file": "hirsch.mp3", "color": Color(0xFF8B4513)}, // Braun
    {"name": "Rehbock", "icon": Icons.nature, "desc": "Plätzen", "file": "rehbock.mp3", "color": Color(0xFFD2691E)}, // Hell-Braun
    {"name": "Kitz", "icon": Icons.pets, "desc": "Fiep-Laut", "file": "kitz.mp3", "color": Color(0xFFDEB887)}, // Beige
    {"name": "Wildsau", "icon": Icons.landscape, "desc": "Grunzen", "file": "wildsau.mp3", "color": Color(0xFF696969)}, // Dunkelgrau
    {"name": "Gemse", "icon": Icons.terrain, "desc": "Warnpfiff", "file": "gemse.mp3", "color": Color(0xFF708090)}, // Schiefergrau
    {"name": "Ente", "icon": Icons.water, "desc": "Lockruf", "file": "ente.mp3", "color": Color(0xFF4682B4)}, // Stahlblau
  ];

  @override
  void initState() {
    super.initState();
    
    // Wir hören auf den Player: Wenn der Sound fertig ist, setzen wir den Status zurück
    _player.onPlayerComplete.listen((event) {
      if (!_isLooping) {
        setState(() {
          _isPlaying = false;
          // Wir lassen den Titel stehen, damit er ihn nochmal starten kann
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Logik: Sound starten
  Future<void> _playSound(String fileName, String title) async {
    try {
      await _player.stop(); // Erstmal Ruhe
      await _player.setVolume(_volume); // Lautstärke setzen
      await _player.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(AssetSource('sounds/$fileName'));

      setState(() {
        _currentTitle = title;
        _isPlaying = true;
      });
    } catch (e) {
      print("Fehler: $e");
    }
  }

  // Logik: Lautstärke ändern
  Future<void> _setVolume(double volume) async {
    await _player.setVolume(volume);
    setState(() {
      _volume = volume;
    });
  }

  // Logik: Toggle Play/Pause
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  // Logik: Not-Aus (Stop)
  Future<void> _stopSound() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // Logik: Loop umschalten
  Future<void> _toggleLoop() async {
    setState(() {
      _isLooping = !_isLooping;
    });
    // Dem Player sofort sagen, ob er loopen soll
    await _player.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.stop);
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.isGhostMode;
    final textColor = isGhost ? Colors.red : Colors.green[900];
    final bgColor = isGhost ? Colors.black : const Color(0xFFF5F5F5);
    final cardColor = isGhost ? Colors.grey[900] : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Lockrufe", style: TextStyle(color: isGhost ? Colors.red : Colors.white)),
        backgroundColor: isGhost ? Colors.black : Colors.green[800],
        iconTheme: IconThemeData(color: isGhost ? Colors.red : Colors.white),
      ),
      body: Column(
        children: [
          // Disclaimer oben
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGhost ? Colors.red.withOpacity(0.1) : Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isGhost ? Colors.red : Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: isGhost ? Colors.red : Colors.orange[900]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "ACHTUNG: Nur zu Übungszwecken verwenden!",
                      style: TextStyle(color: isGhost ? Colors.red : Colors.orange[900], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Das Grid (nimmt den verfügbaren Platz bis zum Player ein)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemCount: animals.length,
                itemBuilder: (context, index) {
                  // Prüfen ob DIESES Tier gerade läuft (für visuelles Highlight)
                  bool isActive = _currentTitle == animals[index]['name'] && _isPlaying;

                  return _buildAnimalCard(
                    animals[index]['name'],
                    animals[index]['desc'],
                    animals[index]['icon'],
                    animals[index]['file'],
                    animals[index]['color'], // Individuelle Farbe
                    cardColor,
                    textColor,
                    isGhost,
                    isActive,
                  );
                },
              ),
            ),
          ),

          // --- OPTIMIERTER PLAYER BALKEN MIT LAUTSTÄRKE ---
          if (_currentTitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isGhost ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -3))
                ],
                border: Border(top: BorderSide(color: isGhost ? Colors.red : Colors.green, width: 3)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titel Info mit Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        color: isGhost ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentTitle!,
                        style: TextStyle(
                          color: isGhost ? Colors.red : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Steuerung
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Loop Button
                      Container(
                        decoration: BoxDecoration(
                          color: _isLooping
                              ? (isGhost ? Colors.red : Colors.green).withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _toggleLoop,
                          icon: Icon(
                            Icons.repeat,
                            color: _isLooping
                                ? (isGhost ? Colors.red : Colors.green)
                                : Colors.grey,
                            size: 28,
                          ),
                          tooltip: "Wiederholung",
                        ),
                      ),

                      // Play / Pause Button (Größer)
                      FloatingActionButton.large(
                        onPressed: _togglePlayPause,
                        backgroundColor: isGhost ? Colors.red : Colors.green,
                        elevation: 8,
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                        ),
                      ),

                      // STOP BUTTON
                      IconButton(
                        onPressed: _stopSound,
                        icon: const Icon(Icons.stop_circle, size: 36),
                        color: isGhost ? Colors.redAccent : Colors.red[700],
                        tooltip: "Stoppen",
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // LAUTSTÄRKE-REGLER
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isGhost ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _volume == 0 ? Icons.volume_off : Icons.volume_up,
                          color: isGhost ? Colors.red : Colors.green,
                          size: 24,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: isGhost ? Colors.red : Colors.green,
                              inactiveTrackColor: Colors.grey[400],
                              thumbColor: isGhost ? Colors.red : Colors.green,
                              overlayColor: (isGhost ? Colors.red : Colors.green).withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: _setVolume,
                            ),
                          ),
                        ),
                        Text(
                          "${(_volume * 100).toInt()}%",
                          style: TextStyle(
                            color: isGhost ? Colors.grey : Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // OPTIMIERTE TIER-KARTE MIT INDIVIDUELLEN FARBEN
  Widget _buildAnimalCard(
    String title,
    String sub,
    IconData icon,
    String fileName,
    Color animalColor, // Individuelle Tierfarbe
    Color? bgColor,
    Color? textColor,
    bool isGhost,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact(); // Haptisches Feedback
        _playSound(fileName, title);
      },
      child: Container(
        decoration: BoxDecoration(
          // Gradient-Hintergrund mit Tierfarbe
          gradient: LinearGradient(
            colors: isActive
                ? [
                    animalColor.withOpacity(0.4),
                    animalColor.withOpacity(0.2),
                  ]
                : [
                    isGhost ? Colors.grey[850]! : Colors.white,
                    isGhost ? Colors.grey[900]! : Colors.grey[50]!,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isActive ? animalColor.withOpacity(0.4) : Colors.black12,
              blurRadius: isActive ? 12 : 6,
              offset: Offset(0, isActive ? 4 : 2),
            )
          ],
          border: Border.all(
            color: isActive ? animalColor : animalColor.withOpacity(0.3),
            width: isActive ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon mit farbigem Hintergrund
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: animalColor.withOpacity(isActive ? 0.3 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48, // Größer: 40 -> 48
                color: animalColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 19, // Größer: 20 -> 19 (besser lesbar)
                fontWeight: FontWeight.bold,
                color: isGhost ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 13, // Größer: 14 -> 13
                color: isGhost
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              // Animierter Equalizer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.graphic_eq, color: animalColor, size: 24),
                  const SizedBox(width: 4),
                  Text(
                    "SPIELT",
                    style: TextStyle(
                      color: animalColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}