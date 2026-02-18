import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Protobuf Meshtastic generati
import '../generated/meshtastic/mesh.pb.dart';
import '../generated/meshtastic/telemetry.pb.dart';
import '../generated/meshtastic/portnums.pb.dart';
import '../models/node_data.dart';
import '../services/log_service.dart';

class MeshtasticService {
  static final MeshtasticService _instance = MeshtasticService._internal();
  factory MeshtasticService() => _instance;
  MeshtasticService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _fromRadioCharacteristic;
  BluetoothCharacteristic? _toRadioCharacteristic;
  Timer? _pollingTimer;
  Timer? _realLogTimer;

  final Map<int, NodeData> _nodesData = {};
  final Map<int, String> _nodeNames = {};
  final Map<int, Position> _nodePositions = {};

  Map<int, NodeData> get nodesData => _nodesData;

  final _nodesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<List<Map<String, dynamic>>> get nodesStream => _nodesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool get isConnected => _connectedDevice != null;

  final Guid serviceUUID = Guid("6ba1b218-15a8-461f-9fa8-5dcae273eafd");
  final Guid fromRadioUUID = Guid("8ba2bcc2-ee02-4a55-a531-c525c5e454d5");
  final Guid toRadioUUID = Guid("f75c76d2-129e-4dad-a1dd-7866124401e7");

  /// Verifica se il dispositivo risulta ancora connesso.
  Future<bool> checkStillConnected() async {
    if (_connectedDevice == null) return false;

    BluetoothConnectionState state =
        await _connectedDevice!.connectionState.first;

    return state == BluetoothConnectionState.connected;
  }

  /// Prova a connettersi a un dispositivo già connesso al sistema (senza scansione).
  Future<bool> connectIfAlreadyConnected() async {
    List<BluetoothDevice> systemDevices = await FlutterBluePlus.connectedDevices;

    if (systemDevices.isEmpty) return false;

    for (var dev in systemDevices) {
      // Eventuale filtro aggiuntivo sul dispositivo
      bool ok = await connectToNode(dev);
      if (ok) return true;
    }

    return false;
  }

  Future<bool> connectToDeviceByMac(String macAddress) async {
    try {
      _statusController.add('Connessione a $macAddress...');
      BluetoothDevice device = BluetoothDevice.fromId(macAddress);
      return await connectToNode(device);
    } catch (e) {
      _statusController.add('Errore connessione: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> getSystemConnectedDevices() async {
    try {
      return FlutterBluePlus.connectedDevices;
    } catch (e) {
      print('❌ Errore ricerca dispositivi: $e');
      return [];
    }
  }

  Future<List<BluetoothDevice>> scanDevices({Duration timeout = const Duration(seconds: 10)}) async {
    _statusController.add('Scansione dispositivi...');
    List<BluetoothDevice> allDevices = [];

    try {
      if (await FlutterBluePlus.isSupported == false) {
        _statusController.add('Bluetooth non supportato');
        return [];
      }

      // 1) Dispositivi già connessi a livello GATT
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      for (var dev in connectedDevices) {
        print("🔵 Connesso GATT: ${dev.platformName} (${dev.remoteId})");
        allDevices.add(dev);
      }

      // 2) Dispositivi accoppiati (bonded)
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;
      for (var dev in bondedDevices) {
        print("🟦 Paired/Bonded: ${dev.platformName} (${dev.remoteId})");
        allDevices.add(dev);
      }

      // 3) Scansione BLE
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (!allDevices.any((d) => d.remoteId == result.device.remoteId)) {
            print("🔍 Trovato via scan: ${result.device.platformName} (${result.device.remoteId})");
            allDevices.add(result.device);
          }
        }
      });

      await Future.delayed(timeout);
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return allDevices;

    } catch (e) {
      print("❌ Errore scansione: $e");
      return allDevices;
    }
  }

  /// Connessione principale al nodo Meshtastic.
  Future<bool> connectToNode(BluetoothDevice device) async {
    try {
      _statusController.add('Connessione in corso...');
      _connectionController.add(false);

      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 15));
      }

      _connectedDevice = device;

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionController.add(false);
          _connectedDevice = null;
          _stopRealLogTimer();
        }
      });

      List<BluetoothService> services = await device.discoverServices();
      bool serviceFound = false;

      for (BluetoothService service in services) {
        if (service.uuid == serviceUUID) {
          serviceFound = true;

          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.uuid == toRadioUUID) _toRadioCharacteristic = char;
          }

          List<BluetoothCharacteristic> notifyChars =
              service.characteristics.where((c) => c.properties.notify).toList();
          List<BluetoothCharacteristic> readChars =
              service.characteristics.where((c) => c.properties.read && !c.properties.notify).toList();

          if (readChars.isNotEmpty) {
            _fromRadioCharacteristic = readChars.first;
          } else if (notifyChars.isNotEmpty) {
            _fromRadioCharacteristic = notifyChars.first;
            try {
              await _fromRadioCharacteristic!.setNotifyValue(true);
              _fromRadioCharacteristic!.lastValueStream.listen((data) {
                if (data.isNotEmpty) _parseData(data);
              });
            } catch (e) {
              print('❌ Errore notifiche: $e');
            }
          }
          break;
        }
      }

      if (!serviceFound || _fromRadioCharacteristic == null || _toRadioCharacteristic == null) {
        await disconnect();
        return false;
      }

      _connectionController.add(true);

      _startRealLogTimer();

      await Future.delayed(const Duration(seconds: 3));

      await _sendSync();
      await Future.delayed(const Duration(seconds: 1));
      await requestAllNodes();
      await requestMyTelemetry();
      _startPolling();

      return true;
    } catch (e) {
      print('❌ Errore connessione: $e');
      await disconnect();
      return false;
    }
  }

  void _parseData(List<int> data) {
    if (data.isEmpty) return;
    try {
      final fromRadio = FromRadio.fromBuffer(data);
      if (fromRadio.hasPacket()) {
        _handleMeshPacket(fromRadio.packet);
      } else if (fromRadio.hasNodeInfo()) {
        _handleNodeInfo(fromRadio.nodeInfo);
      } else if (fromRadio.hasMyInfo()) {
        final myInfo = fromRadio.myInfo;
        print('ℹ️ MyInfo ricevuto: nodo ${myInfo.myNodeNum}');
        NodeInfo? nodeInfo;

        try {
          if ((myInfo as dynamic).nodeInfo != null) {
            nodeInfo = (myInfo as dynamic).nodeInfo as NodeInfo;
          } else if ((myInfo as dynamic).node != null) {
            nodeInfo = (myInfo as dynamic).node as NodeInfo;
          }
        } catch (e) {
          nodeInfo = null;
        }

        if (nodeInfo != null) {
          String? nodeName;
          if (nodeInfo.hasUser()) {
            nodeName = nodeInfo.user.longName.isNotEmpty
                ? nodeInfo.user.longName
                : nodeInfo.user.shortName;
          }

          _updateNodeData(
            nodeId: myInfo.myNodeNum,
            nome: nodeName ?? 'Nodo ${myInfo.myNodeNum}',
          );

          if (nodeInfo.hasPosition()) {
            _handlePosition(myInfo.myNodeNum, nodeInfo.position.writeToBuffer());
          }
        } else {
          return;
        }
      }
    } catch (e) {
      print('❌ Errore parsing dati: $e');
    }
  }

  void _handleMeshPacket(MeshPacket packet) {
    int nodeId = packet.from;
    int? rssi = packet.hasRxRssi() ? packet.rxRssi : null;
    int? snr = packet.hasRxSnr() ? packet.rxSnr.toInt() : null;

    if (packet.hasDecoded()) {
      Data decoded = packet.decoded;
      if (decoded.portnum == PortNum.TELEMETRY_APP) {
        _handleTelemetry(nodeId, decoded.payload, rssi, snr);
      } else if (decoded.portnum == PortNum.POSITION_APP) {
        _handlePosition(nodeId, decoded.payload);
      } else if (decoded.portnum == PortNum.NODEINFO_APP) {
        _handleNodeInfoPacket(nodeId, decoded.payload);
      } else if (decoded.portnum == PortNum.TEXT_MESSAGE_APP) {
        String message = String.fromCharCodes(decoded.payload);
        print('💬 Messaggio da nodo $nodeId: $message');
      }
    }
  }

  void _handleTelemetry(int nodeId, List<int> payload, int? rssi, int? snr) {
    try {
      Telemetry telemetry = Telemetry.fromBuffer(payload);
      double? t, h, p;
      int? battery;

      if (telemetry.hasEnvironmentMetrics()) {
        var env = telemetry.environmentMetrics;
        t = env.hasTemperature() ? env.temperature.toDouble() : null;
        h = env.hasRelativeHumidity() ? env.relativeHumidity.toDouble() : null;
        p = env.hasBarometricPressure() ? env.barometricPressure.toDouble() : null;
      }

      if (telemetry.hasDeviceMetrics()) {
        battery = telemetry.deviceMetrics.hasBatteryLevel()
            ? telemetry.deviceMetrics.batteryLevel
            : null;
      }

      _updateNodeData(
        nodeId: nodeId,
        temperatura: t,
        umidita: h,
        pressione: p,
        batteria: battery,
        rssi: rssi,
        snr: snr,
      );
    } catch (e) {
      print('❌ Errore telemetria: $e');
    }
  }

  void _handlePosition(int nodeId, List<int> payload) {
    try {
      Position pos = Position.fromBuffer(payload);

      if (!pos.hasLatitudeI() || !pos.hasLongitudeI()) return;

      double lat = pos.latitudeI / 1e7;
      double lng = pos.longitudeI / 1e7;

      // Ignora solo la posizione (0,0)
      if (lat == 0.0 && lng == 0.0) return;

      NodeData? prev = _nodesData[nodeId];

      // Accetta sempre la prima posizione
      if (prev == null || (prev.latitude == 0 && prev.longitude == 0)) {
        print("📍 Prima posizione accettata ($lat, $lng)");
        _updateNodeData(nodeId: nodeId, latitude: lat, longitude: lng);
        return;
      }

      // Controllo distanza tra posizione precedente e nuova
      double dx = (lng - prev.longitude) * 111000 * cos(lat * pi / 180);
      double dy = (lat - prev.latitude) * 111000;
      double distance = sqrt(dx * dx + dy * dy);

      if (distance > 200) {
        print("⚠️ Ignorata posizione saltata ($distance m)");
        return;
      }

      // Controllo coerenza temporale
      if (pos.hasTime()) {
        int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if ((now - pos.time).abs() > 120) {
          print("⚠️ Ignorata posizione vecchia");
          return;
        }
      }

      print("📍 Posizione aggiornata ($lat, $lng)");
      _updateNodeData(nodeId: nodeId, latitude: lat, longitude: lng);

    } catch (e) {
      print("❌ Errore posizione: $e");
    }
  }

  void _handleNodeInfo(NodeInfo nodeInfo) {
    int nodeId = nodeInfo.num;
    if (nodeInfo.hasUser()) {
      String name = nodeInfo.user.longName.isNotEmpty
          ? nodeInfo.user.longName
          : nodeInfo.user.shortName;
      _updateNodeData(nodeId: nodeId, nome: name);
    }
    if (nodeInfo.hasPosition()) {
      _handlePosition(nodeId, nodeInfo.position.writeToBuffer());
    }
  }

  void _handleNodeInfoPacket(int nodeId, List<int> payload) {
    try {
      User user = User.fromBuffer(payload);
      String name = user.hasLongName() ? user.longName : user.shortName;
      _updateNodeData(nodeId: nodeId, nome: name);
    } catch (_) {}
  }

  void _updateNodeData({
    required int nodeId,
    String? nome,
    double? temperatura,
    double? umidita,
    double? pressione,
    double? latitude,
    double? longitude,
    int? batteria,
    int? rssi,
    int? snr,
  }) {
    NodeData? existing = _nodesData[nodeId];

    NodeData updated = NodeData(
      id: nodeId,
      nome: nome ?? existing?.nome ?? "Nodo $nodeId",
      temperature: temperatura ?? existing?.temperature ?? 0,
      humidity: umidita ?? existing?.humidity ?? 0,
      pressure: pressione ?? existing?.pressure ?? 0,
      latitude: latitude ?? existing?.latitude ?? 0,
      longitude: longitude ?? existing?.longitude ?? 0,
      batteria: batteria ?? existing?.batteria,
      timestamp: DateTime.now(),
      rssi: rssi ?? existing?.rssi,
      snr: snr ?? existing?.snr,
    );

    _nodesData[nodeId] = updated;

    _nodesController.add(
      _nodesData.values.map((e) => e.toMap()).toList(),
    );
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        if (_fromRadioCharacteristic != null && _connectedDevice != null) {
          List<int> data = await _fromRadioCharacteristic!.read();
          if (data.isNotEmpty) _parseData(data);
        }
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startRealLogTimer() {
    _realLogTimer?.cancel();

    _realLogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Salva log periodicamente solo se connesso e con nodi disponibili
      if (_connectedDevice != null && _nodesData.isNotEmpty) {
        LogService().addLog(
          _nodesData.values.map((e) => e.toMap()).toList(),
        );
      }
    });
  }

  void _stopRealLogTimer() {
    _realLogTimer?.cancel();
    _realLogTimer = null;
  }

  Future<void> _sendSync() async {
    try {
      if (_toRadioCharacteristic == null) return;
      ToRadio toRadio = ToRadio()..wantConfigId = 1;
      await _toRadioCharacteristic!.write(toRadio.writeToBuffer());
    } catch (e) {
      print('⚠️ Errore invio richiesta: $e');
    }
  }

  Future<void> requestMyTelemetry() async {
    try {
      if (_toRadioCharacteristic == null) return;
      ToRadio toRadio = ToRadio();
      MeshPacket packet = MeshPacket()
        ..to = 0xffffffff
        ..decoded = (Data()
          ..portnum = PortNum.TELEMETRY_APP
          ..payload = []);
      toRadio.packet = packet;
      await _toRadioCharacteristic!.write(toRadio.writeToBuffer());
    } catch (e) {
      print('⚠️ Errore richiesta telemetria: $e');
    }
  }

  Future<void> requestAllNodes() async {
    try {
      if (_toRadioCharacteristic == null) return;
      ToRadio toRadio = ToRadio()..wantConfigId = 3;
      await _toRadioCharacteristic!.write(toRadio.writeToBuffer());
    } catch (e) {
      print('⚠️ Errore richiesta nodi: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _stopPolling();
      await _connectedDevice?.disconnect();
    } catch (_) {}
    finally {
      _stopRealLogTimer();

      _connectedDevice = null;
      _fromRadioCharacteristic = null;
      _toRadioCharacteristic = null;
      _connectionController.add(false);
      _nodesData.clear();
      _nodesController.add([]);
    }
  }

  void dispose() {
    _stopPolling();
  }
}
