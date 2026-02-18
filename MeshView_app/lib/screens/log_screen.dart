import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final Color bluFiordaliso = const Color(0xFF4A90E2);
  final _logService = LogService();

  List<String> availableMonths = [];
  String? selectedMonth;

  List<Map<String, dynamic>> allLogs = [];
  List<Map<String, dynamic>> visibleLogs = [];
  bool isLoading = false;
  static const int logsPerPage = 50;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadMonths();
    _loadLogs();
  }

  Future<void> _loadMonths() async {
    List<String> months = await _logService.getAvailableMonths();
    setState(() => availableMonths = months);
  }

  Future<void> _loadLogs() async {
    setState(() {
      isLoading = true;
      visibleLogs.clear();
      currentPage = 0;
    });

    List<Map<String, dynamic>> logs = selectedMonth == null
        ? await _logService.getLogs()
        : await _logService.getLogsByMonth(selectedMonth!);

    setState(() {
      allLogs = logs;
      _loadMoreLogs();
      isLoading = false;
    });
  }

  void _loadMoreLogs() {
    final start = currentPage * logsPerPage;
    final end = (start + logsPerPage).clamp(0, allLogs.length);
    if (start >= allLogs.length) return;

    setState(() {
      visibleLogs.addAll(allLogs.sublist(start, end));
      currentPage++;
    });
  }

  Future<void> _clearLogs() async {
    String title = selectedMonth == null
        ? 'Elimina Tutti i Log'
        : 'Elimina Log di ${_logService.formatMonthName(selectedMonth!)}';

    String content = selectedMonth == null
        ? 'Vuoi eliminare TUTTI i log di tutti i mesi?'
        : 'Vuoi eliminare i log di ${_logService.formatMonthName(selectedMonth!)}?';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (selectedMonth == null) {
        await _logService.clearLogs();
      } else {
        await _logService.clearMonth(selectedMonth!);
      }
      await _loadLogs();
      await _loadMonths();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log eliminati')),
        );
      }

      setState(() => selectedMonth = null);
    }
  }

  void _showMonthSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seleziona Periodo',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: bluFiordaliso)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tutti i Mesi'),
              trailing: selectedMonth == null
                  ? Icon(Icons.check, color: bluFiordaliso)
                  : null,
              onTap: () {
                setState(() => selectedMonth = null);
                Navigator.pop(context);
                _loadLogs();
              },
            ),
            const Divider(),
            ...availableMonths.map((month) {
              return ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(_logService.formatMonthName(month)),
                trailing: selectedMonth == month
                    ? Icon(Icons.check, color: bluFiordaliso)
                    : null,
                onTap: () {
                  setState(() => selectedMonth = month);
                  Navigator.pop(context);
                  _loadLogs();
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime timestamp) =>
      DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log', style: TextStyle(fontSize: 18)),
            if (selectedMonth != null)
              Text(
                _logService.formatMonthName(selectedMonth!),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: bluFiordaliso,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtra per mese',
            onPressed: availableMonths.isEmpty ? null : _showMonthSelector,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visibleLogs.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: visibleLogs.length,
                        itemBuilder: (context, index) {
                          final log = visibleLogs[index];
                          return _buildLogCard(log);
                        },
                      ),
                    ),
                    if (visibleLogs.length < allLogs.length)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bluFiordaliso,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loadMoreLogs,
                          icon: const Icon(Icons.add),
                          label: Text(
                              'Carica altri (${allLogs.length - visibleLogs.length})'),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            selectedMonth == null
                ? 'Nessun log disponibile'
                : 'Nessun log per ${_logService.formatMonthName(selectedMonth!)}',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Text('I dati ricevuti verranno salvati qui',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: bluFiordaliso.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bluFiordaliso.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.sensors, color: bluFiordaliso),
        ),
        title: Text(log['nodeName'] ?? 'Nodo ${log['nodeId']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          _formatDate(log['timestamp']),
          style: TextStyle(color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildDataItem('🌡️', 'Temperatura',
                            '${log['temperatura'].toStringAsFixed(1)}°C')),
                    Expanded(
                        child: _buildDataItem('💧', 'Umidità',
                            '${log['umidita'].toStringAsFixed(1)}%')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildDataItem('📊', 'Pressione',
                            '${log['pressione'].toStringAsFixed(1)} hPa')),
                    Expanded(
                        child: _buildDataItem(
                            '🔋', 'Batteria', '${log['batteria']}%')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bluFiordaliso.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
