class NodeData {
  final int id;                    // ID del nodo
  final String? nome;              // Nome del nodo (opzionale)
  final double temperature;        // Temperatura in °C
  final double humidity;           // Umidità in %
  final double pressure;           // Pressione in hPa
  final double latitude;           // Latitudine
  final double longitude;          // Longitudine
  final int? batteria;             // Livello batteria in % 
  final DateTime timestamp;        // Timestamp della rilevazione
  final int? rssi;                 // RSSI (opzionale, Meshtastic)
  final int? snr;                  // SNR (opzionale, Meshtastic)

  NodeData({
    required this.id,
    this.nome,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.latitude,
    required this.longitude,
    this.batteria,
    required this.timestamp,
    this.rssi,
    this.snr,
  });

  // Conversione da Map (per JSON o database)
  factory NodeData.fromMap(Map<String, dynamic> map) {
    return NodeData(
      id: map['id'] ?? map['nodeId'] ?? 0,
      nome: map['nome'] ?? map['nodeName'],
      temperature: (map['temperatura'] ?? map['temperature'] ?? 0).toDouble(),
      humidity: (map['umidita'] ?? map['humidity'] ?? 0).toDouble(),
      pressure: (map['pressione'] ?? map['pressure'] ?? 0).toDouble(),
      latitude: (map['lat'] ?? map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['lng'] ?? map['longitude'] ?? 0.0).toDouble(),
      batteria: map['batteria'] ?? map['battery'],
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp']
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      rssi: map['rssi'],
      snr: map['snr'],
    );
  }

  // Conversione verso Map (per JSON/database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'temperatura': temperature,
      'umidita': humidity,
      'pressione': pressure,
      'lat': latitude,
      'lng': longitude,
      'batteria': batteria,
      'timestamp': timestamp.toIso8601String(),
      'rssi': rssi,
      'snr': snr,
    };
  }

  // Crea una copia modificando solo alcuni campi
  NodeData copyWith({
    int? id,
    String? nome,
    double? temperature,
    double? humidity,
    double? pressure,
    double? latitude,
    double? longitude,
    int? batteria,
    DateTime? timestamp,
    int? rssi,
    int? snr,
  }) {
    return NodeData(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      pressure: pressure ?? this.pressure,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteria: batteria ?? this.batteria,
      timestamp: timestamp ?? this.timestamp,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
    );
  }

  // Rappresentazione testuale per debug
  @override
  String toString() {
    return 'NodeData(id: $id, nome: $nome, temp: ${temperature.toStringAsFixed(1)}°C, '
           'hum: ${humidity.toStringAsFixed(1)}%, press: ${pressure.toStringAsFixed(1)}hPa, '
           'bat: $batteria%, lat: ${latitude.toStringAsFixed(5)}, lng: ${longitude.toStringAsFixed(5)})';
  }

  // Confronto tra oggetti basato su ID e timestamp
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeData && other.id == id && other.timestamp == timestamp;
  }

  @override
  int get hashCode => id.hashCode ^ timestamp.hashCode;
}
