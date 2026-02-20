import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/thermal_data.dart';

class AlertService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Tracks last alerted level per component key to avoid spam
  static final Map<String, ThermalLevel> _lastAlertedLevel = {};

  static Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // request explicitly via requestPermissions()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    bool critical = false,
  }) async {
    if (!_initialized) return;
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(iOS: iosDetails),
    );
  }

  /// Evaluate a report against thresholds and fire notifications for any new alerts.
  /// Returns list of new AlertEvents triggered this cycle.
  static Future<List<AlertEvent>> evaluate(
    ThermalReport report,
    AlertThresholds thresholds,
  ) async {
    if (!thresholds.enabled) return [];
    final events = <AlertEvent>[];

    // ── GPU (Blackwell B200) ────────────────────────────────────────────────
    for (final gpu in report.gpus) {
      final key = 'gpu_${gpu.index}_temp';
      final level = _levelFor(gpu.temperatureC, thresholds.gpuWarnC, thresholds.gpuCritC);
      final event = await _maybeAlert(
        key: key,
        level: level,
        component: 'GPU ${gpu.index} (${gpu.name})',
        tempC: gpu.temperatureC,
        label: 'GPU temperature',
      );
      if (event != null) events.add(event);

      // HBM3e memory temperature
      if (gpu.hasMemTemp) {
        final memKey = 'gpu_${gpu.index}_mem';
        final memLevel = _levelFor(
            gpu.memTemperatureC, thresholds.gpuMemWarnC, thresholds.gpuMemCritC);
        final memEvent = await _maybeAlert(
          key: memKey,
          level: memLevel,
          component: 'GPU ${gpu.index} HBM3e Memory',
          tempC: gpu.memTemperatureC,
          label: 'HBM3e memory temperature',
        );
        if (memEvent != null) events.add(memEvent);
      }
    }

    // ── Grace CPU ───────────────────────────────────────────────────────────
    if (report.graceCpu != null && report.graceCpu!.zones.isNotEmpty) {
      const key = 'cpu_max';
      final maxTemp = report.graceCpu!.maxTempC;
      final level = _levelFor(maxTemp, thresholds.cpuWarnC, thresholds.cpuCritC);
      final event = await _maybeAlert(
        key: key,
        level: level,
        component: 'Grace CPU (Neoverse V2)',
        tempC: maxTemp,
        label: 'CPU temperature',
      );
      if (event != null) events.add(event);
    }

    // ── Board sensors ────────────────────────────────────────────────────────
    for (final sensor in report.boardSensors) {
      final key = 'board_${sensor.name.toLowerCase().replaceAll(' ', '_')}';
      final level =
          _levelFor(sensor.tempC, thresholds.boardWarnC, thresholds.boardCritC);
      final event = await _maybeAlert(
        key: key,
        level: level,
        component: sensor.name,
        tempC: sensor.tempC,
        label: 'sensor temperature',
      );
      if (event != null) events.add(event);
    }

    return events;
  }

  static ThermalLevel _levelFor(double temp, double warn, double crit) {
    if (temp >= crit) return ThermalLevel.critical;
    if (temp >= warn) return ThermalLevel.warning;
    return ThermalLevel.normal;
  }

  static Future<AlertEvent?> _maybeAlert({
    required String key,
    required ThermalLevel level,
    required String component,
    required double tempC,
    required String label,
  }) async {
    if (level == ThermalLevel.normal) {
      _lastAlertedLevel.remove(key);
      return null;
    }

    final last = _lastAlertedLevel[key];
    // Only alert if level is new or escalated
    if (last != null && _levelIndex(level) <= _levelIndex(last)) return null;

    _lastAlertedLevel[key] = level;

    final isCritical = level == ThermalLevel.critical;
    final title = isCritical
        ? '🔴 CRITICAL — $component'
        : '⚠️ WARNING — $component';
    final body =
        '${label.substring(0, 1).toUpperCase()}${label.substring(1)} is ${tempC.toStringAsFixed(0)}°C';

    final id = key.hashCode.abs() % 10000;
    await _show(id: id, title: title, body: body, critical: isCritical);

    return AlertEvent(
      time: DateTime.now(),
      component: component,
      tempC: tempC,
      level: level,
      message: '$body on $component',
    );
  }

  static int _levelIndex(ThermalLevel l) {
    switch (l) {
      case ThermalLevel.normal:
        return 0;
      case ThermalLevel.warning:
        return 1;
      case ThermalLevel.critical:
        return 2;
    }
  }

  /// Reset tracked alert states (call on disconnect)
  static void reset() => _lastAlertedLevel.clear();
}
