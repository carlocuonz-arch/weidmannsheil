import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart'; // Das hier ist neu!

void main() {
  runApp(const WeidmannsheilApp());
}

class HunterTheme {
  static final ThemeData normal = ThemeData(
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    brightness: Brightness.light,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
      bodyLarge: TextStyle(fontSize: 18, color: Colors.black87),
    ),
  );

  static final ThemeData ghostMode = ThemeData(
    primaryColor: Colors.red,
    scaffoldBackgroundColor: Colors.black,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Colors.red,
      secondary: Colors.redAccent,
      surface: Colors.black,
      onSurface: Colors.red,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
      bodyLarge: TextStyle(fontSize: 18, color: Colors.red),
    ),
    iconTheme: const IconThemeData(color: Colors.red),
  );
}

class WeidmannsheilApp extends StatefulWidget {
  const WeidmannsheilApp({super.key});

  @override
  State<WeidmannsheilApp> createState() => _WeidmannsheilAppState();
}

class _WeidmannsheilAppState extends State<WeidmannsheilApp> {
  bool _isGhostMode = false;

  void _toggleGhostMode() {
    setState(() {
      _isGhostMode = !_isGhostMode;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Das kleine "Debug" Banner oben rechts wegmachen
      title: 'Weidmannsheil',
      theme: _isGhostMode ? HunterTheme.ghostMode : HunterTheme.normal,
      home: DashboardPage(
        isGhostMode: _isGhostMode,
        toggleMode: _toggleGhostMode,
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final bool isGhostMode;
  final VoidCallback toggleMode;

  const DashboardPage({super.key, required this.isGhostMode, required this.toggleMode});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _locationMessage = "Standort wird gesucht...";
  String _coordinates = "--";

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Sofort beim Start GPS suchen
  }

  // Die Magie: Hier holen wir die GPS Daten
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Ist GPS überhaupt an?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationMessage = "GPS ist deaktiviert.");
      return;
    }

    // 2. Haben wir die Erlaubnis?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationMessage = "GPS Zugriff verweigert.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationMessage = "GPS dauerhaft verweigert.");
      return;
    }

    // 3. Position holen
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationMessage = "Standort gefunden";
      // Wir runden auf 4 Stellen, Thomas braucht keine Nanometer-Präzision
      _coordinates = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wir holen uns die Farben aus dem aktuellen Theme (Ghost oder Normal)
    final isGhost = widget.isGhostMode;
    final textColor = isGhost ? Colors.red : Colors.green[900];
    final boxColor = isGhost ? Colors.grey[900] : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGhost ? "GHOST MODE" : "Weidmannsheil"),
        backgroundColor: isGhost ? Colors.black : Colors.green[800],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- GPS WIDGET ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isGhost ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, size: 40, color: isGhost ? Colors.red : Colors.green),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_locationMessage, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      Text("Lat/Lon: $_coordinates", style: TextStyle(fontSize: 18, fontFamily: 'Courier', color: textColor)),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- BUTTON ---
            Expanded(
              child: GestureDetector(
                onTap: widget.toggleMode,
                child: Container(
                  decoration: BoxDecoration(
                    color: isGhost ? Colors.red.withOpacity(0.1) : Colors.green[100],
                    border: Border.all(
                      color: isGhost ? Colors.red : Colors.green,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isGhost ? Icons.visibility_off : Icons.visibility,
                        size: 80,
                        color: isGhost ? Colors.red : Colors.green[800],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isGhost ? "JAGD BEENDEN" : "JAGD STARTEN",
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}