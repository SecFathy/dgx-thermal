import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import '../models/thermal_data.dart';

class SshService {
  SSHClient? _client;
  bool get isConnected => _client != null;

  Future<void> connect({
    required String host,
    required String username,
    required String password,
    int port = 22,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_client != null) {
      _client!.close();
      _client = null;
    }
    final socket = await SSHSocket.connect(host, port, timeout: timeout);
    _client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
    await _client!.authenticated;
  }

  Future<String> execute(String command) async {
    if (_client == null) throw StateError('Not connected');
    final session = await _client!.execute(command);
    final bytes = await session.stdout.toList();
    return utf8.decode(bytes.expand((x) => x).toList(), allowMalformed: true).trim();
  }

  void disconnect() {
    _client?.close();
    _client = null;
  }

  Future<ThermalReport> fetchThermalReport() async {
    final gpuQuery =
        'name,temperature.gpu,fan.speed,power.draw,power.limit,utilization.gpu,memory.used,memory.total';

    final results = await Future.wait([
      execute(
          'nvidia-smi --query-gpu=$gpuQuery --format=csv,noheader,nounits 2>/dev/null'),
      execute('hostname 2>/dev/null'),
      execute(
          'nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1'),
      execute(_sysTempsCmd),
    ]);

    final gpuRaw = results[0];
    final hostname = results[1].isEmpty ? 'Unknown' : results[1];
    final driver = results[2].isEmpty ? 'N/A' : results[2];
    final sysRaw = results[3];

    final gpus = <GpuThermalData>[];
    for (final (i, line) in gpuRaw.split('\n').indexed) {
      if (line.trim().isEmpty) continue;
      final g = GpuThermalData.fromCsvLine(i, line);
      if (g != null) gpus.add(g);
    }

    final systemTemps = _parseSystemTemps(sysRaw);

    return ThermalReport(
      gpus: gpus,
      systemTemps: systemTemps,
      fetchedAt: DateTime.now(),
      hostname: hostname,
      driverVersion: driver,
    );
  }

  static const _sysTempsCmd = r'''
python3 -c "
import os, glob
zones = glob.glob('/sys/class/thermal/thermal_zone*/temp')
names = glob.glob('/sys/class/thermal/thermal_zone*/type')
for z, n in zip(sorted(zones), sorted(names)):
    try:
        t = int(open(z).read().strip()) / 1000.0
        nm = open(n).read().strip()
        print(f'{nm},{t:.1f}')
    except: pass
" 2>/dev/null''';

  List<SystemThermalEntry> _parseSystemTemps(String raw) {
    final entries = <SystemThermalEntry>[];
    for (final line in raw.split('\n')) {
      final parts = line.trim().split(',');
      if (parts.length < 2) continue;
      final temp = double.tryParse(parts.last);
      if (temp == null) continue;
      final name = parts.sublist(0, parts.length - 1).join(',');
      if (temp > 0 && temp < 200) {
        entries.add(SystemThermalEntry(zone: name, temperatureC: temp));
      }
    }
    return entries;
  }
}
