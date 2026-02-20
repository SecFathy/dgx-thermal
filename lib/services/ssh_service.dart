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
    // Enhanced query includes: name, GPU temp, HBM3e mem temp, fan, power draw,
    // power limit, GPU util, mem used, mem total, SM clock, mem clock
    const gpuQuery =
        'name,temperature.gpu,temperature.memory,fan.speed,power.draw,power.limit,'
        'utilization.gpu,memory.used,memory.total,clocks.current.sm,clocks.current.memory';

    final results = await Future.wait([
      execute(
          'nvidia-smi --query-gpu=$gpuQuery --format=csv,noheader,nounits 2>/dev/null'),
      execute('hostname 2>/dev/null'),
      execute(
          'nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1'),
      execute(_gb10SystemCmd),
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

    final parsed = _parseSystemOutput(sysRaw);

    return ThermalReport(
      gpus: gpus,
      systemTemps: parsed.systemTemps,
      graceCpu: parsed.graceCpu,
      boardSensors: parsed.boardSensors,
      fetchedAt: DateTime.now(),
      hostname: hostname,
      driverVersion: driver,
    );
  }

  // ── Comprehensive GB10 system metrics command ──────────────────────────────
  // Gathers: thermal zones, load avg, memory, lm-sensors, IPMI, NVSM
  // Each section is prefixed so the Dart parser can split cleanly.
  static const _gb10SystemCmd = r'''python3 -c "
import subprocess, os, glob, re, sys

# ── Thermal zones ────────────────────────────────────────────────────────────
zones = sorted(glob.glob('/sys/class/thermal/thermal_zone*/temp'))
ztypes = sorted(glob.glob('/sys/class/thermal/thermal_zone*/type'))
tz = []
for z, t in zip(zones, ztypes):
    try:
        v = float(open(z).read().strip()) / 1000.0
        n = open(t).read().strip()
        if 0 < v < 200:
            tz.append(n + '=' + str(round(v, 1)))
    except:
        pass
print('ZONES:' + ','.join(tz))

# ── CPU load ─────────────────────────────────────────────────────────────────
try:
    la = open('/proc/loadavg').read().strip().split()
    print('LOAD:' + ','.join(la[:3]))
except:
    pass

# ── Memory (LPDDR5x) ─────────────────────────────────────────────────────────
try:
    mi = {}
    for line in open('/proc/meminfo'):
        k = line.split(':')[0]
        if k in ('MemTotal', 'MemAvailable'):
            mi[k] = int(line.split()[1])
    print('MEM:' + str(mi.get('MemTotal', 0)) + ',' + str(mi.get('MemAvailable', 0)))
except:
    pass

# ── CPU core count ────────────────────────────────────────────────────────────
try:
    cores = sum(1 for l in open('/proc/cpuinfo') if l.startswith('processor'))
    print('CORES:' + str(cores))
except:
    pass

# ── lm-sensors ───────────────────────────────────────────────────────────────
try:
    out = subprocess.check_output(['sensors', '-A'], timeout=5,
                                  stderr=subprocess.DEVNULL).decode()
    chip = ''
    sens = []
    for line in out.split('\n'):
        stripped = line.strip()
        if not stripped:
            chip = ''
            continue
        if 'Adapter:' in stripped:
            continue
        if ':' not in stripped:
            chip = stripped
        else:
            name, rest = stripped.split(':', 1)
            m = re.search(r'[\+\-]?(\d+\.?\d*)', rest)
            if m and ('C' in rest or 'temp' in name.lower()):
                label = (chip + '/' + name.strip()).strip('/')
                sens.append(label + '=' + m.group(1))
    print('SENSORS:' + ';'.join(sens))
except:
    pass

# ── IPMI board sensors ────────────────────────────────────────────────────────
try:
    out = subprocess.check_output(
        ['ipmitool', 'sdr', 'type', 'Temperature'],
        timeout=8, stderr=subprocess.DEVNULL).decode()
    ipmis = []
    for line in out.split('\n'):
        parts = [p.strip() for p in line.split('|')]
        if len(parts) >= 3 and parts[2].strip() != 'ns':
            m = re.match(r'(\d+\.?\d*)', parts[1])
            if m and parts[0]:
                ipmis.append(parts[0] + '=' + m.group(1))
    print('IPMI:' + ';'.join(ipmis))
except:
    pass

# ── NVIDIA System Manager (DGX OS) ───────────────────────────────────────────
try:
    out = subprocess.check_output(
        ['nvsm', 'show', 'temps'],
        timeout=10, stderr=subprocess.DEVNULL).decode()
    nvsms = []
    for line in out.split('\n'):
        m = re.search(r'(.+?)\s*[=:]\s*(\d+\.?\d*)\s*[Cc]', line)
        if m:
            nvsms.append(m.group(1).strip() + '=' + m.group(2))
    print('NVSM:' + ';'.join(nvsms))
except:
    pass
" 2>/dev/null''';

  // ── CPU thermal zone names that belong to the Grace (ARM) die ───────────────
  static bool _isCpuZone(String name) {
    final n = name.toLowerCase();
    return n.contains('cpu') ||
        n.contains('arm') ||
        n.contains('neoverse') ||
        n.contains('grace') ||
        n.contains('cluster') ||
        n.contains('core') ||
        n.contains('big') ||
        n.contains('little');
  }

  // ── Parse the combined system output ─────────────────────────────────────
  _ParsedSystemData _parseSystemOutput(String raw) {
    final systemTemps = <SystemThermalEntry>[];
    final boardSensors = <BoardSensorEntry>[];
    final cpuZones = <CpuZoneTemp>[];
    double load1m = 0, load5m = 0, load15m = 0;
    int memTotalKiB = 0, memAvailKiB = 0, cpuCores = 0;

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('ZONES:')) {
        final data = trimmed.substring(6);
        for (final entry in data.split(',')) {
          if (!entry.contains('=')) continue;
          final idx = entry.lastIndexOf('=');
          final name = entry.substring(0, idx);
          final temp = double.tryParse(entry.substring(idx + 1));
          if (temp == null || temp <= 0 || temp >= 200) continue;

          if (_isCpuZone(name)) {
            cpuZones.add(CpuZoneTemp(name: name, tempC: temp));
          } else {
            systemTemps.add(SystemThermalEntry(zone: name, temperatureC: temp));
          }
        }
      } else if (trimmed.startsWith('LOAD:')) {
        final parts = trimmed.substring(5).split(',');
        if (parts.length >= 3) {
          load1m = double.tryParse(parts[0]) ?? 0;
          load5m = double.tryParse(parts[1]) ?? 0;
          load15m = double.tryParse(parts[2]) ?? 0;
        }
      } else if (trimmed.startsWith('MEM:')) {
        final parts = trimmed.substring(4).split(',');
        if (parts.length >= 2) {
          memTotalKiB = int.tryParse(parts[0]) ?? 0;
          memAvailKiB = int.tryParse(parts[1]) ?? 0;
        }
      } else if (trimmed.startsWith('CORES:')) {
        cpuCores = int.tryParse(trimmed.substring(6)) ?? 0;
      } else if (trimmed.startsWith('SENSORS:')) {
        _parseSensorEntries(
          trimmed.substring(8),
          BoardSensorSource.sensors,
          boardSensors,
        );
      } else if (trimmed.startsWith('IPMI:')) {
        _parseSensorEntries(
          trimmed.substring(5),
          BoardSensorSource.ipmi,
          boardSensors,
        );
      } else if (trimmed.startsWith('NVSM:')) {
        _parseSensorEntries(
          trimmed.substring(5),
          BoardSensorSource.nvsm,
          boardSensors,
        );
      }
    }

    // Deduplicate board sensors by name (prefer NVSM > IPMI > sensors)
    final seen = <String>{};
    final dedupedBoard = <BoardSensorEntry>[];
    for (final s in [
      ...boardSensors.where((b) => b.source == BoardSensorSource.nvsm),
      ...boardSensors.where((b) => b.source == BoardSensorSource.ipmi),
      ...boardSensors.where((b) => b.source == BoardSensorSource.sensors),
    ]) {
      final key = s.name.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        dedupedBoard.add(s);
      }
    }

    GraceCpuData? graceCpu;
    if (cpuZones.isNotEmpty || load1m > 0 || memTotalKiB > 0) {
      graceCpu = GraceCpuData(
        zones: cpuZones,
        load1m: load1m,
        load5m: load5m,
        load15m: load15m,
        memTotalKiB: memTotalKiB,
        memAvailKiB: memAvailKiB,
        cpuCores: cpuCores,
      );
    }

    return _ParsedSystemData(
      systemTemps: systemTemps,
      graceCpu: graceCpu,
      boardSensors: dedupedBoard,
    );
  }

  void _parseSensorEntries(
    String data,
    BoardSensorSource source,
    List<BoardSensorEntry> out,
  ) {
    if (data.isEmpty) return;
    for (final entry in data.split(';')) {
      if (!entry.contains('=')) continue;
      final idx = entry.lastIndexOf('=');
      final name = entry.substring(0, idx).trim();
      final temp = double.tryParse(entry.substring(idx + 1).trim());
      if (temp == null || temp <= 0 || temp >= 200 || name.isEmpty) continue;
      out.add(BoardSensorEntry(name: name, tempC: temp, source: source));
    }
  }
}

class _ParsedSystemData {
  final List<SystemThermalEntry> systemTemps;
  final GraceCpuData? graceCpu;
  final List<BoardSensorEntry> boardSensors;

  const _ParsedSystemData({
    required this.systemTemps,
    required this.graceCpu,
    required this.boardSensors,
  });
}
