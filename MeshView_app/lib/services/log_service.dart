import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Gestione dei log con salvataggio per mese.
/// Timestamp salvati come millisecondi per efficienza.
/// Parsing JSON pesante delegato a isolate tramite `compute()`.

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const String _logPrefix = 'mesh_log_';
  static const int _maxLogsPerMonth = 10000;
  static const int _monthsToKeep = 6;

  String _getMonthKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${_logPrefix}${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  /// Aggiunge i dati dei nodi al log del mese corrente.
  Future<void> addLog(List<Map<String, dynamic>> nodes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      DateTime now = DateTime.now();
      String monthKey = _getMonthKey(now);

      String? existingJson = prefs.getString(monthKey);
      List<Map<String, dynamic>> logs = [];

      if (existingJson != null && existingJson.isNotEmpty) {
        logs = await compute(_parseMonthJsonToList, existingJson);
      }

      final int ts = now.millisecondsSinceEpoch;
      for (var node in nodes) {
        logs.add({
          'timestamp': ts,
          'nodeId': node['id'],
          'nodeName': node['nome'] ?? 'Nodo ${node['id']}',
          'temperatura': node['temperatura'],
          'umidita': node['umidita'],
          'pressione': node['pressione'],
          'batteria': node['batteria'] ?? 0,
          'lat': node['lat'],
          'lng': node['lng'],
        });
      }

      if (logs.length > _maxLogsPerMonth) {
        logs = logs.sublist(logs.length - _maxLogsPerMonth);
      }

      await prefs.setString(monthKey, jsonEncode(logs));

      await _autoCleanOldLogs();

      print('✅ Log salvato: ${nodes.length} nodi in $monthKey');
    } catch (e) {
      print('❌ Errore salvataggio log: $e');
    }
  }

  /// Recupera i log di un singolo mese.
  Future<List<Map<String, dynamic>>> _getLogsForMonth(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String monthKey = _getMonthKey(date);
      String? jsonString = prefs.getString(monthKey);

      if (jsonString == null || jsonString.isEmpty) return [];

      List<Map<String, dynamic>> parsed =
          await compute(_parseMonthJsonToList, jsonString);

      return parsed.map((m) {
        final copy = Map<String, dynamic>.from(m);

        if (copy['timestamp'] is int) {
          copy['timestamp'] =
              DateTime.fromMillisecondsSinceEpoch(copy['timestamp']);
        } else if (copy['timestamp'] is String) {
          try {
            copy['timestamp'] = DateTime.parse(copy['timestamp']);
          } catch (_) {
            copy['timestamp'] = DateTime.now();
          }
        } else {
          copy['timestamp'] = DateTime.now();
        }

        return copy;
      }).toList();
    } catch (e) {
      print('❌ Errore caricamento log mese: $e');
      return [];
    }
  }

  /// Recupera i log da tutti i mesi salvati.
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> jsonStrings = [];

      Set<String> keys = prefs.getKeys();
      List<String> logKeys =
          keys.where((k) => k.startsWith(_logPrefix)).toList();
      logKeys.sort((a, b) => b.compareTo(a));

      for (String key in logKeys) {
        String? jsonString = prefs.getString(key);
        if (jsonString != null && jsonString.isNotEmpty) {
          jsonStrings.add(jsonString);
        }
      }

      if (jsonStrings.isEmpty) return [];

      List<Map<String, dynamic>> parsed =
          await compute(_parseMonthsJsonListToList, jsonStrings);

      final converted = parsed.map((m) {
        final copy = Map<String, dynamic>.from(m);
        final t = copy['timestamp'];

        if (t is int) {
          copy['timestamp'] = DateTime.fromMillisecondsSinceEpoch(t);
        } else if (t is String) {
          try {
            copy['timestamp'] = DateTime.parse(t);
          } catch (_) {
            copy['timestamp'] = DateTime.now();
          }
        } else {
          copy['timestamp'] = DateTime.now();
        }
        return copy;
      }).toList();

      converted.sort((a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      return converted;
    } catch (e) {
      print('❌ Errore caricamento log: $e');
      return [];
    }
  }

  /// Rimuove automaticamente i mesi più vecchi del limite configurato.
  Future<void> _autoCleanOldLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      List<String> logKeys =
          keys.where((k) => k.startsWith(_logPrefix)).toList();

      DateTime now = DateTime.now();

      for (String key in logKeys) {
        final parts = key.replaceFirst(_logPrefix, '').split('_');
        if (parts.length == 2) {
          int year = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          DateTime date = DateTime(year, month);

          int diffMonths =
              (now.year - date.year) * 12 + (now.month - date.month);

          if (diffMonths > _monthsToKeep) {
            await prefs.remove(key);
            print('🧹 Log eliminato: $key');
          }
        }
      }
    } catch (e) {
      print('❌ Errore pulizia automatica: $e');
    }
  }

  Future<List<String>> getAvailableMonths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      List<String> months = keys
          .where((k) => k.startsWith(_logPrefix))
          .map((k) => k.replaceFirst(_logPrefix, ''))
          .toList();

      months.sort((a, b) => b.compareTo(a));
      return months;
    } catch (e) {
      print('❌ Errore mesi: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLogsByMonth(String monthKey) async {
    try {
      List<String> parts = monthKey.split('_');
      int year = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      DateTime date = DateTime(year, month);
      return await _getLogsForMonth(date);
    } catch (e) {
      print('❌ Errore caricamento mese $monthKey: $e');
      return [];
    }
  }

  Future<void> clearMonth(String monthKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_logPrefix}$monthKey');
      print('🗑️ Log eliminati per mese: $monthKey');
    } catch (e) {
      print('❌ Errore eliminazione mese: $e');
    }
  }

  Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      List<String> logKeys =
          keys.where((k) => k.startsWith(_logPrefix)).toList();

      for (String key in logKeys) {
        await prefs.remove(key);
      }

      print('🗑️ Tutti i log eliminati');
    } catch (e) {
      print('❌ Errore eliminazione log: $e');
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    List<Map<String, dynamic>> logs = await getLogs();

    if (logs.isEmpty) {
      return {
        'totalLogs': 0,
        'nodesCount': 0,
        'avgTemperature': 0.0,
        'avgHumidity': 0.0,
        'avgPressure': 0.0,
        'monthsCount': 0,
      };
    }

    double totalTemp = 0;
    double totalHum = 0;
    double totalPress = 0;
    Set<int> uniqueNodes = {};

    for (var log in logs) {
      totalTemp += log['temperatura'] ?? 0;
      totalHum += log['umidita'] ?? 0;
      totalPress += log['pressione'] ?? 0;
      uniqueNodes.add(log['nodeId']);
    }

    int count = logs.length;
    List<String> months = await getAvailableMonths();

    return {
      'totalLogs': count,
      'nodesCount': uniqueNodes.length,
      'avgTemperature': totalTemp / count,
      'avgHumidity': totalHum / count,
      'avgPressure': totalPress / count,
      'oldestLog': logs.last['timestamp'],
      'newestLog': logs.first['timestamp'],
      'monthsCount': months.length,
    };
  }

  Future<String> exportMonthToCsv(String monthKey) async {
    List<Map<String, dynamic>> logs = await getLogsByMonth(monthKey);
    if (logs.isEmpty) return '';

    StringBuffer csv = StringBuffer();
    csv.writeln('Timestamp,NodeID,NodeName,Temperature,Humidity,Pressure,Battery,Latitude,Longitude');

    for (var log in logs) {
      final DateTime ts = _ensureDateTime(log['timestamp']);
      csv.writeln(
        '${ts.toIso8601String()},'
        '${log['nodeId']},'
        '${log['nodeName']},'
        '${log['temperatura']},'
        '${log['umidita']},'
        '${log['pressione']},'
        '${log['batteria']},'
        '${log['lat']},'
        '${log['lng']}'
      );
    }
    return csv.toString();
  }

  Future<String> exportAllToCsv() async {
    List<Map<String, dynamic>> logs = await getLogs();
    if (logs.isEmpty) return '';

    StringBuffer csv = StringBuffer();
    csv.writeln('Timestamp,NodeID,NodeName,Temperature,Humidity,Pressure,Battery,Latitude,Longitude');

    for (var log in logs) {
      final DateTime ts = _ensureDateTime(log['timestamp']);
      csv.writeln(
        '${ts.toIso8601String()},'
        '${log['nodeId']},'
        '${log['nodeName']},'
        '${log['temperatura']},'
        '${log['umidita']},'
        '${log['pressione']},'
        '${log['batteria']},'
        '${log['lat']},'
        '${log['lng']}'
      );
    }
    return csv.toString();
  }

  String formatMonthName(String monthKey) {
    try {
      List<String> parts = monthKey.split('_');
      int year = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      DateTime date = DateTime(year, month);
      return DateFormat('MMMM yyyy', 'it_IT').format(date);
    } catch (_) {
      return monthKey;
    }
  }

  DateTime _ensureDateTime(dynamic ts) {
    if (ts is DateTime) return ts;
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) {
      try {
        return DateTime.parse(ts);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}

/// Funzioni top-level richieste da compute() per il parsing JSON.

List<Map<String, dynamic>> _parseMonthJsonToList(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  final List<Map<String, dynamic>> out = [];

  for (var item in jsonList) {
    try {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item);

      final t = map['timestamp'];
      if (t is int) {
        map['timestamp'] = t;
      } else if (t is String) {
        try {
          map['timestamp'] = DateTime.parse(t).millisecondsSinceEpoch;
        } catch (_) {
          map['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        map['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      out.add(map);
    } catch (_) {
      // ignora elementi non validi
    }
  }

  return out;
}

List<Map<String, dynamic>> _parseMonthsJsonListToList(List<String> jsonStrings) {
  final List<Map<String, dynamic>> combined = [];
  for (var s in jsonStrings) {
    combined.addAll(_parseMonthJsonToList(s));
  }
  return combined;
}
