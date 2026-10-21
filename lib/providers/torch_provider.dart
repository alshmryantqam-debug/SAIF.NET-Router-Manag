import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_provider.dart';
import '../models/mikrotik_torch_model.dart';

/// A row returned by the router's Torch command. These are real router rows,
/// never locally fabricated packet data.
class TorchPacket {
  final String srcIp;
  final String dstIp;
  final String protocol;
  final String port;
  final double txSpeed;
  final double rxSpeed;
  final String interfaceName;

  const TorchPacket({
    required this.srcIp,
    required this.dstIp,
    required this.protocol,
    required this.port,
    required this.txSpeed,
    required this.rxSpeed,
    required this.interfaceName,
  });

  factory TorchPacket.fromRouter(Map<String, dynamic> row, String interfaceName) {
    final normalized = MikrotikTorch.fromMap(row);
    double rate(dynamic value) {
      if (value == null) return 0;
      final text = value.toString().trim().toLowerCase();
      // RouterOS rates may be numeric bps or formatted strings such as 1.5Mbps.
      final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*([kmgt]?)').firstMatch(text);
      if (match == null) return 0;
      final amount = double.tryParse(match.group(1) ?? '') ?? 0;
      final unit = match.group(2) ?? '';
      if (text.contains('bps')) {
        switch (unit) {
          case 'g': return amount * 1000;
          case 'm': return amount;
          case 'k': return amount / 1000;
          default: return amount / 1000000;
        }
      }
      // Bare RouterOS numeric tx/rx values are bits per second.
      return amount / 1000000;
    }

    return TorchPacket(
      srcIp: normalized.srcAddress,
      dstIp: normalized.dstAddress,
      protocol: normalized.protocol.toUpperCase(),
      port: normalized.port,
      txSpeed: rate(normalized.txSpeed),
      rxSpeed: rate(normalized.rxSpeed),
      interfaceName: interfaceName,
    );
  }
}

class TorchProvider extends ChangeNotifier {
  TorchProvider(this._connection);
  final ConnectionProvider _connection;

  bool _isSniffing = false;
  bool _disposed = false;
  String _selectedInterface = '';
  String _errorMessage = '';
  String _statusMessage = 'جاهز للمراقبة';
  List<TorchPacket> _packets = const [];
  Timer? _timer;
  bool _requestInFlight = false;

  bool get isSniffing => _isSniffing;
  String get selectedInterface => _selectedInterface;
  String get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  List<TorchPacket> get packets => List.unmodifiable(_packets);

  Future<void> startSniffing(String interfaceName) async {
    final name = interfaceName.trim();
    if (!_connection.isConnected) {
      _errorMessage = 'اتصل براوتر الإدارة أولاً.';
      _notify();
      return;
    }
    if (name.isEmpty) {
      _errorMessage = 'اختر واجهة صحيحة من الراوتر.';
      _notify();
      return;
    }
    stopSniffing();
    _selectedInterface = name;
    _isSniffing = true;
    _errorMessage = '';
    _statusMessage = 'جارٍ طلب بيانات Torch الحقيقية من الراوتر…';
    _packets = const [];
    _notify();
    await _poll();
    if (!_isSniffing || _disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!_isSniffing || _requestInFlight || _disposed) return;
    _requestInFlight = true;
    try {
      final rows = await _connection.getTorchPackets(_selectedInterface);
      if (!_isSniffing || _disposed) return;
      _packets = rows
          .whereType<Map>()
          .map((row) => TorchPacket.fromRouter(Map<String, dynamic>.from(row), _selectedInterface))
          .toList(growable: false);
      _errorMessage = '';
      _statusMessage = 'تحديث من الراوتر: ${_packets.length} تدفق';
    } catch (error) {
      if (_disposed) return;
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      _statusMessage = 'تعذر قراءة Torch؛ تحقق من دعم إصدار RouterOS والصلاحيات.';
      _timer?.cancel();
      _timer = null;
      _isSniffing = false;
    } finally {
      _requestInFlight = false;
      _notify();
    }
  }

  void stopSniffing() {
    _timer?.cancel();
    _timer = null;
    if (_isSniffing) {
      _isSniffing = false;
      _statusMessage = 'توقفت المراقبة';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
