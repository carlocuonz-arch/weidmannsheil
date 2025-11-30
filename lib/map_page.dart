import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:torch_light/torch_light.dart';
import 'dart:math' as math;

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

  // Für das Foto im Dialog
  XFile? _tempImage;
  final ImagePicker _picker = ImagePicker();

  // GPS Stream für Live-Tracking
  StreamSubscription<Position>? _positionStreamSubscription;

  // Kompass
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;

  // Taschenlampe
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _locateUser();
    _loadEntries();
    _startCompass();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    if (_isTorchOn) {
      _toggleTorch(); // Taschenlampe ausschalten beim Verlassen
    }
    super.dispose();
  }

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      setState(() {
        _compassHeading = event.heading ?? 0.0;
      });
    });
  }

  void _startPositionStream() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update alle 5 Meter
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        if (!_manualSelection) {
          _targetPosition = _currentPosition;
        }
      });

      // Wenn Tracking aktiv ist, Karte mitbewegen
      if (_isTracking) {
        _mapController.move(_currentPosition, _mapController.camera.zoom);
      }
    });
  }

  void _stopPositionStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<void> _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      // Taschenlampe nicht verfügbar (z.B. auf Desktop)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Taschenlampe nicht verfügbar")),
        );
      }
    }
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

  // --- BACKUP ---
  Future<void> _exportData() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nichts zu sichern!")));
      return;
    }
    try {
      final String dataString = jsonEncode(_entries.map((e) => e.toMap()).toList());
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Weidmannsheil_Backup.txt');
      await file.writeAsString(dataString, flush: true);
      await Future.delayed(const Duration(milliseconds: 500));
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'json']);
      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        _processImportString(content);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Fehler: $e")));
    }
  }

  void _processImportString(String jsonString) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      List<MapEntry> newEntries = decoded.map((item) {
          try { return MapEntry.fromMap(item); } catch (e) { return null; }
        }).whereType<MapEntry>().toList();

      if (newEntries.isNotEmpty) {
        setState(() {
          _entries.addAll(newEntries);
          _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
        _saveEntries();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${newEntries.length} Einträge importiert!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keine gültigen Daten.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ungültiges Format.")));
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
          title: Text("Einstellungen", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: Icon(Icons.share, color: textColor), title: Text("Backup senden", style: TextStyle(color: textColor)), onTap: () { Navigator.pop(context); _exportData(); }),
              ListTile(leading: Icon(Icons.download, color: textColor), title: Text("Backup laden", style: TextStyle(color: textColor)), onTap: () { Navigator.pop(context); _importData(); }),
              ListTile(leading: Icon(Icons.delete_forever, color: Colors.red), title: Text("Alles löschen", style: TextStyle(color: Colors.red)), onTap: () { setState(() { _entries.clear(); }); _saveEntries(); Navigator.pop(context); }),
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
        if (!_manualSelection) _targetPosition = _currentPosition;
      });
      if (!_manualSelection && !_isTracking) _mapController.move(_currentPosition, 16.0);
    } catch (e) { print("Kein GPS: $e"); }
  }

  void _resetToGPS() {
    setState(() { _manualSelection = false; _targetPosition = _currentPosition; });
    _mapController.move(_currentPosition, 16.0);
  }

  Future<Map<String, dynamic>> _getEnviromentData(double lat, double lon) async {
    String weatherInfo = "Kein Netz";
    double altitude = 0.0;
    try { Position pos = await Geolocator.getCurrentPosition(); altitude = pos.altitude; } catch (e) {}
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
    } catch (e) {}
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
        _startPositionStream(); // GPS Live-Tracking starten
      } else {
        _trackingPath = [];
        _trackingMarkers = [];
        _stopPositionStream(); // GPS Stream stoppen
      }
    });
  }

  void _addTrackingPoint(String type, IconData icon, Color color, LatLng pos) {
    setState(() { _trackingPath.add(pos); _trackingMarkers.add(Marker(point: pos, width: 40, height: 40, child: Icon(icon, color: color, size: 28))); });
  }

  Future<void> _finishTracking() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysiere Daten..."), duration: Duration(milliseconds: 500)));
    final envData = await _getEnviromentData(_currentPosition.latitude, _currentPosition.longitude);
    _finishTrackingDialog(envData);
  }

  void _finishTrackingDialog(Map<String, dynamic> envData) {
    // Gleicher Dialog wie unten, nur angepasst für Tracking Abschluss
    _addEntryDialog(true, isTrackingFinish: true, envData: envData);
  }

  // --- KAMERA LOGIK ---
  Future<void> _pickImage(StateSetter setStateDialog) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera); // Oder gallery
      if (photo != null) {
        setStateDialog(() {
          _tempImage = photo;
        });
      }
    } catch (e) {
      print("Kamera Fehler: $e");
    }
  }

  // --- HAUPT DIALOG (JETZT MIT FOTO) ---
  void _addEntryDialog(bool isKill, {bool isTrackingFinish = false, Map<String, dynamic>? envData}) {
    String note = isTrackingFinish ? "Nachsuche: ${_trackingPath.length} Punkte" : "";
    String animal = "Hirsch";
    final textColor = widget.isGhostMode ? Colors.red : Colors.black;
    final dialogBg = widget.isGhostMode ? Colors.grey[900] : Colors.white;
    
    // Reset temp image
    _tempImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Wichtig, damit sich das Bild im Dialog aktualisiert!
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isTrackingFinish ? "Nachsuche beenden" : (isKill ? "Abschuss" : "Sichtung"), style: TextStyle(color: textColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     if (isTrackingFinish) Text("Erfolgreich gefunden!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                     
                     // TIERAUSWAHL
                     DropdownButtonFormField<String>(
                      dropdownColor: dialogBg,
                      value: animal,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      items: ["Hirsch", "Reh", "Wildsau", "Gemse", "Fuchs", "Sonstiges"].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => animal = v!,
                      decoration: InputDecoration(labelText: "Wildart", labelStyle: TextStyle(color: textColor)),
                    ),
                    
                    // NOTIZ
                    TextField(
                      controller: TextEditingController(text: note),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(labelText: "Notiz", labelStyle: TextStyle(color: textColor)),
                      onChanged: (v) => note = v,
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // --- KAMERA BUTTON & VORSCHAU ---
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(setStateDialog),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Foto"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        if (_tempImage != null)
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green),
                              image: DecorationImage(image: FileImage(File(_tempImage!.path)), fit: BoxFit.cover),
                            ),
                          )
                        else
                          Text("Kein Bild", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isKill ? Colors.red[900] : Colors.green[800]),
                  onPressed: () async {
                    String weather = "";
                    double alt = 0.0;
                    
                    // Wenn wir Daten schon haben (Tracking), nutzen wir sie, sonst holen
                    if (envData != null) {
                      weather = envData['weather'];
                      alt = envData['altitude'];
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Speichere..."), duration: Duration(milliseconds: 500)));
                      final data = await _getEnviromentData(_targetPosition.latitude, _targetPosition.longitude);
                      weather = data['weather'];
                      alt = data['altitude'];
                    }

                    _addNewEntry(isKill, animal, note, weather, alt, _tempImage?.path);

                    if (isTrackingFinish) {
                      setState(() { _isTracking = false; _trackingPath = []; _trackingMarkers = []; });
                      _stopPositionStream(); // GPS Stream stoppen
                    }
                    Navigator.pop(context);
                    _resetToGPS(); 
                  },
                  child: const Text("SPEICHERN", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _addNewEntry(bool isKill, String animal, String note, String weather, double alt, String? imagePath) {
    setState(() {
      _entries.insert(0, MapEntry(
        isKill: isKill,
        animal: animal,
        note: note,
        position: _targetPosition,
        timestamp: DateTime.now(),
        weather: weather,
        altitude: alt,
        imagePath: imagePath, // NEU: Pfad zum Bild
      ));
    });
    _saveEntries();
  }
  
  void _deleteEntry(int index) { setState(() { _entries.removeAt(index); }); _saveEntries(); }

  // --- VOLLBILD ANZEIGE ---
  void _showFullImage(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer( // Erlaubt Zoom mit zwei Fingern
            child: Image.file(File(path)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.isGhostMode;
    final bgColor = isGhost ? Colors.black : const Color(0xFFE8F5E9);
    final tileUrl = isGhost ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isTracking ? "NACHSUCHE AKTIV" : "Revierkarte",
            style: TextStyle(color: _isTracking ? Colors.white : (isGhost ? Colors.red : Colors.white), fontWeight: FontWeight.bold)),
        backgroundColor: _isTracking ? Colors.red[900] : (isGhost ? Colors.black : Colors.green[900]),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flashlight_on : Icons.flashlight_off),
            onPressed: _toggleTorch,
            tooltip: "Taschenlampe",
          ),
          IconButton(icon: Icon(Icons.settings), onPressed: _showSettingsDialog),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _isTracking ? Colors.red : (isGhost ? Colors.red : Colors.green[900]!), width: 2)),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _currentPosition, initialZoom: 16.0, onTap: (tapPosition, point) { setState(() { _manualSelection = true; _targetPosition = point; }); }),
                    children: [
                      TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.weidmannsheil.app', subdomains: const ['a', 'b', 'c']),
                      if (_trackingPath.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _trackingPath, strokeWidth: 4.0, color: Colors.redAccent)]),
                      MarkerLayer(markers: _trackingMarkers),
                      MarkerLayer(markers: [
                          Marker(point: _currentPosition, width: 50, height: 50, child: Icon(Icons.my_location, color: Colors.blueAccent.withOpacity(0.7), size: 30)),
                          if (!_isTracking) Marker(point: _targetPosition, width: 60, height: 60, child: Icon(Icons.gps_fixed, color: _manualSelection ? Colors.orange : (isGhost ? Colors.red : Colors.green[800]), size: 45)),
                          ..._entries.map((e) => Marker(point: e.position, width: 40, height: 40, child: Icon(e.isKill ? Icons.close : Icons.visibility, color: e.isKill ? Colors.red : Colors.green, size: 30))),
                        ]),
                    ],
                  ),
                  if (_manualSelection) Positioned(top: 10, right: 10, child: FloatingActionButton.small(backgroundColor: Colors.white, onPressed: _resetToGPS, child: Icon(Icons.my_location, color: Colors.blue))),

                  // Kompass Overlay (oben links)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: (_compassHeading * (math.pi / 180) * -1),
                            child: Icon(Icons.navigation, color: Colors.red, size: 40),
                          ),
                          Positioned(
                            top: 5,
                            child: Text('N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                        return Dismissible(key: UniqueKey(), onDismissed: (_) => _deleteEntry(index), background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)), child: _buildLogCard(_entries[index], isGhost));
                      },
                    ),
            ),
          ),
          
          if (_isTracking)
            Expanded(
              flex: 4,
              child: Container(padding: const EdgeInsets.all(10), color: isGhost ? Colors.grey[900] : Colors.red[50], child: Column(children: [
                    Text("Nachsuche läuft...", style: TextStyle(color: isGhost ? Colors.red : Colors.red[900], fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_trackingBtn("Schweiß", Icons.water_drop, Colors.red, () => _addTrackingPoint("Schweiß", Icons.water_drop, Colors.red, _currentPosition)), _trackingBtn("Wundbett", Icons.bed, Colors.orange, () => _addTrackingPoint("Wundbett", Icons.bed, Colors.orange, _currentPosition)), _trackingBtn("Knochen", Icons.accessibility_new, Colors.grey, () => _addTrackingPoint("Knochen", Icons.accessibility_new, Colors.grey, _currentPosition))]),
                    const Spacer(),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], padding: const EdgeInsets.all(15)), onPressed: _finishTracking, icon: const Icon(Icons.check_circle, size: 30), label: const Text("GEFUNDEN & BEENDEN", style: TextStyle(fontSize: 18, color: Colors.white)))),
                  ])),
            ),
        ],
      ),
      
      floatingActionButton: _isTracking 
          ? FloatingActionButton(backgroundColor: Colors.grey, onPressed: _toggleTracking, child: const Icon(Icons.close))
          : Column(mainAxisAlignment: MainAxisAlignment.end, children: [FloatingActionButton.extended(heroTag: "track", backgroundColor: Colors.orange[800], onPressed: _toggleTracking, icon: const Icon(Icons.pets, color: Colors.white), label: const Text("Nachsuche", style: TextStyle(color: Colors.white))), const SizedBox(height: 15), FloatingActionButton.extended(heroTag: "btn1", backgroundColor: isGhost ? Colors.grey[800] : Colors.green[700], onPressed: () => _addEntryDialog(false), icon: const Icon(Icons.visibility, color: Colors.white), label: const Text("Sichtung", style: TextStyle(color: Colors.white))), const SizedBox(height: 15), FloatingActionButton.extended(heroTag: "btn2", backgroundColor: Colors.red[900], onPressed: () => _addEntryDialog(true), icon: const Icon(Icons.gps_fixed, color: Colors.white), label: const Text("Abschuss", style: TextStyle(color: Colors.white)))]),
    );
  }
  
  Widget _trackingBtn(String label, IconData icon, Color color, VoidCallback onTap) { return Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder(), padding: const EdgeInsets.all(20), elevation: 5), onPressed: onTap, child: Icon(icon, color: color, size: 30)), const SizedBox(height: 5), Text(label, style: const TextStyle(fontWeight: FontWeight.bold))]); }

  // --- KOMPAKTES DESIGN (MIT FOTO) ---
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
                Expanded( // Tiername bekommt Platz
                  child: Text(e.animal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis),
                ),
                
                // --- FOTO THUMBNAIL (NEU!) ---
                if (e.imagePath != null && File(e.imagePath!).existsSync())
                  GestureDetector(
                    onTap: () => _showFullImage(e.imagePath!),
                    child: Container(
                      width: 40, height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(image: FileImage(File(e.imagePath!)), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                // -----------------------------

                // Wetter Daten
                _buildCompactStat(Icons.terrain, altDisplay, subTextColor!), const SizedBox(width: 8),
                _buildCompactStat(Icons.thermostat, temp, subTextColor), const SizedBox(width: 8),
                _buildCompactStat(Icons.air, wind, subTextColor),
                const SizedBox(width: 8),
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

  Widget _buildCompactStat(IconData icon, String text, Color color) { return Row(children: [Icon(icon, size: 12, color: color.withOpacity(0.6)), const SizedBox(width: 2), Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]); }
}

// --- MAP ENTRY (MIT IMAGE PATH) ---
class MapEntry {
  final bool isKill; final String animal; final String note; final LatLng position; final DateTime timestamp; final String weather; final double altitude;
  final String? imagePath; // NEU

  MapEntry({required this.isKill, required this.animal, required this.note, required this.position, required this.timestamp, this.weather = "", this.altitude = 0.0, this.imagePath});
  
  Map<String, dynamic> toMap() => {'isKill': isKill, 'animal': animal, 'note': note, 'lat': position.latitude, 'lng': position.longitude, 'time': timestamp.toIso8601String(), 'weather': weather, 'alt': altitude, 'imagePath': imagePath};
  
  factory MapEntry.fromMap(Map<String, dynamic> map) => MapEntry(
    isKill: map['isKill'] ?? false, 
    animal: (map['animal'] as String?) ?? "Unbekannt", 
    note: (map['note'] as String?) ?? "", 
    position: LatLng((map['lat'] as num?)?.toDouble() ?? 0.0, (map['lng'] as num?)?.toDouble() ?? 0.0), 
    timestamp: DateTime.tryParse((map['time'] as String?) ?? "") ?? DateTime.now(), 
    weather: (map['weather'] as String?) ?? "", 
    altitude: (map['alt'] as num?)?.toDouble() ?? 0.0,
    imagePath: map['imagePath'], // Laden
  );
}