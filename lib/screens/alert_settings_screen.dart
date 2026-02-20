import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../models/thermal_data.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Color(0xFFFF9500), size: 18),
            SizedBox(width: 8),
            Text(
              'Alert Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF0A84FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Thresholds'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ThresholdTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ── Threshold configuration ──────────────────────────────────────────────────

class _ThresholdTab extends StatelessWidget {
  const _ThresholdTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (ctx, provider, _) {
        final t = provider.thresholds;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AlertToggle(
              enabled: t.enabled,
              onChanged: (v) =>
                  provider.updateThresholds(t.copyWith(enabled: v)),
            ),
            const SizedBox(height: 20),
            if (t.enabled) ...[
              _ThresholdSection(
                icon: Icons.memory,
                color: const Color(0xFF0A84FF),
                title: 'Blackwell GPU (B200)',
                subtitle: 'Die junction temperature',
                warnC: t.gpuWarnC,
                critC: t.gpuCritC,
                onWarnChanged: (v) =>
                    provider.updateThresholds(t.copyWith(gpuWarnC: v)),
                onCritChanged: (v) =>
                    provider.updateThresholds(t.copyWith(gpuCritC: v)),
              ),
              const SizedBox(height: 12),
              _ThresholdSection(
                icon: Icons.layers,
                color: const Color(0xFF5E5CE6),
                title: 'HBM3e Memory',
                subtitle: 'GPU memory (stacked DRAM)',
                warnC: t.gpuMemWarnC,
                critC: t.gpuMemCritC,
                onWarnChanged: (v) =>
                    provider.updateThresholds(t.copyWith(gpuMemWarnC: v)),
                onCritChanged: (v) =>
                    provider.updateThresholds(t.copyWith(gpuMemCritC: v)),
              ),
              const SizedBox(height: 12),
              _ThresholdSection(
                icon: Icons.developer_board,
                color: const Color(0xFF30D158),
                title: 'Grace CPU',
                subtitle: 'ARM Neoverse V2 die temperature',
                warnC: t.cpuWarnC,
                critC: t.cpuCritC,
                onWarnChanged: (v) =>
                    provider.updateThresholds(t.copyWith(cpuWarnC: v)),
                onCritChanged: (v) =>
                    provider.updateThresholds(t.copyWith(cpuCritC: v)),
              ),
              const SizedBox(height: 12),
              _ThresholdSection(
                icon: Icons.settings_input_component,
                color: const Color(0xFFFF9500),
                title: 'Board / Chipset',
                subtitle: 'IPMI, lm-sensors, NVSM readings',
                warnC: t.boardWarnC,
                critC: t.boardCritC,
                onWarnChanged: (v) =>
                    provider.updateThresholds(t.copyWith(boardWarnC: v)),
                onCritChanged: (v) =>
                    provider.updateThresholds(t.copyWith(boardCritC: v)),
              ),
              const SizedBox(height: 24),
              _ResetButton(onReset: () {
                provider.updateThresholds(const AlertThresholds());
              }),
            ],
          ],
        );
      },
    );
  }
}

class _AlertToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _AlertToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? const Color(0xFF30D158).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off,
            color: enabled ? const Color(0xFF30D158) : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Alerts',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                Text(
                  'Push notification on thermal anomaly',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF30D158),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double warnC;
  final double critC;
  final ValueChanged<double> onWarnChanged;
  final ValueChanged<double> onCritChanged;

  const _ThresholdSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.warnC,
    required this.critC,
    required this.onWarnChanged,
    required this.onCritChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Warning',
            value: warnC,
            min: 40,
            max: critC - 5,
            color: const Color(0xFFFF9500),
            onChanged: onWarnChanged,
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: 'Critical',
            value: critC,
            min: warnC + 5,
            max: 110,
            color: const Color(0xFFFF3B30),
            onChanged: onCritChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white12,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / 5).round(),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(0)}°C',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onReset;
  const _ResetButton({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Reset Thresholds'),
            content: const Text('Restore all thresholds to their defaults?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  onReset();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.restore, size: 16),
        label: const Text('Reset to Defaults'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: const BorderSide(color: Colors.white12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Alert history ─────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (ctx, provider, _) {
        final history = provider.alertHistory;
        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF30D158), size: 48),
                SizedBox(height: 12),
                Text(
                  'No alerts fired',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'All components within normal range',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${history.length} alert${history.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: provider.clearAlertHistory,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Color(0xFF0A84FF), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: history.length,
                itemBuilder: (_, i) => _AlertRow(event: history[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  final AlertEvent event;
  const _AlertRow({required this.event});

  Color get _color {
    switch (event.level) {
      case ThermalLevel.critical:
        return const Color(0xFFFF3B30);
      case ThermalLevel.warning:
        return const Color(0xFFFF9500);
      case ThermalLevel.normal:
        return const Color(0xFF30D158);
    }
  }

  String get _timeLabel {
    final t = event.time;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            event.level == ThermalLevel.critical
                ? Icons.error
                : Icons.warning_amber,
            color: _color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.component,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${event.tempC.toStringAsFixed(0)}°C',
                  style: TextStyle(color: _color, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _timeLabel,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
