import 'package:flutter/material.dart';
import '../models/thermal_data.dart';
import 'temp_arc.dart';

class GpuCard extends StatelessWidget {
  final GpuThermalData gpu;

  const GpuCard({super.key, required this.gpu});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(gpu: gpu),
            const SizedBox(height: 16),
            _MetricsRow(gpu: gpu),
            const SizedBox(height: 14),
            _BarRow(label: 'GPU', value: gpu.gpuUtilPct, color: const Color(0xFF0A84FF)),
            const SizedBox(height: 8),
            _BarRow(label: 'VRAM', value: gpu.memUsedPct, color: const Color(0xFF5E5CE6)),
            const SizedBox(height: 8),
            _BarRow(label: 'PWR', value: gpu.powerUsedPct, color: const Color(0xFFFF9500)),
          ],
        ),
      ),
    );
  }

  Color get _borderColor {
    switch (gpu.thermalLevel) {
      case ThermalLevel.critical:
        return const Color(0xFFFF3B30);
      case ThermalLevel.warning:
        return const Color(0xFFFF9500);
      case ThermalLevel.normal:
        return const Color(0xFF30D158);
    }
  }
}

class _Header extends StatelessWidget {
  final GpuThermalData gpu;
  const _Header({required this.gpu});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'GPU ${gpu.index}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A84FF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            gpu.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final GpuThermalData gpu;
  const _MetricsRow({required this.gpu});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TempArc(
          temperature: gpu.temperatureC,
          maxTemp: 100,
          level: gpu.thermalLevel,
          size: 90,
        ),
        _StatColumn(
          label: 'Fan',
          value: '${gpu.fanSpeedPct.toStringAsFixed(0)}%',
          icon: Icons.air,
          color: const Color(0xFF64D2FF),
        ),
        _StatColumn(
          label: 'Power',
          value: '${gpu.powerDrawW.toStringAsFixed(0)}W',
          icon: Icons.bolt,
          color: const Color(0xFFFF9500),
        ),
        _StatColumn(
          label: 'VRAM',
          value: '${(gpu.memUsedMiB / 1024).toStringAsFixed(1)}G\n/ ${(gpu.memTotalMiB / 1024).toStringAsFixed(0)}G',
          icon: Icons.memory,
          color: const Color(0xFF5E5CE6),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BarRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 100.0);
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
