import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/meshtastic_service.dart';
import '../services/log_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final Color bluFiordaliso = const Color(0xFF4A90E2);

  final _meshtasticService = MeshtasticService();
  final _logService = LogService();

  bool isConnected = false;
  String statusMessage = 'Non connesso';
  List<Map<String, dynamic>> nodes = [];
  bool isScanning = false;
  Timer? _logTimer;

  late TabController _tabController;
  int _selectedTab = 0;

  bool simulationMode = false;
  int _demoLogCounter = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });

    _requestPermissions();
    _initStreams();

    if (_meshtasticService.isConnected) {
      setState(() {
        isConnected = true;
        nodes = _meshtasticService.nodesData.values.map((e) => e.toMap()).toList();
        statusMessage = "Connesso (riconnessione)";
      });
    }

    _meshtasticService.connectIfAlreadyConnected().then((success) {
      if (success && mounted) {
        setState(() {
          isConnected = true;
          nodes = _meshtasticService.nodesData.values.map((e) => e.toMap()).toList();
        });
      }
    });

    if (simulationMode) {
      _startSimulation();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose(); 
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      _showMessage('⚠️ Permessi Bluetooth necessari');
    }
  }

  void _initStreams() {
    _meshtasticService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => isConnected = connected);
      }
    });

    _meshtasticService.statusStream.listen((status) {
      if (mounted) {
        setState(() => statusMessage = status);
      }
    });

    _meshtasticService.nodesStream.listen((receivedNodes) {
      if (mounted) {
        setState(() => nodes = receivedNodes);
      }
    });
  }

  void _startSimulation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isConnected = true;
          statusMessage = 'Connesso (SIMULAZIONE)';
          nodes = _generateSimulatedNodes();
        });
        _updateSimulatedData();
      }
    });
  }

  void _updateSimulatedData() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && isConnected && simulationMode) {
        setState(() {
          nodes = _generateSimulatedNodes();
        });
        _demoLogCounter += 3;

        if (_demoLogCounter >= 30) {
          _logService.addLog(nodes);
          _demoLogCounter = 0;
        }

        _updateSimulatedData();
      }
    });
  }

  List<Map<String, dynamic>> _generateSimulatedNodes() {
    final random = Random();
    return List.generate(8, (i) {
      double baseTemp = 22.0;
      double baseHum = 55.0;
      double basePress = 1013.0;

      return {
        'id': i + 1,
        'nome': 'Nodo ${i + 1}',
        'lat': 37.068 + (cos(i * pi / 4) * 0.004) + (random.nextDouble() * 0.0005),
        'lng': 14.269 + (sin(i * pi / 4) * 0.004) + (random.nextDouble() * 0.0005),
        'temperatura': baseTemp + (i * 1.5) + (random.nextDouble() * 2 - 1),
        'umidita': baseHum + (i * 3) + (random.nextDouble() * 5 - 2.5),
        'pressione': basePress + (i * 1.2) + (random.nextDouble() * 3 - 1.5),
        'batteria': 100 - (i * 8) + random.nextInt(10),
        'timestamp': DateTime.now().toIso8601String(),
      };
    });
  }

  Future<void> _scanAndConnect() async {
    if (isConnected) {
      _showMessage("🔵 Sei già connessa al nodo.");
      return;
    }
    if (simulationMode) {
      _showMessage('⚠️ Modalità simulazione attiva');
      return;
    }
    if (isScanning) return;

    await _startNewScan();
  }

  Future<void> _startNewScan() async {
    bool bluetoothScan = await Permission.bluetoothScan.isGranted;
    bool bluetoothConnect = await Permission.bluetoothConnect.isGranted;
    bool location = await Permission.location.isGranted;

    if (!bluetoothScan || !bluetoothConnect || !location) {
      _showMessage('Concedi i permessi Bluetooth e Posizione');
      await _requestPermissions();
      return;
    }

    setState(() {
      isScanning = true;
      statusMessage = 'Scansione in corso...';
    });

    try {
      List<BluetoothDevice> devices = await _meshtasticService.scanDevices(
        timeout: const Duration(seconds: 10),
      );

      setState(() => isScanning = false);

      if (devices.isEmpty) {
        _showMessage('Nessun dispositivo trovato');
        return;
      }
      
      if (!mounted) return;

      BluetoothDevice? selected = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bluetooth_searching, color: bluFiordaliso),
              const SizedBox(width: 10),
              const Text('Seleziona Nodo'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                String name = devices[index].platformName.isEmpty
                    ? 'Dispositivo ${index + 1}'
                    : devices[index].platformName;
                return Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bluFiordaliso.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sensors, color: bluFiordaliso),
                    ),
                    title: Text(name),
                    subtitle: Text(devices[index].remoteId.toString()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(context, devices[index]),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        _showMessage('Connessione in corso...');
        bool connected = await _meshtasticService.connectToNode(selected);
        if (mounted) {
          _showMessage(connected
              ? '✅ Connesso a ${selected.platformName}'
              : '❌ Connessione fallita');
        }
      }
    } catch (e) {
      setState(() => isScanning = false);
      _showMessage('Errore: $e');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getHeatColor(double temperature, double minTemp, double maxTemp) {
    double normalized = (temperature - minTemp) / (maxTemp - minTemp);
    normalized = normalized.clamp(0.0, 1.0);

    if (normalized < 0.25) {
      return Color.lerp(Colors.blue, Colors.cyan, normalized * 4)!;
    } else if (normalized < 0.5) {
      return Color.lerp(Colors.cyan, Colors.green, (normalized - 0.25) * 4)!;
    } else if (normalized < 0.75) {
      return Color.lerp(Colors.green, Colors.yellow, (normalized - 0.5) * 4)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (normalized - 0.75) * 4)!;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        title: const Text('Network', style: TextStyle(fontSize: 18)),
        backgroundColor: bluFiordaliso,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: simulationMode
                      ? Colors.orange
                      : (isConnected ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      simulationMode
                          ? Icons.science
                          : (isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled),
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      simulationMode ? 'DEMO' : (isConnected ? 'Online' : 'Offline'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: isConnected && nodes.isNotEmpty
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.map, size: 18), text: 'Map'),
                  Tab(icon: Icon(Icons.whatshot, size: 18), text: 'Heat Map'),
                ],
                labelStyle: const TextStyle(fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
              )
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: !isConnected
                ? _buildConnectView()
                : nodes.isEmpty
                    ? _buildLoadingView()
                    : _buildMapContent(),
          ),
        ],
      ),

      floatingActionButtonLocation: const _RightCenterFabLocation(),

      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: simulationMode ? Colors.orange : bluFiordaliso,
        child: Icon(
          simulationMode ? Icons.bluetooth : Icons.developer_mode,
          color: Colors.white,
        ),
        onPressed: () async {
          if (simulationMode) {
            setState(() {
              simulationMode = false;
              isConnected = false;
              nodes = [];
            });

            await _meshtasticService.disconnect();
            _showMessage('🔵 Modalità Bluetooth attivata');
          } else {
            setState(() {
              simulationMode = true;
              isConnected = false;
              nodes = [];
            });

            _startSimulation();
            _showMessage('🧪 Modalità Demo attivata');
          }
        },
      ),
    );
  }

  Widget _buildConnectView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning
                ? Icons.bluetooth_searching
                : (isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            size: 80,
            color: bluFiordaliso,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning
                ? ''
                : (isConnected ? 'Connesso' : 'Assicurati che il Bluetooth sia acceso'),
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              backgroundColor: bluFiordaliso,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(isScanning ? 'Scansione in corso...' : 'Cerca Nodi'),
            onPressed: (isScanning || isConnected)
                ? null
                : () => _scanAndConnect(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildMapContent() {
    return Column(
      children: [
        Expanded(
          child: _selectedTab == 0 ? _buildMapView() : _buildHeatMapView(),
        ),
        if (_selectedTab == 1) _buildLegend(),
      ],
    );
  }

  Widget _buildMapView() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(nodes[0]['lat'], nodes[0]['lng']),
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progetto_tesi',
        ),
        MarkerLayer(
          markers: nodes.map((nodo) {
            return Marker(
              point: LatLng(nodo['lat'], nodo['lng']),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showNodeDetails(nodo),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: bluFiordaliso, width: 1.5),
                  ),
                  child: Icon(Icons.sensors, size: 20, color: bluFiordaliso),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeatMapView() {
    double minLat = nodes.map((n) => n['lat'] as double).reduce(min);
    double maxLat = nodes.map((n) => n['lat'] as double).reduce(max);
    double minLng = nodes.map((n) => n['lng'] as double).reduce(min);
    double maxLng = nodes.map((n) => n['lng'] as double).reduce(max);

    LatLngBounds dynamicBounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    double minTemp = nodes.map((n) => n['temperatura'] as double).reduce(min);
    double maxTemp = nodes.map((n) => n['temperatura'] as double).reduce(max);

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(nodes[0]['lat'], nodes[0]['lng']),
        initialZoom: 14.5,
        onTap: (tapPosition, point) {
          double minDistance = double.infinity;
          Map<String, dynamic>? closestNode;

          for (var node in nodes) {
            double distance = sqrt(
              pow(point.latitude - node['lat'], 2) + pow(point.longitude - node['lng'], 2),
            );
            if (distance < minDistance) {
              minDistance = distance;
              closestNode = node;
            }
          }

          if (closestNode != null && minDistance < 0.002) {
            _showNodeDetails(closestNode);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progetto_tesi',
        ),
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: dynamicBounds,
              opacity: 0.7,
              imageProvider: _HeatMapImageProvider(
                nodes: nodes,
                minTemp: minTemp,
                maxTemp: maxTemp,
                getColorCallback: _getHeatColor,
                bounds: dynamicBounds,
              ),
            )
          ],
        ),
        MarkerLayer(
          markers: nodes.map((nodo) {
            return Marker(
              point: LatLng(nodo['lat'], nodo['lng']),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showNodeDetails(nodo),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: bluFiordaliso, width: 1.5),
                  ),
                  child: Icon(Icons.sensors, size: 20, color: bluFiordaliso),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    double minTemp = nodes.map((n) => n['temperatura'] as double).reduce(min);
    double maxTemp = nodes.map((n) => n['temperatura'] as double).reduce(max);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, color: bluFiordaliso, size: 20),
              const SizedBox(width: 6),
              Text(
                'Temperatura',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: bluFiordaliso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.cyan, Colors.green, Colors.yellow, Colors.red],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min: ${minTemp.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 10)),
              Text('Max: ${maxTemp.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${nodes.length} sensori attivi',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showNodeDetails(Map<String, dynamic> nodo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: bluFiordaliso, width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bluFiordaliso.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sensors, color: bluFiordaliso, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nodo['nome'] ?? 'Nodo ${nodo['id']}',
                style: TextStyle(
                  color: bluFiordaliso,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDataRow('🌡️ Temperatura', '${nodo['temperatura'].toStringAsFixed(1)}°C'),
            _buildDataRow('💧 Umidità', '${nodo['umidita'].toStringAsFixed(1)}%'),
            _buildDataRow('📊 Pressione', '${nodo['pressione'].toStringAsFixed(1)} hPa'),
            if (nodo['batteria'] != null)
              _buildDataRow('🔋 Batteria', '${nodo['batteria']}%'),
            const Divider(height: 20),
            _buildDataRow('📍 Latitudine', nodo['lat'].toStringAsFixed(5)),
            _buildDataRow('📍 Longitudine', nodo['lng'].toStringAsFixed(5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: bluFiordaliso,
            ),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Provider per generare l’immagine della Heat Map
class _HeatMapImageProvider extends ImageProvider<_HeatMapImageProvider> {
  final List<Map<String, dynamic>> nodes;
  final double minTemp;
  final double maxTemp;
  final Color Function(double, double, double) getColorCallback;
  final LatLngBounds bounds;

  const _HeatMapImageProvider({
    required this.nodes,
    required this.minTemp,
    required this.maxTemp,
    required this.getColorCallback,
    required this.bounds,
  });

  @override
  Future<_HeatMapImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_HeatMapImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_HeatMapImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key));
  }

  Future<ImageInfo> _loadAsync(_HeatMapImageProvider key) async {
    const int width = 200;
    const int height = 200;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..style = PaintingStyle.fill;

    double minLat = bounds.southWest.latitude;
    double maxLat = bounds.northEast.latitude;
    double minLng = bounds.southWest.longitude;
    double maxLng = bounds.northEast.longitude;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double lat = minLat + (maxLat - minLat) * (1 - y / height);
        double lng = minLng + (maxLng - minLng) * (x / width);

        double interpolatedTemp = _interpolateTemperature(lat, lng);
        Color color = getColorCallback(interpolatedTemp, minTemp, maxTemp);

        paint.color = color.withValues(alpha: 0.8);
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    return ImageInfo(image: image);
  }

  double _interpolateTemperature(double lat, double lng) {
    double weightedSum = 0;
    double weightSum = 0;
    const double power = 2.5;

    for (var node in nodes) {
      double nodeLat = node['lat'];
      double nodeLng = node['lng'];
      double nodeTemp = node['temperatura'];

      double dx = (lng - nodeLng) * 111000 * cos(lat * pi / 180);
      double dy = (lat - nodeLat) * 111000;
      double distance = sqrt(dx * dx + dy * dy);

      if (distance < 1) {
        return nodeTemp;
      }

      double weight = 1 / pow(distance, power);
      weightedSum += nodeTemp * weight;
      weightSum += weight;
    }

    return weightSum > 0 ? (weightedSum / weightSum) : minTemp;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HeatMapImageProvider &&
        other.nodes == nodes &&
        other.minTemp == minTemp &&
        other.maxTemp == maxTemp;
  }

  @override
  int get hashCode => Object.hash(nodes, minTemp, maxTemp);
}

// Posizionamento personalizzato del FAB
class _RightCenterFabLocation extends FloatingActionButtonLocation {
  const _RightCenterFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) {
    final double appBarHeight = g.minInsets.top + kToolbarHeight;
    final double tabBarHeight = 48;
    final double correction = appBarHeight + tabBarHeight;
    final double usableHeight = g.scaffoldSize.height - correction;

    final double fabX =
        g.scaffoldSize.width - g.floatingActionButtonSize.width - 16;

    const double shiftDown = 100;

    final double fabY = correction +
        usableHeight / 2 -
        g.floatingActionButtonSize.height / 2 +
        shiftDown;

    return Offset(fabX, fabY);
  }
}
