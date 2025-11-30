import 'dart:async';
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
  
  // WETTER & SONNE VARIABLEN
  String _weatherTemp = "--°C";
  String _windSpeed = "--";
  String _windDir = "--";
  IconData _weatherIcon = Icons.cloud_off;
  
  String _sunriseTime = "--:--";
  String _sunsetTime = "--:--";
  
  // MOND
  String _moonText = "--";
  String _moonSubText = "Phase";
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

  // LOKALE MOND-PHASEN-BERECHNUNG
  Map<String, dynamic> _calculateMoonPhase() {
    final now = DateTime.now();

    // Referenz: Neumond am 6. Januar 2000, 18:14 UTC
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final daysSinceNewMoon = now.difference(knownNewMoon).inHours / 24.0;

    // Synodischer Monat = 29.53058867 Tage
    const synodicMonth = 29.53058867;
    final phase = (daysSinceNewMoon % synodicMonth) / synodicMonth;

    String phaseName;
    String phaseEmoji;
    IconData phaseIcon;

    if (phase < 0.03 || phase > 0.97) {
      phaseName = "Neumond";
      phaseEmoji = "🌑";
      phaseIcon = Icons.brightness_1;
    } else if (phase < 0.22) {
      phaseName = "Zunehmend";
      phaseEmoji = "🌒";
      phaseIcon = Icons.nightlight;
    } else if (phase < 0.28) {
      phaseName = "1. Viertel";
      phaseEmoji = "🌓";
      phaseIcon = Icons.brightness_6;
    } else if (phase < 0.47) {
      phaseName = "Zunehmend";
      phaseEmoji = "🌔";
      phaseIcon = Icons.nightlight;
    } else if (phase < 0.53) {
      phaseName = "Vollmond";
      phaseEmoji = "🌕";
      phaseIcon = Icons.brightness_1_outlined;
    } else if (phase < 0.72) {
      phaseName = "Abnehmend";
      phaseEmoji = "🌖";
      phaseIcon = Icons.nightlight_outlined;
    } else if (phase < 0.78) {
      phaseName = "Letztes Viertel";
      phaseEmoji = "🌗";
      phaseIcon = Icons.brightness_4;
    } else {
      phaseName = "Abnehmend";
      phaseEmoji = "🌘";
      phaseIcon = Icons.nightlight_outlined;
    }

    final illumination = (phase < 0.5) ? phase * 2 : (1 - phase) * 2;
    final illuminationPercent = (illumination * 100).toInt();

    return {
      'name': phaseName,
      'emoji': phaseEmoji,
      'icon': phaseIcon,
      'percent': illuminationPercent,
    };
  }

  Future<void> _fetchWeatherAndSun() async {
    if (_lat == null || _lon == null) return;

    setState(() => _isLoadingWeather = true);

    try {
      String urlString = 'https://api.open-meteo.com/v1/forecast?'
          'latitude=$_lat&longitude=$_lon'
          '&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m'
          '&daily=sunrise,sunset'
          '&wind_speed_unit=kmh'
          '&timezone=Europe/Berlin';

      final response = await http.get(Uri.parse(urlString));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 1. Wetter
        String tmpTemp = "--°C";
        String tmpWindS = "--";
        String tmpWindD = "--";
        IconData tmpIcon = Icons.cloud_off;

        try {
          final current = data['current'];
          tmpTemp = "${current['temperature_2m']}°C";
          tmpWindS = "${current['wind_speed_10m']} km/h";
          tmpWindD = _getWindDirection(current['wind_direction_10m']);
          tmpIcon = _getWeatherIcon(current['weather_code']);
        } catch (e) { print("Wetter Fehler: $e"); }

        // 2. Sonne
        String tmpRise = "--:--";
        String tmpSet = "--:--";
        try {
          final daily = data['daily'];
          String rawSunrise = daily['sunrise'][0].toString();
          String rawSunset = daily['sunset'][0].toString();
          tmpRise = rawSunrise.contains('T') ? rawSunrise.split('T').last : rawSunrise;
          tmpSet = rawSunset.contains('T') ? rawSunset.split('T').last : rawSunset;
        } catch (e) { print("Sonne Fehler: $e"); }

        // 3. MOND - LOKALE BERECHNUNG!
        final moonData = _calculateMoonPhase();
        String tmpMoonTxt = moonData['emoji'];
        String tmpMoonSub = "${moonData['name']} ${moonData['percent']}%";
        IconData tmpMoonIco = moonData['icon'];

        setState(() {
          _weatherTemp = tmpTemp;
          _windSpeed = tmpWindS;
          _windDir = tmpWindD;
          _weatherIcon = tmpIcon;
          _sunriseTime = tmpRise;
          _sunsetTime = tmpSet;

          _moonText = tmpMoonTxt;
          _moonSubText = tmpMoonSub;
          _moonIcon = tmpMoonIco;

          _isLoadingWeather = false;
        });

      } else {
        print("Server Antwort: ${response.body}");
        throw Exception('API Status: ${response.statusCode}');
      }
    } catch (e) {
      print("Globaler Fehler: $e");
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
            // --- OPTIMIERTES DASHBOARD - GRÖßER & ÜBERSICHTLICHER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Mehr Padding: 10/15 -> 16/20
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isGhost ? [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 15)] : [const BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2)],
                border: Border.all(color: isGhost ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.3), width: 2),
              ),
              child: _isLoadingWeather
                ? Center(child: CircularProgressIndicator(color: isGhost ? Colors.red : Colors.green))
                : Column(
                  children: [
                    // OBERE REIHE - MEHR ABSTAND
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temp - Größer
                        _buildWeatherCard(
                          _weatherIcon,
                          _weatherTemp,
                          "Temperatur",
                          iconColor,
                          textColor,
                          isGhost,
                        ),

                        // MOND - Mit Emoji!
                        _buildWeatherCard(
                          _moonIcon,
                          _moonText,
                          _moonSubText,
                          isGhost ? Colors.red : Colors.blueGrey,
                          textColor,
                          isGhost,
                        ),

                        // Wind - Klickbar für Refresh
                        InkWell(
                          onTap: _fetchWeatherAndSun,
                          borderRadius: BorderRadius.circular(15),
                          child: _buildWeatherCard(
                            Icons.air,
                            _windDir,
                            _windSpeed,
                            textColor.withOpacity(0.8),
                            textColor,
                            isGhost,
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 20), // Mehr Abstand: 15 -> 20
                    Divider(color: textColor.withOpacity(0.3), thickness: 1.5), // Dicker
                    const SizedBox(height: 15),

                    // UNTERE REIHE - SONNE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSunTime(Icons.wb_twilight, "Aufgang", _sunriseTime, textColor, isGhost),
                        Container(height: 40, width: 2, color: textColor.withOpacity(0.3)), // Größer
                        _buildSunTime(Icons.nights_stay, "Untergang", _sunsetTime, textColor, isGhost),
                      ],
                    ),
                  ],
                ),
            ),
            
            const SizedBox(height: 12),
            // VERBESSERTER STANDORT
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isGhost ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isGhost ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: isGhost ? Colors.red : Colors.green[700],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _locationMessage,
                      style: TextStyle(
                        color: isGhost ? Colors.grey : Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // --- ANIMIERTER HAUPT BUTTON ---
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  widget.toggleMode();
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: isGhost ? 1.0 : 1.02),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isGhost ? Colors.red.withOpacity(0.15) : Colors.green[100],
                          border: Border.all(
                            color: isGhost ? Colors.red : Colors.green,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isGhost ? Colors.red : Colors.green).withOpacity(0.3),
                              blurRadius: isGhost ? 10 : 20,
                              spreadRadius: isGhost ? 0 : 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isGhost ? Icons.visibility_off : Icons.visibility,
                              size: 90, // Größer: 80 -> 90
                              color: isGhost ? Colors.red : Colors.green[800],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isGhost ? "JAGD BEENDEN" : "JAGD STARTEN",
                              style: Theme.of(context).textTheme.displayLarge,
                            ),
                            if (!isGhost) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Antippen zum Starten",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
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

  // OPTIMIERTE WETTER-KARTE
  Widget _buildWeatherCard(IconData icon, String mainText, String subText, Color iconColor, Color textColor, bool isGhost) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGhost ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: iconColor), // Größer: 35 -> 42
          const SizedBox(height: 8),
          Text(
            mainText,
            style: TextStyle(
              fontSize: 22, // Größer: 20 -> 22
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSunTime(IconData icon, String label, String time, Color color, bool isGhost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGhost ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 28), // Größer: 24 -> 28
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
              Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)), // Größer: 14 -> 16
            ],
          )
        ],
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