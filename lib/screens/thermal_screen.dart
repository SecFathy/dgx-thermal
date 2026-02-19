import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../models/thermal_data.dart';
import '../widgets/gpu_card.dart';
import '../widgets/temp_arc.dart';
import 'connection_screen.dart';

class ThermalScreen extends StatelessWidget {
  const ThermalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ConnectionProvider>(
        builder: (ctx, provider, _) {
          return CustomScrollView(
            slivers: [
              _AppBar(provider: provider),
              if (provider.report == null)
                const SliverFillRemaining(child: _LoadingView())
              else ...[
                _SummaryHeader(report: provider.report!),
                _GpuList(gpus: provider.report!.gpus),
                if (provider.report!.systemTemps.isNotEmpty)
                  _SystemTempsSection(entries: provider.report!.systemTemps),
                _Footer(report: provider.report!),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final ConnectionProvider provider;
  const _AppBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          const Icon(Icons.device_thermostat, color: Color(0xFF30D158), size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thermal Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (provider.report != null)
                Text(
                  provider.report!.hostname,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (provider.refreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CupertinoActivityIndicator(color: Colors.white54),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: provider.fetchReport,
          ),
        _RefreshMenu(provider: provider),
        IconButton(
          icon: const Icon(Icons.power_settings_new, color: Color(0xFFFF3B30)),
          onPressed: () => _confirmDisconnect(context, provider),
        ),
      ],
    );
  }

  void _confirmDisconnect(BuildContext context, ConnectionProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Disconnect'),
        content: const Text('End SSH session and return to login?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              provider.disconnect();
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const ConnectionScreen()),
                (_) => false,
              );
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

class _RefreshMenu extends StatelessWidget {
  final ConnectionProvider provider;
  const _RefreshMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.timer_outlined, color: Colors.white54),
      color: const Color(0xFF1C1C1E),
      tooltip: 'Auto-refresh interval',
      onSelected: provider.setRefreshInterval,
      itemBuilder: (_) => [5, 10, 30, 60]
          .map(
            (s) => PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Icon(
                    provider.refreshIntervalSec == s
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: provider.refreshIntervalSec == s
                        ? const Color(0xFF30D158)
                        : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s}s',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final ThermalReport report;
  const _SummaryHeader({required this.report});

  Color get _statusColor {
    switch (report.overallLevel) {
      case ThermalLevel.critical:
        return const Color(0xFFFF3B30);
      case ThermalLevel.warning:
        return const Color(0xFFFF9500);
      case ThermalLevel.normal:
        return const Color(0xFF30D158);
    }
  }

  String get _statusLabel {
    switch (report.overallLevel) {
      case ThermalLevel.critical:
        return 'CRITICAL';
      case ThermalLevel.warning:
        return 'WARNING';
      case ThermalLevel.normal:
        return 'NORMAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            TempArc(
              temperature: report.maxGpuTemp,
              maxTemp: 100,
              level: report.overallLevel,
              size: 80,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SummaryStat(
                    label: 'GPUs',
                    value: report.gpus.length.toString(),
                  ),
                  _SummaryStat(
                    label: 'Peak Temp',
                    value: '${report.maxGpuTemp.toStringAsFixed(0)}°C',
                  ),
                  _SummaryStat(
                    label: 'Driver',
                    value: report.driverVersion,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpuList extends StatelessWidget {
  final List<GpuThermalData> gpus;
  const _GpuList({required this.gpus});

  @override
  Widget build(BuildContext context) {
    if (gpus.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No GPUs detected\nor nvidia-smi not available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => GpuCard(gpu: gpus[i]),
        childCount: gpus.length,
      ),
    );
  }
}

class _SystemTempsSection extends StatelessWidget {
  final List<SystemThermalEntry> entries;
  const _SystemTempsSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'SYSTEM TEMPERATURES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...entries.map((e) => _SysTempRow(entry: e)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SysTempRow extends StatelessWidget {
  final SystemThermalEntry entry;
  const _SysTempRow({required this.entry});

  Color get _color {
    if (entry.temperatureC >= 85) return const Color(0xFFFF3B30);
    if (entry.temperatureC >= 70) return const Color(0xFFFF9500);
    return const Color(0xFF30D158);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.thermostat, color: _color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.zone,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.temperatureC.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ThermalReport report;
  const _Footer({required this.report});

  @override
  Widget build(BuildContext context) {
    final time = report.fetchedAt;
    final label =
        'Last updated: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(color: Colors.white54, radius: 16),
          SizedBox(height: 16),
          Text(
            'Fetching thermal data…',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
