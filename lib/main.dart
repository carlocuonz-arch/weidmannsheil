import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'blatter_page.dart';
import 'map_page.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'Waidmannsheil',
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
  String _locationMessage = "Suche GPS...";
  String _coordinates = "--";
  
  // WETTER VARIABLEN
  String _weatherTemp = "--°C";
  String _windSpeed = "-- km/h";
  String _windDir = "--";
  IconData _weatherIcon = Icons.cloud_off;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _determinePosition(); 
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationMessage = "GPS ist aus");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationMessage = "Kein GPS Zugriff");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationMessage = "GPS dauerhaft verweigert");
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationMessage = "Standort gefunden";
      _coordinates = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
    });

    _fetchWeather(position.latitude, position.longitude);
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    setState(() => _isLoadingWeather = true);

    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m&wind_speed_unit=kmh');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        final temp = current['temperature_2m'];
        final windS = current['wind_speed_10m'];
        final windD = current['wind_direction_10m'];
        final wCode = current['weather_code'];

        setState(() {
          _weatherTemp = "$temp°C";
          _windSpeed = "$windS km/h";
          _windDir = _getWindDirection(windD);
          _weatherIcon = _getWeatherIcon(wCode);
          _isLoadingWeather = false;
        });
      } else {
        throw Exception('Server Fehler');
      }
    } catch (e) {
      print("Wetter Fehler: $e");
      setState(() {
        _weatherTemp = "Fehler";
        _isLoadingWeather = false;
      });
    }
  }

  String _getWindDirection(int degrees) {
    const directions = ["Nord", "Nord-Ost", "Ost", "Süd-Ost", "Süd", "Süd-West", "West", "Nord-West"];
    return directions[((degrees + 22.5) % 360) ~/ 45];
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code >= 1 && code <= 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.beach_access;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 95) return Icons.flash_on;
    return Icons.wb_cloudy;
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.isGhostMode;
    
    // --- HIER WAR DER FEHLER: Wir fügen "!" hinzu um sicher zu sein ---
    final Color textColor = isGhost ? Colors.red : Colors.green[900]!; 
    final Color boxColor = isGhost ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGhost ? "GHOST MODE" : "Waidmannsheil"),
        backgroundColor: isGhost ? Colors.black : Colors.green[800],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isGhost ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
                border: Border.all(color: isGhost ? Colors.red.withOpacity(0.5) : Colors.transparent),
              ),
              child: _isLoadingWeather 
                ? Center(child: CircularProgressIndicator(color: isGhost ? Colors.red : Colors.green))
                : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Icon(_weatherIcon, size: 50, color: isGhost ? Colors.red : Colors.orange),
                        const SizedBox(height: 5),
                        Text(_weatherTemp, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text("Wind:", style: TextStyle(fontSize: 16, color: textColor)),
                            const SizedBox(width: 5),
                            Icon(Icons.air, color: textColor),
                          ],
                        ),
                        Text(_windDir, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        Text(_windSpeed, style: TextStyle(fontSize: 16, color: textColor)),
                      ],
                    )
                  ],
                ),
            ),
            
            const SizedBox(height: 10),
            
            Center(
              child: Text(
                "$_locationMessage ($_coordinates)",
                style: TextStyle(color: isGhost ? Colors.grey : Colors.grey[600], fontSize: 12),
              ),
            ),

            const SizedBox(height: 20),
            
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
            
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildToolButton(context, Icons.surround_sound, "Blatter", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BlatterPage(isGhostMode: isGhost)));
                  }, boxColor, textColor),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildToolButton(context, Icons.map, "Karte & Log", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage(isGhostMode: isGhost)));
                  }, boxColor, textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, IconData icon, String label, VoidCallback onTap, Color bg, Color text) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: text,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
      ),
      onPressed: onTap,
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