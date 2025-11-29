import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class MapPage extends StatefulWidget {
  final bool isGhostMode;

  const MapPage({super.key, required this.isGhostMode});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng _currentPosition = LatLng(46.9480, 7.4474);
  LatLng _targetPosition = LatLng(46.9480, 7.4474); 
  bool _manualSelection = false;

  final MapController _mapController = MapController();
  List<MapEntry> _entries = [];
  
  bool _isTracking = false;
  List<LatLng> _trackingPath = [];
  List<Marker> _trackingMarkers = [];

  @override
  void initState() {
    super.initState();
    _locateUser();
    _loadEntries();
  }

  // --- SAFE LOAD ---
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('jagd_logbuch');
    
    if (dataString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(dataString);
        setState(() {
          _entries = decoded.map((item) {
            try { return MapEntry.fromMap(item); } catch (e) { return null; }
          }).whereType<MapEntry>().toList();
        });
      } catch (e) { print("Daten-Crash: $e"); }
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String dataString = jsonEncode(_entries.map((e) => e.toMap()).toList());
    await prefs.setString('jagd_logbuch', dataString);
  }

  // --- DER INTELLIGENTE EXPORT ---
  Future<void> _exportData() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nichts zu sichern!")));
      return;
    }

    try {
      final String dataString = jsonEncode(_entries.map((e) => e.toMap()).toList());
      
      // Weiche: Windows oder Handy?
      if (Platform.isWindows) {
        // --- WINDOWS: SPEICHERN ---
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}\\Weidmannsheil_Backup.txt';
        final file = File(path);
        await file.writeAsString(dataString);
        
        // Info Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Datei gespeichert"),
            content: Text("Da Windows 'Teilen' oft nicht mag, habe ich die Datei hier gespeichert:\n\n$path"),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      } else {
        // --- HANDY: TEILEN (WhatsApp etc.) ---
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/Weidmannsheil_Backup.txt');
        await file.writeAsString(dataString, flush: true);
        
        // Warten, damit File-System ready ist
        await Future.delayed(const Duration(milliseconds: 300));

        // Teilen der DATEI
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Mein Jagd-Logbuch Backup', // Optionaler Text dazu
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
    }
  }

  // --- IMPORT DATEI ---
  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        final List<dynamic> decoded = jsonDecode(content);
        List<MapEntry> newEntries = decoded.map((item) {
            try { return MapEntry.fromMap(item); } catch (e) { return null; }
          }).whereType<MapEntry>().toList();

        if (newEntries.isNotEmpty) {
          setState(() {
            _entries.addAll(newEntries);
            // Sortieren: Neueste zuerst
            _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          });
          _saveEntries();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${newEntries.length} Einträge erfolgreich importiert!"), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Die Datei war leer oder ungültig.")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import fehlgeschlagen: $e")));
    }
  }

  void _showSettingsDialog() {
    final textColor = widget.isGhostMode ? Colors.red : Colors.black;
    final dialogBg = widget.isGhostMode ? Colors.grey[900] : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text("Datensicherung", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.upload_file, color: textColor),
                title: Text("Backup erstellen (Export)", style: TextStyle(color: textColor)),
                subtitle: Text("Erzeugt eine Datei zum Senden", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                onTap: () { Navigator.pop(context); _exportData(); },
              ),
              Divider(color: Colors.grey),
              ListTile(
                leading: Icon(Icons.download, color: textColor),
                title: Text("Backup einspielen (Import)", style: TextStyle(color: textColor)),
                subtitle: Text("Lädt Daten aus einer Datei", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                onTap: () { Navigator.pop(context); _importData(); },
              ),
              Divider(color: Colors.grey),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text("Alle Daten löschen", style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() { _entries.clear(); });
                  _saveEntries();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Schließen")) ],
        );
      },
    );
  }

  Future<void> _locateUser() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        if (!_manualSelection) {
          _targetPosition = _currentPosition;
        }
      });
      if (!_manualSelection && !_isTracking) {
        _mapController.move(_currentPosition, 16.0);
      }
    } catch (e) { print("Kein GPS: $e"); }
  }

  void _resetToGPS() {
    setState(() {
      _manualSelection = false;
      _targetPosition = _currentPosition;
    });
    _mapController.move(_currentPosition, 16.0);
  }

  Future<Map<String, dynamic>> _getEnviromentData(double lat, double lon) async {
    String weatherInfo = "Kein Netz";
    double altitude = 0.0;
    try {
      Position pos = await Geolocator.getCurrentPosition();
      altitude = pos.altitude;
    } catch (e) { print(e); }
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,wind_direction_10m&wind_speed_unit=kmh');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['current']['temperature_2m'];
        final int? windDeg = data['current']['wind_direction_10m'];
        final windDir = windDeg != null ? _getWindDirection(windDeg) : "-";
        weatherInfo = "$temp°C, $windDir";
      }
    } catch (e) { print(e); }
    return {'weather': weatherInfo, 'altitude': altitude};
  }

  String _getWindDirection(int degrees) {
    const directions = ["N", "NO", "O", "SO", "S", "SW", "W", "NW"];
    return directions[((degrees + 22.5) % 360) ~/ 45];
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
      if (_isTracking) {
        _trackingPath = [];
        _trackingMarkers = [];
        _addTrackingPoint("Anschuss", Icons.gps_fixed, Colors.orange, _currentPosition);
      } else {
        _trackingPath = [];
        _trackingMarkers = [];
      }
    });
  }

  void _addTrackingPoint(String type, IconData icon, Color color, LatLng pos) {
    setState(() {
      _trackingPath.add(pos);
      _trackingMarkers.add(Marker(
        point: pos,
        width: 40, height: 40,
        child: Icon(icon, color: color, size: 28),
      ));
    });
  }

  Future<void> _finishTracking() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysiere Daten..."), duration: Duration(milliseconds: 500)));
    final envData = await _getEnviromentData(_currentPosition.latitude, _currentPosition.longitude);
    _finishTrackingDialog(envData);
  }

  void _finishTrackingDialog(Map<String, dynamic> envData) {
    String animal = "Hirsch";
    String note = "Nachsuche: ${_trackingPath.length} Punkte.";
    final textColor = widget.isGhostMode ? Colors.red : Colors.black;
    final dialogBg = widget.isGhostMode ? Colors.grey[900] : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text("Nachsuche beenden", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               DropdownButtonFormField<String>(
                dropdownColor: dialogBg,
                value: animal,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                items: ["Hirsch", "Reh", "Wildsau", "Gemse", "Fuchs", "Sonstiges"].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => animal = v!,
                decoration: InputDecoration(labelText: "Wildart", labelStyle: TextStyle(color: textColor)),
              ),
              TextField(
                controller: TextEditingController(text: note),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(labelText: "Notiz", labelStyle: TextStyle(color: textColor)),
                onChanged: (v) => note = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
              onPressed: () {
                _addNewEntry(true, animal, note, envData['weather'], envData['altitude']);
                setState(() { _isTracking = false; _trackingPath = []; _trackingMarkers = []; });
                Navigator.pop(context);
              },
              child: const Text("SPEICHERN", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _addEntryDialog(bool isKill) {
    String note = "";
    String animal = "Hirsch";
    final textColor = widget.isGhostMode ? Colors.red : Colors.black;
    final dialogBg = widget.isGhostMode ? Colors.grey[900] : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(isKill ? "Abschuss" : "Sichtung", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (_manualSelection)
                 Padding(
                   padding: const EdgeInsets.only(bottom: 10),
                   child: Row(children: [Icon(Icons.touch_app, color: Colors.orange, size: 16), SizedBox(width: 5), Text("Manuelle Position", style: TextStyle(color: Colors.orange, fontSize: 12))]),
                 ),
               DropdownButtonFormField<String>(
                dropdownColor: dialogBg,
                value: animal,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                items: ["Hirsch", "Reh", "Wildsau", "Gemse", "Fuchs", "Sonstiges"].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => animal = v!,
                decoration: InputDecoration(labelText: "Wildart", labelStyle: TextStyle(color: textColor)),
              ),
              TextField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(labelText: "Notiz", labelStyle: TextStyle(color: textColor)),
                onChanged: (v) => note = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isKill ? Colors.red[900] : Colors.green[800]),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hole Daten..."), duration: Duration(milliseconds: 500)));
                final envData = await _getEnviromentData(_targetPosition.latitude, _targetPosition.longitude);
                _addNewEntry(isKill, animal, note, envData['weather'], envData['altitude']);
                Navigator.pop(context);
                _resetToGPS(); 
              },
              child: const Text("SPEICHERN", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _addNewEntry(bool isKill, String animal, String note, String weather, double alt) {
    setState(() {
      _entries.insert(0, MapEntry(
        isKill: isKill,
        animal: animal,
        note: note,
        position: _targetPosition,
        timestamp: DateTime.now(),
        weather: weather,
        altitude: alt,
      ));
    });
    _saveEntries();
  }
  
  void _deleteEntry(int index) {
    setState(() { _entries.removeAt(index); });
    _saveEntries();
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.isGhostMode;
    final bgColor = isGhost ? Colors.black : const Color(0xFFE8F5E9);
    final tileUrl = isGhost 
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png' 
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isTracking ? "NACHSUCHE AKTIV" : "Revierkarte", 
            style: TextStyle(color: _isTracking ? Colors.white : (isGhost ? Colors.red : Colors.white), fontWeight: FontWeight.bold)),
        backgroundColor: _isTracking ? Colors.red[900] : (isGhost ? Colors.black : Colors.green[900]),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [ IconButton(icon: Icon(Icons.settings), onPressed: _showSettingsDialog) ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isTracking ? Colors.red : (isGhost ? Colors.red : Colors.green[900]!), width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition, 
                      initialZoom: 16.0,
                      onTap: (tapPosition, point) {
                        setState(() { _manualSelection = true; _targetPosition = point; });
                      },
                    ),
                    children: [
                      TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.weidmannsheil.app', subdomains: const ['a', 'b', 'c']),
                      if (_trackingPath.isNotEmpty)
                        PolylineLayer(polylines: [Polyline(points: _trackingPath, strokeWidth: 4.0, color: Colors.redAccent)]),
                      MarkerLayer(markers: _trackingMarkers),
                      MarkerLayer(markers: [
                          Marker(point: _currentPosition, width: 50, height: 50, child: Icon(Icons.my_location, color: Colors.blueAccent.withOpacity(0.7), size: 30)),
                          if (!_isTracking) Marker(point: _targetPosition, width: 60, height: 60, child: Icon(Icons.gps_fixed, color: _manualSelection ? Colors.orange : (isGhost ? Colors.red : Colors.green[800]), size: 45)),
                          ..._entries.map((e) => Marker(point: e.position, width: 40, height: 40, child: Icon(e.isKill ? Icons.close : Icons.visibility, color: e.isKill ? Colors.red : Colors.green, size: 30))),
                        ]),
                    ],
                  ),
                  if (_manualSelection) Positioned(top: 10, right: 10, child: FloatingActionButton.small(backgroundColor: Colors.white, onPressed: _resetToGPS, child: Icon(Icons.my_location, color: Colors.blue))),
                ],
              ),
            ),
          ),

          if (!_isTracking)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _entries.isEmpty
                  ? Center(child: Text("Logbuch leer", style: TextStyle(color: isGhost ? Colors.grey : Colors.grey[700])))
                  : ListView.builder(
                      itemCount: _entries.length,
                      padding: const EdgeInsets.only(top: 0, bottom: 300), 
                      itemBuilder: (context, index) {
                        return Dismissible(
                          key: UniqueKey(),
                          onDismissed: (_) => _deleteEntry(index),
                          background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                          child: _buildLogCard(_entries[index], isGhost),
                        );
                      },
                    ),
            ),
          ),
          
          if (_isTracking)
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: isGhost ? Colors.grey[900] : Colors.red[50],
                child: Column(
                  children: [
                    Text("Nachsuche läuft...", style: TextStyle(color: isGhost ? Colors.red : Colors.red[900], fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _trackingBtn("Schweiß", Icons.water_drop, Colors.red, () => _addTrackingPoint("Schweiß", Icons.water_drop, Colors.red, _currentPosition)),
                        _trackingBtn("Wundbett", Icons.bed, Colors.orange, () => _addTrackingPoint("Wundbett", Icons.bed, Colors.orange, _currentPosition)),
                        _trackingBtn("Knochen", Icons.accessibility_new, Colors.grey, () => _addTrackingPoint("Knochen", Icons.accessibility_new, Colors.grey, _currentPosition)),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], padding: const EdgeInsets.all(15)), onPressed: _finishTracking, icon: const Icon(Icons.check_circle, size: 30), label: const Text("GEFUNDEN & BEENDEN", style: TextStyle(fontSize: 18, color: Colors.white)))),
                  ],
                ),
              ),
            ),
        ],
      ),
      
      floatingActionButton: _isTracking 
          ? FloatingActionButton(backgroundColor: Colors.grey, onPressed: _toggleTracking, child: const Icon(Icons.close))
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(heroTag: "track", backgroundColor: Colors.orange[800], onPressed: _toggleTracking, icon: const Icon(Icons.pets, color: Colors.white), label: const Text("Nachsuche", style: TextStyle(color: Colors.white))),
                const SizedBox(height: 15),
                FloatingActionButton.extended(heroTag: "btn1", backgroundColor: isGhost ? Colors.grey[800] : Colors.green[700], onPressed: () => _addEntryDialog(false), icon: const Icon(Icons.visibility, color: Colors.white), label: const Text("Sichtung", style: TextStyle(color: Colors.white))),
                const SizedBox(height: 15),
                FloatingActionButton.extended(heroTag: "btn2", backgroundColor: Colors.red[900], onPressed: () => _addEntryDialog(true), icon: const Icon(Icons.gps_fixed, color: Colors.white), label: const Text("Abschuss", style: TextStyle(color: Colors.white))),
              ],
            ),
    );
  }
  
  Widget _trackingBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder(), padding: const EdgeInsets.all(20), elevation: 5), onPressed: onTap, child: Icon(icon, color: color, size: 30)), const SizedBox(height: 5), Text(label, style: const TextStyle(fontWeight: FontWeight.bold))]);
  }

  // --- KOMPAKTES DESIGN ---
  Widget _buildLogCard(MapEntry e, bool isGhost) {
    final dateStr = DateFormat('dd.MM. HH:mm').format(e.timestamp);
    final cardColor = isGhost ? Colors.grey[900] : Colors.white;
    final accentColor = e.isKill ? Colors.red : Colors.green[700];
    final textColor = isGhost ? Colors.white : Colors.black87;
    final subTextColor = isGhost ? Colors.grey : Colors.grey[700];

    final weatherDisplay = e.weather.isEmpty ? "--" : e.weather;
    final temp = weatherDisplay.contains(',') ? weatherDisplay.split(',')[0] : weatherDisplay;
    final wind = weatherDisplay.contains(',') ? weatherDisplay.split(',')[1].trim() : "-";
    final altDisplay = e.altitude == 0.0 ? "--" : "${e.altitude.toInt()}m";

    return Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardColor,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: accentColor!, width: 4))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
                Icon(e.isKill ? Icons.gps_fixed : Icons.visibility, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(e.animal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(width: 10),
                Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                        Container(height: 12, width: 1, color: Colors.grey.withOpacity(0.3)), const SizedBox(width: 8),
                        _buildCompactStat(Icons.terrain, altDisplay, subTextColor!), const SizedBox(width: 8),
                        _buildCompactStat(Icons.thermostat, temp, subTextColor), const SizedBox(width: 8),
                        _buildCompactStat(Icons.air, wind, subTextColor),
                      ]))),
                const SizedBox(width: 5),
                Text(dateStr, style: TextStyle(color: subTextColor, fontSize: 11)),
              ]),
            if (e.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(padding: const EdgeInsets.only(left: 28), child: Text(e.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic))),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 12, color: color.withOpacity(0.6)), const SizedBox(width: 2), Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]);
  }
}

class MapEntry {
  final bool isKill; final String animal; final String note; final LatLng position; final DateTime timestamp; final String weather; final double altitude;
  MapEntry({required this.isKill, required this.animal, required this.note, required this.position, required this.timestamp, this.weather = "", this.altitude = 0.0});
  Map<String, dynamic> toMap() => {'isKill': isKill, 'animal': animal, 'note': note, 'lat': position.latitude, 'lng': position.longitude, 'time': timestamp.toIso8601String(), 'weather': weather, 'alt': altitude};
  factory MapEntry.fromMap(Map<String, dynamic> map) => MapEntry(isKill: map['isKill'] ?? false, animal: (map['animal'] as String?) ?? "Unbekannt", note: (map['note'] as String?) ?? "", position: LatLng((map['lat'] as num?)?.toDouble() ?? 0.0, (map['lng'] as num?)?.toDouble() ?? 0.0), timestamp: DateTime.tryParse((map['time'] as String?) ?? "") ?? DateTime.now(), weather: (map['weather'] as String?) ?? "", altitude: (map['alt'] as num?)?.toDouble() ?? 0.0);
}