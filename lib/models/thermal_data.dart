enum ThermalLevel { normal, warning, critical }

// ── GPU (Blackwell B200) ─────────────────────────────────────────────────────

class GpuThermalData {
  final int index;
  final String name;
  final double temperatureC;
  final double memTemperatureC; // HBM3e junction temp (GB10 Blackwell)
  final double fanSpeedPct;
  final double powerDrawW;
  final double powerLimitW;
  final double gpuUtilPct;
  final double memUsedMiB;
  final double memTotalMiB;
  final double smClockMHz;
  final double memClockMHz;

  const GpuThermalData({
    required this.index,
    required this.name,
    required this.temperatureC,
    this.memTemperatureC = 0,
    required this.fanSpeedPct,
    required this.powerDrawW,
    required this.powerLimitW,
    required this.gpuUtilPct,
    required this.memUsedMiB,
    required this.memTotalMiB,
    this.smClockMHz = 0,
    this.memClockMHz = 0,
  });

  double get memUsedPct => memTotalMiB > 0 ? (memUsedMiB / memTotalMiB) * 100 : 0;
  double get powerUsedPct => powerLimitW > 0 ? (powerDrawW / powerLimitW) * 100 : 0;
  bool get hasMemTemp => memTemperatureC > 0;

  ThermalLevel get thermalLevel {
    if (temperatureC >= 85) return ThermalLevel.critical;
    if (temperatureC >= 75) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }

  ThermalLevel get memThermalLevel {
    if (memTemperatureC >= 95) return ThermalLevel.critical;
    if (memTemperatureC >= 85) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }

  // CSV format:
  // name,temp.gpu,temp.memory,fan,power.draw,power.limit,util.gpu,mem.used,mem.total,clk.sm,clk.mem
  static GpuThermalData? fromCsvLine(int idx, String line) {
    try {
      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.length < 9) return null;
      double parseSafe(String s) {
        final clean = s.replaceAll(RegExp(r'[^\d.\-]'), '');
        return double.tryParse(clean) ?? 0;
      }

      return GpuThermalData(
        index: idx,
        name: parts[0],
        temperatureC: parseSafe(parts[1]),
        memTemperatureC: parseSafe(parts[2]),
        fanSpeedPct: parseSafe(parts[3]),
        powerDrawW: parseSafe(parts[4]),
        powerLimitW: parseSafe(parts[5]),
        gpuUtilPct: parseSafe(parts[6]),
        memUsedMiB: parseSafe(parts[7]),
        memTotalMiB: parseSafe(parts[8]),
        smClockMHz: parts.length > 9 ? parseSafe(parts[9]) : 0,
        memClockMHz: parts.length > 10 ? parseSafe(parts[10]) : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

// ── System thermal zone (existing) ──────────────────────────────────────────

class SystemThermalEntry {
  final String zone;
  final double temperatureC;

  const SystemThermalEntry({required this.zone, required this.temperatureC});
}

// ── Grace CPU (Neoverse V2) ──────────────────────────────────────────────────

class CpuZoneTemp {
  final String name;
  final double tempC;
  const CpuZoneTemp({required this.name, required this.tempC});
}

class GraceCpuData {
  final List<CpuZoneTemp> zones;
  final double load1m;
  final double load5m;
  final double load15m;
  final int memTotalKiB;
  final int memAvailKiB;
  final int cpuCores;

  const GraceCpuData({
    required this.zones,
    this.load1m = 0,
    this.load5m = 0,
    this.load15m = 0,
    this.memTotalKiB = 0,
    this.memAvailKiB = 0,
    this.cpuCores = 0,
  });

  double get maxTempC =>
      zones.isEmpty ? 0 : zones.map((z) => z.tempC).reduce((a, b) => a > b ? a : b);

  double get avgTempC {
    if (zones.isEmpty) return 0;
    return zones.map((z) => z.tempC).reduce((a, b) => a + b) / zones.length;
  }

  double get memUsedPct {
    if (memTotalKiB <= 0) return 0;
    return ((memTotalKiB - memAvailKiB) / memTotalKiB) * 100;
  }

  double get memUsedGiB => (memTotalKiB - memAvailKiB) / (1024 * 1024);
  double get memTotalGiB => memTotalKiB / (1024 * 1024);

  ThermalLevel get thermalLevel {
    final t = maxTempC;
    if (t >= 90) return ThermalLevel.critical;
    if (t >= 75) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }
}

// ── Board / chipset sensors (lm-sensors, IPMI, NVSM) ────────────────────────

enum BoardSensorSource { sensors, ipmi, nvsm, unknown }

class BoardSensorEntry {
  final String name;
  final double tempC;
  final BoardSensorSource source;

  const BoardSensorEntry({
    required this.name,
    required this.tempC,
    this.source = BoardSensorSource.unknown,
  });

  ThermalLevel get level {
    if (tempC >= 85) return ThermalLevel.critical;
    if (tempC >= 70) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }
}

// ── Alert system ─────────────────────────────────────────────────────────────

class AlertThresholds {
  final double gpuWarnC;
  final double gpuCritC;
  final double gpuMemWarnC;
  final double gpuMemCritC;
  final double cpuWarnC;
  final double cpuCritC;
  final double boardWarnC;
  final double boardCritC;
  final bool enabled;

  const AlertThresholds({
    this.gpuWarnC = 75,
    this.gpuCritC = 85,
    this.gpuMemWarnC = 85,
    this.gpuMemCritC = 95,
    this.cpuWarnC = 75,
    this.cpuCritC = 90,
    this.boardWarnC = 70,
    this.boardCritC = 85,
    this.enabled = true,
  });

  AlertThresholds copyWith({
    double? gpuWarnC,
    double? gpuCritC,
    double? gpuMemWarnC,
    double? gpuMemCritC,
    double? cpuWarnC,
    double? cpuCritC,
    double? boardWarnC,
    double? boardCritC,
    bool? enabled,
  }) =>
      AlertThresholds(
        gpuWarnC: gpuWarnC ?? this.gpuWarnC,
        gpuCritC: gpuCritC ?? this.gpuCritC,
        gpuMemWarnC: gpuMemWarnC ?? this.gpuMemWarnC,
        gpuMemCritC: gpuMemCritC ?? this.gpuMemCritC,
        cpuWarnC: cpuWarnC ?? this.cpuWarnC,
        cpuCritC: cpuCritC ?? this.cpuCritC,
        boardWarnC: boardWarnC ?? this.boardWarnC,
        boardCritC: boardCritC ?? this.boardCritC,
        enabled: enabled ?? this.enabled,
      );
}

class AlertEvent {
  final DateTime time;
  final String component;
  final double tempC;
  final ThermalLevel level;
  final String message;

  const AlertEvent({
    required this.time,
    required this.component,
    required this.tempC,
    required this.level,
    required this.message,
  });
}

// ── ThermalReport ─────────────────────────────────────────────────────────────

class ThermalReport {
  final List<GpuThermalData> gpus;
  final List<SystemThermalEntry> systemTemps;
  final GraceCpuData? graceCpu;
  final List<BoardSensorEntry> boardSensors;
  final DateTime fetchedAt;
  final String hostname;
  final String driverVersion;

  const ThermalReport({
    required this.gpus,
    required this.systemTemps,
    this.graceCpu,
    this.boardSensors = const [],
    required this.fetchedAt,
    required this.hostname,
    required this.driverVersion,
  });

  bool get hasGpus => gpus.isNotEmpty;
  bool get hasCpu => graceCpu != null && graceCpu!.zones.isNotEmpty;
  bool get hasBoardSensors => boardSensors.isNotEmpty;

  double get maxGpuTemp =>
      gpus.isEmpty ? 0 : gpus.map((g) => g.temperatureC).reduce((a, b) => a > b ? a : b);

  ThermalLevel get overallLevel {
    final levels = <ThermalLevel>[
      if (gpus.isNotEmpty) ...[
        for (final g in gpus) g.thermalLevel,
        for (final g in gpus) if (g.hasMemTemp) g.memThermalLevel,
      ],
      if (graceCpu != null) graceCpu!.thermalLevel,
      for (final b in boardSensors) b.level,
    ];
    if (levels.any((l) => l == ThermalLevel.critical)) return ThermalLevel.critical;
    if (levels.any((l) => l == ThermalLevel.warning)) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }
}
