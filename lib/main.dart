import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  String _locationMessage = "GPS...";
  
  // WETTER
  String _weatherTemp = "--°C";
  String _windSpeed = "--";
  String _windDir = "--";
  IconData _weatherIcon = Icons.cloud_off;
  
  // SONNE & MOND
  String _sunriseTime = "--:--";
  String _sunsetTime = "--:--";
  String _moonText = "--"; 
  String _moonSubText = "Licht";
  IconData _moonIcon = Icons.nightlight_round;
  
  bool _isLoadingWeather = false;
  double? _lat;
  double? _lon;

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
      setState(() => _locationMessage = "GPS aus");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationMessage = "Kein GPS");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationMessage = "GPS verweigert");
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _lat = position.latitude;
      _lon = position.longitude;
      _locationMessage = "${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}";
    });

    _fetchWeatherAndSun();
  }

  // --- API LOGIK (Mit präzisem Mond) ---
  Future<void> _fetchWeatherAndSun() async {
    if (_lat == null || _lon == null) return;

    setState(() => _isLoadingWeather = true);

    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lon&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m&daily=sunrise,sunset,moon_phase&wind_speed_unit=kmh&timezone=auto');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final current = data['current'];
        final daily = data['daily'];

        // Zeiten
        String rawSunrise = daily['sunrise'][0].toString();
        String rawSunset = daily['sunset'][0].toString();
        String sRise = rawSunrise.contains('T') ? rawSunrise.split('T').last : rawSunrise;
        String sSet = rawSunset.contains('T') ? rawSunset.split('T').last : rawSunset;

        // --- MOND LOGIK VERBESSERT ---
        // 0.0 = Neumond, 0.5 = Vollmond, 1.0 = Neumond
        double phase = (daily['moon_phase'][0] as num).toDouble();
        
        // Berechnung der Beleuchtung in Prozent (0.5 ist 100%, 0.0/1.0 ist 0%)
        int illumination = ((1 - (phase - 0.5).abs() * 2) * 100).round();
        
        String mStatus = "";
        IconData mIcon = Icons.nightlight_round;

        if (phase <= 0.03 || phase >= 0.97) {
          mStatus = "Neumond";
          mIcon = Icons.circle_outlined;
        } else if (phase >= 0.47 && phase <= 0.53) {
          mStatus = "Vollmond";
          mIcon = Icons.brightness_1; 
        } else if (phase < 0.5) {
          mStatus = "Zunehmend";
          mIcon = Icons.brightness_2; // Sichel
        } else {
          mStatus = "Abnehmend";
          mIcon = Icons.brightness_3; // Sichel
        }

        setState(() {
          _weatherTemp = "${current['temperature_2m']}°C";
          _windSpeed = "${current['wind_speed_10m']} km/h";
          _windDir = _getWindDirection(current['wind_direction_10m']);
          _weatherIcon = _getWeatherIcon(current['weather_code']);
          
          _sunriseTime = sRise;
          _sunsetTime = sSet;
          
          _moonText = "$illumination%"; // Groß oben: Prozent
          _moonSubText = mStatus;       // Klein unten: Zunehmend/Abnehmend
          _moonIcon = mIcon;

          _isLoadingWeather = false;
        });

      } else {
        throw Exception('API Fehler');
      }
    } catch (e) {
      print("Fehler: $e");
      setState(() {
        _weatherTemp = "--";
        _isLoadingWeather = false;
      });
    }
  }

  String _getWindDirection(int degrees) {
    const directions = ["Nord", "NO", "Ost", "SO", "Süd", "SW", "West", "NW"];
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
    final Color textColor = isGhost ? Colors.red : Colors.green[900]!; 
    final Color boxColor = isGhost ? Colors.grey[900]! : Colors.white;
    final Color iconColor = isGhost ? Colors.red : Colors.orange;

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
            // --- DASHBOARD ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isGhost ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
                border: Border.all(color: isGhost ? Colors.red.withOpacity(0.5) : Colors.transparent),
              ),
              child: _isLoadingWeather 
                ? Center(child: CircularProgressIndicator(color: isGhost ? Colors.red : Colors.green))
                : Column(
                  children: [
                    // OBERE REIHE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temp
                        Column(
                          children: [
                            Icon(_weatherIcon, size: 35, color: iconColor),
                            const SizedBox(height: 5),
                            Text(_weatherTemp, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                          ],
                        ),
                        
                        // MOND (Gefixed)
                        Column(
                          children: [
                            Icon(_moonIcon, size: 30, color: isGhost ? Colors.red : Colors.blueGrey),
                            const SizedBox(height: 5),
                            // HIER: Prozentzahl groß, Status klein
                            Text(_moonText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                            Text(_moonSubText, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
                          ],
                        ),

                        // Wind
                        InkWell(
                          onTap: _fetchWeatherAndSun,
                          child: Column(
                            children: [
                              Icon(Icons.air, size: 35, color: textColor.withOpacity(0.8)),
                              const SizedBox(height: 5),
                              Text(_windDir, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                              Text(_windSpeed, style: TextStyle(fontSize: 12, color: textColor)),
                            ],
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    Divider(color: textColor.withOpacity(0.2), thickness: 1),
                    const SizedBox(height: 10),

                    // UNTERE REIHE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSunTime(Icons.wb_twilight, "Aufgang", _sunriseTime, textColor),
                        Container(height: 30, width: 1, color: textColor.withOpacity(0.2)),
                        _buildSunTime(Icons.nights_stay, "Untergang", _sunsetTime, textColor),
                      ],
                    ),
                  ],
                ),
            ),
            
            const SizedBox(height: 10),
            Center(child: Text("Standort: $_locationMessage", style: TextStyle(color: isGhost ? Colors.grey : Colors.grey[600], fontSize: 12))),
            const SizedBox(height: 20),
            
            // --- HAUPT BUTTON ---
            Expanded(
              child: GestureDetector(
                onTap: widget.toggleMode,
                child: Container(
                  decoration: BoxDecoration(
                    color: isGhost ? Colors.red.withOpacity(0.1) : Colors.green[100],
                    border: Border.all(color: isGhost ? Colors.red : Colors.green, width: 4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isGhost ? Icons.visibility_off : Icons.visibility, size: 80, color: isGhost ? Colors.red : Colors.green[800]),
                      const SizedBox(height: 20),
                      Text(isGhost ? "JAGD BEENDEN" : "JAGD STARTEN", style: Theme.of(context).textTheme.displayLarge),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- WERKZEUGE ---
            Row(
              children: [
                Expanded(child: _buildToolButton(context, Icons.surround_sound, "Blatter", () { Navigator.push(context, MaterialPageRoute(builder: (context) => BlatterPage(isGhostMode: isGhost))); }, boxColor, textColor)),
                const SizedBox(width: 15),
                Expanded(child: _buildToolButton(context, Icons.map, "Karte & Log", () { Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage(isGhostMode: isGhost))); }, boxColor, textColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSunTime(IconData icon, String label, String time, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.6), size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
            Text(time, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        )
      ],
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