import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const WeidmannsheilApp());
}

// Boss, hier definieren wir unser Farb-Thema für den Jagd-Modus
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
    // Alles wird Rot/Schwarz für die Nachtsicht
    colorScheme: const ColorScheme.dark(
      primary: Colors.red,
      secondary: Colors.redAccent,
      surface: Colors.black,
      onSurface: Colors.red, // Textfarbe auf Schwarz
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
    // Haptisches Feedback (Vibration), damit er spürt, dass was passiert
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weidmannsheil',
      theme: _isGhostMode ? HunterTheme.ghostMode : HunterTheme.normal,
      home: DashboardPage(
        isGhostMode: _isGhostMode,
        toggleMode: _toggleGhostMode,
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final bool isGhostMode;
  final VoidCallback toggleMode;

  const DashboardPage({
    super.key,
    required this.isGhostMode,
    required this.toggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isGhostMode ? "GHOST MODE AKTIV" : "Weidmannsheil, Thomas"),
        backgroundColor: isGhostMode ? Colors.black : Colors.green[800],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wetter Widget (Platzhalter)
            _buildInfoCard(
              context,
              icon: Icons.wind_power,
              title: "Wind: Ost 12km/h",
              subtitle: "Perfekt für den Hochsitz am Waldrand",
            ),
            const SizedBox(height: 20),
            
            // Der Haupt-Button
            Expanded(
              child: GestureDetector(
                onTap: toggleMode,
                child: Container(
                  decoration: BoxDecoration(
                    color: isGhostMode ? Colors.red.withOpacity(0.1) : Colors.green[100],
                    border: Border.all(
                      color: isGhostMode ? Colors.red : Colors.green,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isGhostMode ? Icons.visibility_off : Icons.visibility,
                        size: 80,
                        color: isGhostMode ? Colors.red : Colors.green[800],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isGhostMode ? "JAGD BEENDEN" : "JAGD STARTEN",
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGhostMode ? "Display gedimmt. Töne aus." : "Auf in den Wald.",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Grid für Tools
            Row(
              children: [
                Expanded(child: _buildToolButton(context, Icons.surround_sound, "Blatter")),
                const SizedBox(width: 15),
                Expanded(child: _buildToolButton(context, Icons.map, "Karte & Log")),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGhostMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isGhostMode ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: isGhostMode ? Colors.red : Colors.green),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(subtitle, style: const TextStyle(fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, IconData icon, String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isGhostMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isGhostMode ? Colors.red : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isGhostMode ? Colors.red : Colors.transparent)
        ),
      ),
      onPressed: () {
        // Hier kommt später die Navigation hin
      },
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}