import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/ssh_service.dart';
import '../models/thermal_data.dart';

enum ConnectionState { disconnected, connecting, connected, error }

class ConnectionProvider extends ChangeNotifier {
  final SshService _ssh = SshService();

  ConnectionState _state = ConnectionState.disconnected;
  String _errorMessage = '';
  ThermalReport? _report;
  bool _refreshing = false;
  Timer? _autoRefreshTimer;
  int _refreshIntervalSec = 10;

  ConnectionState get state => _state;
  String get errorMessage => _errorMessage;
  ThermalReport? get report => _report;
  bool get refreshing => _refreshing;
  int get refreshIntervalSec => _refreshIntervalSec;
  bool get isConnected => _ssh.isConnected;

  Future<void> connect({
    required String host,
    required String username,
    required String password,
    int port = 22,
  }) async {
    _state = ConnectionState.connecting;
    _errorMessage = '';
    notifyListeners();

    try {
      await _ssh.connect(
        host: host,
        username: username,
        password: password,
        port: port,
      );
      _state = ConnectionState.connected;
      notifyListeners();
      await fetchReport();
      _startAutoRefresh();
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = _friendlyError(e.toString());
      notifyListeners();
    }
  }

  Future<void> fetchReport() async {
    if (!_ssh.isConnected) return;
    _refreshing = true;
    notifyListeners();
    try {
      _report = await _ssh.fetchThermalReport();
    } catch (e) {
      _errorMessage = 'Fetch failed: ${_friendlyError(e.toString())}';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void setRefreshInterval(int seconds) {
    _refreshIntervalSec = seconds;
    _startAutoRefresh();
    notifyListeners();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSec),
      (_) => fetchReport(),
    );
  }

  void disconnect() {
    _autoRefreshTimer?.cancel();
    _ssh.disconnect();
    _state = ConnectionState.disconnected;
    _report = null;
    _errorMessage = '';
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('Connection refused')) return 'Connection refused — check host & port.';
    if (raw.contains('Host lookup') || raw.contains('Failed host')) {
      return 'Cannot reach host — check IP address.';
    }
    if (raw.contains('Authentication') || raw.contains('password')) {
      return 'Authentication failed — check credentials.';
    }
    if (raw.contains('timed out') || raw.contains('timeout')) {
      return 'Connection timed out — host unreachable.';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _ssh.disconnect();
    super.dispose();
  }
}
