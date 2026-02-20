import 'package:flutter/material.dart';
import '../models/thermal_data.dart';
import 'temp_arc.dart';

class CpuCard extends StatelessWidget {
  final GraceCpuData cpu;
  const CpuCard({super.key, required this.cpu});

  Color get _borderColor {
    switch (cpu.thermalLevel) {
      case ThermalLevel.critical:
        return const Color(0xFFFF3B30);
      case ThermalLevel.warning:
        return const Color(0xFFFF9500);
      case ThermalLevel.normal:
        return const Color(0xFF30D158);
    }
  }

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
            _CpuHeader(cpu: cpu),
            const SizedBox(height: 16),
            _CpuMetricsRow(cpu: cpu),
            if (cpu.memTotalKiB > 0) ...[
              const SizedBox(height: 14),
              _BarRow(
                label: 'MEM',
                value: cpu.memUsedPct,
                color: const Color(0xFF5E5CE6),
                detail:
                    '${cpu.memUsedGiB.toStringAsFixed(1)} / ${cpu.memTotalGiB.toStringAsFixed(0)} GB',
              ),
            ],
            if (cpu.cpuCores > 0 || cpu.load1m > 0) ...[
              const SizedBox(height: 8),
              _BarRow(
                label: 'LOAD',
                value: cpu.cpuCores > 0
                    ? (cpu.load1m / cpu.cpuCores * 100).clamp(0, 100)
                    : cpu.load1m.clamp(0, 100),
                color: const Color(0xFF0A84FF),
                detail:
                    '${cpu.load1m.toStringAsFixed(2)} / ${cpu.load5m.toStringAsFixed(2)} / ${cpu.load15m.toStringAsFixed(2)}',
              ),
            ],
            if (cpu.zones.length > 1) ...[
              const SizedBox(height: 14),
              _ZoneList(zones: cpu.zones),
            ],
          ],
        ),
      ),
    );
  }
}

class _CpuHeader extends StatelessWidget {
  final GraceCpuData cpu;
  const _CpuHeader({required this.cpu});

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
          child: const Text(
            'GRACE CPU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF30D158),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'NVIDIA Grace  •  Neoverse V2',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (cpu.cpuCores > 0)
          Text(
            '${cpu.cpuCores} cores',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
      ],
    );
  }
}

class _CpuMetricsRow extends StatelessWidget {
  final GraceCpuData cpu;
  const _CpuMetricsRow({required this.cpu});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TempArc(
          temperature: cpu.maxTempC,
          maxTemp: 100,
          level: cpu.thermalLevel,
          size: 90,
        ),
        if (cpu.load1m > 0)
          _StatColumn(
            label: '1m Load',
            value: cpu.load1m.toStringAsFixed(2),
            icon: Icons.speed,
            color: const Color(0xFF0A84FF),
          ),
        if (cpu.load5m > 0)
          _StatColumn(
            label: '5m Load',
            value: cpu.load5m.toStringAsFixed(2),
            icon: Icons.show_chart,
            color: const Color(0xFF64D2FF),
          ),
        if (cpu.zones.isNotEmpty)
          _StatColumn(
            label: 'Avg Temp',
            value: '${cpu.avgTempC.toStringAsFixed(1)}°C',
            icon: Icons.thermostat,
            color: const Color(0xFFFF9500),
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
  final String? detail;

  const _BarRow({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Text(
              detail!,
              style: const TextStyle(fontSize: 10, color: Colors.white30),
            ),
          ),
      ],
    );
  }
}

class _ZoneList extends StatefulWidget {
  final List<CpuZoneTemp> zones;
  const _ZoneList({required this.zones});

  @override
  State<_ZoneList> createState() => _ZoneListState();
}

class _ZoneListState extends State<_ZoneList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visible =
        _expanded ? widget.zones : widget.zones.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 8),
        const Text(
          'CPU ZONES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        ...visible.map((z) => _ZoneRow(zone: z)),
        if (widget.zones.length > 3)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded
                    ? 'Show less'
                    : '+ ${widget.zones.length - 3} more zones',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0A84FF),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final CpuZoneTemp zone;
  const _ZoneRow({required this.zone});

  Color get _color {
    if (zone.tempC >= 90) return const Color(0xFFFF3B30);
    if (zone.tempC >= 75) return const Color(0xFFFF9500);
    return const Color(0xFF30D158);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.memory, color: _color, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              zone.name,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${zone.tempC.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
