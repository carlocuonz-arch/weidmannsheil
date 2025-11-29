import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> animals = [
    {"name": "Hirsch", "icon": Icons.forest, "desc": "Röhren (Brunft)", "file": "hirsch.mp3"},
    {"name": "Rehbock", "icon": Icons.pets, "desc": "Plätzen", "file": "rehbock.mp3"},
    {"name": "Kitz", "icon": Icons.child_care, "desc": "Fiep-Laut", "file": "kitz.mp3"},
    {"name": "Wildsau", "icon": Icons.grass, "desc": "Grunzen", "file": "wildsau.mp3"},
    {"name": "Gemse", "icon": Icons.filter_hdr, "desc": "Warnpfiff", "file": "gemse.mp3"},
    {"name": "Ente", "icon": Icons.waves, "desc": "Lockruf", "file": "ente.mp3"},
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
        title: Text("Jagd-Blatter", style: TextStyle(color: isGhost ? Colors.red : Colors.white)),
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
                    cardColor,
                    textColor,
                    isGhost,
                    isActive, // Neu: Sagen ob aktiv
                  );
                },
              ),
            ),
          ),

          // --- DER NEUE PLAYER BALKEN ---
          // Er erscheint immer, wenn ein Titel ausgewählt wurde
          if (_currentTitle != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGhost ? Colors.grey[900] : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
                border: Border(top: BorderSide(color: isGhost ? Colors.red : Colors.green, width: 2)),
              ),
              child: Column(
                children: [
                  // Titel Info
                  Text(
                    "Aktuell: $_currentTitle",
                    style: TextStyle(
                      color: isGhost ? Colors.red : Colors.black87, 
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Loop Button
                      IconButton(
                        onPressed: _toggleLoop,
                        icon: Icon(Icons.repeat, color: _isLooping ? (isGhost ? Colors.red : Colors.green) : Colors.grey),
                        tooltip: "Wiederholung",
                      ),
                      
                      // Play / Pause Button (Groß)
                      FloatingActionButton(
                        onPressed: _togglePlayPause,
                        backgroundColor: isGhost ? Colors.red : Colors.green,
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      ),

                      // STOP BUTTON (Wichtig!)
                      IconButton(
                        onPressed: _stopSound,
                        icon: const Icon(Icons.stop_circle_outlined, size: 32),
                        color: isGhost ? Colors.redAccent : Colors.red,
                        tooltip: "SOFORT STOPPEN",
                      ),
                    ],
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard(String title, String sub, IconData icon, String fileName, Color? bg, Color? text, bool isGhost, bool isActive) {
    return GestureDetector(
      onTap: () {
        _playSound(fileName, title);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? (isGhost ? Colors.red.withOpacity(0.2) : Colors.green[100]) : bg, // Highlight wenn aktiv
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            if (!isGhost) 
              const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
          border: Border.all(
            color: isActive 
                ? (isGhost ? Colors.red : Colors.green) 
                : (isGhost ? Colors.red.withOpacity(0.5) : Colors.transparent),
            width: isActive ? 3 : 1
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: isGhost ? Colors.red : Colors.green[700]),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
            Text(sub, style: TextStyle(fontSize: 14, color: isGhost ? Colors.red.withOpacity(0.7) : Colors.grey[600])),
            if (isActive) ...[
              const SizedBox(height: 5),
              Icon(Icons.equalizer, color: isGhost ? Colors.red : Colors.green, size: 20) // Kleines Equalizer Icon
            ]
          ],
        ),
      ),
    );
  }
}