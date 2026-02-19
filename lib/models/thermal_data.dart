class GpuThermalData {
  final int index;
  final String name;
  final double temperatureC;
  final double fanSpeedPct;
  final double powerDrawW;
  final double powerLimitW;
  final double gpuUtilPct;
  final double memUsedMiB;
  final double memTotalMiB;

  const GpuThermalData({
    required this.index,
    required this.name,
    required this.temperatureC,
    required this.fanSpeedPct,
    required this.powerDrawW,
    required this.powerLimitW,
    required this.gpuUtilPct,
    required this.memUsedMiB,
    required this.memTotalMiB,
  });

  double get memUsedPct => memTotalMiB > 0 ? (memUsedMiB / memTotalMiB) * 100 : 0;
  double get powerUsedPct => powerLimitW > 0 ? (powerDrawW / powerLimitW) * 100 : 0;

  ThermalLevel get thermalLevel {
    if (temperatureC >= 85) return ThermalLevel.critical;
    if (temperatureC >= 75) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }

  static GpuThermalData? fromCsvLine(int idx, String line) {
    try {
      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.length < 9) return null;
      return GpuThermalData(
        index: idx,
        name: parts[0],
        temperatureC: double.tryParse(parts[1]) ?? 0,
        fanSpeedPct: double.tryParse(parts[2]) ?? 0,
        powerDrawW: double.tryParse(parts[3]) ?? 0,
        powerLimitW: double.tryParse(parts[4]) ?? 0,
        gpuUtilPct: double.tryParse(parts[5]) ?? 0,
        memUsedMiB: double.tryParse(parts[6]) ?? 0,
        memTotalMiB: double.tryParse(parts[7]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

enum ThermalLevel { normal, warning, critical }

class SystemThermalEntry {
  final String zone;
  final double temperatureC;

  const SystemThermalEntry({required this.zone, required this.temperatureC});
}

class ThermalReport {
  final List<GpuThermalData> gpus;
  final List<SystemThermalEntry> systemTemps;
  final DateTime fetchedAt;
  final String hostname;
  final String driverVersion;

  const ThermalReport({
    required this.gpus,
    required this.systemTemps,
    required this.fetchedAt,
    required this.hostname,
    required this.driverVersion,
  });

  bool get hasGpus => gpus.isNotEmpty;

  double get maxGpuTemp =>
      gpus.isEmpty ? 0 : gpus.map((g) => g.temperatureC).reduce((a, b) => a > b ? a : b);

  ThermalLevel get overallLevel {
    final max = maxGpuTemp;
    if (max >= 85) return ThermalLevel.critical;
    if (max >= 75) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }
}
