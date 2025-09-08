import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_new_app/screens/theme.dart';
import 'package:my_new_app/shared/styled_button.dart';
import 'package:my_new_app/model/pet_profile.dart';
import 'package:my_new_app/services/profile_storage.dart';
import 'package:my_new_app/services/arduino_service.dart';

class BleManagerScreen extends StatefulWidget {
  const BleManagerScreen({super.key});

  @override
  State<BleManagerScreen> createState() => _BleManagerScreenState();
}

class _BleManagerScreenState extends State<BleManagerScreen> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDiscoveryResult> _scanResults = [];
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSub;
  bool _isDiscovering = false;

  BluetoothConnection? _connection;
  bool _isConnecting = false;
  bool _isConnected = false;
  final List<String> _logLines = [];
  final List<String> _uidList = [];
  final StringBuffer _incomingBuffer = StringBuffer();
  StreamSubscription<Uint8List>? _inputSub;

  // Simulator state
  bool _simulate = false;
  final Random _rng = Random();

  bool get _isAndroid => Platform.isAndroid;

  String? _pendingAddType; // 'dog' | 'cat' when last command was 0/1

  @override
  void initState() {
    super.initState();
    if (_isAndroid) {
      _initBluetooth();
    } else {
      _appendLog(
        'Running on non-Android platform; Bluetooth disabled. Use Simulator.',
      );
    }
  }

  Future<void> _initBluetooth() async {
    await _ensurePermissions();
    final state = await _bluetooth.state;
    setState(() {
      _bluetoothState = state;
    });
    _bluetooth.onStateChanged().listen((s) {
      setState(() {
        _bluetoothState = s;
      });
      if (s == BluetoothState.STATE_OFF) {
        _disposeConnection();
      }
    });
  }

  Future<void> _ensurePermissions() async {
    if (!_isAndroid) return;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    for (final e in statuses.entries) {
      _appendLog('perm ${e.key}: ${e.value}');
    }
  }

  Future<void> _ensureEnabled() async {
    if (!_isAndroid) return;
    if (_bluetoothState != BluetoothState.STATE_ON) {
      await _bluetooth.requestEnable();
    }
  }

  Future<void> _startDiscovery() async {
    if (_simulate || !_isAndroid)
      return; // disabled in simulator or non-Android
    await _ensureEnabled();
    setState(() {
      _scanResults = [];
      _isDiscovering = true;
    });
    _discoveryStreamSub = _bluetooth.startDiscovery().listen((r) {
      setState(() {
        final index = _scanResults.indexWhere(
          (e) => e.device.address == r.device.address,
        );
        if (index >= 0) {
          _scanResults[index] = r;
        } else {
          _scanResults.add(r);
        }
      });
    });
    _discoveryStreamSub?.onDone(() {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_simulate || !_isAndroid) return;
    if (_isConnecting || _isConnected) return;
    setState(() {
      _isConnecting = true;
    });
    try {
      final conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connection = conn;
        _isConnected = true;
        _simulate = false;
      });

      // ADD THIS LINE:
      ArduinoService.setConnection(
        conn,
      ); // Share connection with Arduino service

      _appendLog('Connected to ${device.name ?? device.address}');
      _inputSub = conn.input?.listen(_onDataReceived);
      _inputSub?.onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
          _appendLog('Connection closed');
        }
      });
    } catch (e) {
      _appendLog('Connection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _connectSimulator() {
    if (_isConnected) return;
    setState(() {
      _simulate = true;
      _isConnected = true;
    });
    // Preload simulator UID list from persisted profiles so they persist across sessions
    ProfileStorage.load().then((profiles) {
      if (!mounted) return;
      setState(() {
        _uidList
          ..clear()
          ..addAll(profiles.map((p) => p.uidHex.toUpperCase()));
      });
    });
    _appendLog('Simulator connected');
  }

  void _disposeConnection() {
    _inputSub?.cancel();
    _inputSub = null;
    _connection?.dispose();
    _connection = null;
    _isConnected = false;
    if (_simulate) {
      _simulate = false;
      _appendLog('Simulator disconnected');
    }
  }

  void _onDataReceived(Uint8List data) {
    final text = utf8.decode(data, allowMalformed: true);
    _incomingBuffer.write(text);
    String bufferStr = _incomingBuffer.toString();
    int newlineIdx;
    while ((newlineIdx = bufferStr.indexOf('\n')) != -1) {
      final line = bufferStr.substring(0, newlineIdx).trim();
      bufferStr = bufferStr.substring(newlineIdx + 1);
      _handleLine(line);
    }
    _incomingBuffer
      ..clear()
      ..write(bufferStr);
  }

  void _handleLine(String line) {
    if (line.isEmpty) return;
    setState(() {
      _logLines.add(line);
      if (_logLines.length > 500) {
        _logLines.removeAt(0);
      }
    });

    final uidMatch = RegExp(r"^UID\s+\d+:\s*([0-9A-Fa-f]{8})").firstMatch(line);
    if (uidMatch != null) {
      final hex = uidMatch.group(1)!.toUpperCase();
      if (!_uidList.contains(hex)) {
        setState(() {
          _uidList.add(hex);
        });
      }
      // Create profile if we know the pending type from last command
      if (_pendingAddType == 'dog' || _pendingAddType == 'cat') {
        ProfileStorage.upsert(
          PetProfile(uidHex: hex, type: _pendingAddType!, name: null),
        );
      }
      return;
    }

    final lower = line.toLowerCase();
    if (lower.contains('updated list') ||
        lower.contains('sending list') ||
        lower.contains('list start')) {
      // Do not clear during simulator refresh; only clear when talking to a real device
      if (!_simulate) {
        setState(() {
          _uidList.clear();
        });
      }
      return;
    }

    // Remove confirmation
    if (line.toLowerCase().startsWith('removed uid:')) {
      final m = RegExp(
        r"removed uid:\s*([0-9A-Fa-f]{8})",
      ).firstMatch(line.toLowerCase());
      if (m != null) {
        final hex = m.group(1)!.toUpperCase();
        ProfileStorage.removeByUid(hex);
      }
      return;
    }
  }

  Future<void> _sendText(String text) async {
    if (_simulate || !_isAndroid) {
      _appendLog('> $text');
      _handleSimulatorCommand(text.trim());
      return;
    }
    if (_connection == null || !_isConnected) return;
    try {
      if (text == '0')
        _pendingAddType = 'dog';
      else if (text == '1')
        _pendingAddType = 'cat';
      else
        _pendingAddType = null;

      _connection!.output.add(utf8.encode(text + "\n"));
      await _connection!.output.allSent;
      _appendLog('> $text');
    } catch (e) {
      _appendLog('Send error: $e');
    }
  }

  void _appendLog(String s) {
    setState(() {
      _logLines.add(s);
      if (_logLines.length > 500) {
        _logLines.removeAt(0);
      }
    });
  }

  // ---------- Simulator logic ----------
  String _randomUidHex() {
    final bytes = List<int>.generate(4, (_) => _rng.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  void _emitSimLine(String line) {
    _handleLine(line);
  }

  void _handleSimulatorCommand(String cmd) {
    if (cmd == 'GETUIDLIST') {
      _emitSimLine('Sending list...');
      for (int i = 0; i < _uidList.length; i++) {
        _emitSimLine('UID ${i + 1}: ${_uidList[i]}');
      }
      _emitSimLine('Updated list sent successfully');
      return;
    }
    if (cmd == '0' || cmd == '1') {
      final uid = _randomUidHex();
      _emitSimLine(
        'Scanned UID: ${uid.substring(0, 2)} ${uid.substring(2, 4)} ${uid.substring(4, 6)} ${uid.substring(6, 8)}',
      );
      if (!_uidList.contains(uid)) {
        setState(() {
          _uidList.add(uid);
        });
        // persist simulated add as dog/cat
        final t = cmd == '0' ? 'dog' : 'cat';
        ProfileStorage.upsert(PetProfile(uidHex: uid, type: t, name: null));
        _emitSimLine('New UID added!');
      } else {
        _emitSimLine('UID already exists');
      }
      return;
    }
    if (cmd == '2') {
      if (_uidList.isNotEmpty) {
        final removed = _uidList.removeLast();
        ProfileStorage.removeByUid(removed);
        _emitSimLine('Removed UID: $removed');
      } else {
        _emitSimLine('No UID to remove');
      }
      return;
    }
    _emitSimLine('Unknown command: $cmd');
  }

  @override
  void dispose() {
    _discoveryStreamSub?.cancel();
    _inputSub?.cancel();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanningDisabled = _isDiscovering || _simulate || !_isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('PupPal Bluetooth')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: StyledButton(
                    onPressed: scanningDisabled ? null : _startDiscovery,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isDiscovering ? Icons.search_off : Icons.search,
                          color: AppColors.titleColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAndroid
                              ? (_isDiscovering
                                    ? 'Scanning...'
                                    : 'Scan Devices')
                              : 'Scan (Android only)',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StyledButton(
                    onPressed: _isConnected
                        ? () {
                            _disposeConnection();
                            setState(() {});
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.link_off, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Disconnect',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StyledButton(
                    onPressed: _isConnected ? null : _connectSimulator,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.desktop_windows, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _simulate ? 'Simulator Active' : 'Use Simulator',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isConnected ? _buildControls() : _buildScanList(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logLines.length,
                  itemBuilder: (_, i) => Text(
                    _logLines[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanList() {
    return ListView.separated(
      itemCount: _scanResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = _scanResults[index];
        final device = r.device;
        return ListTile(
          title: Text(device.name ?? device.address),
          subtitle: Text(device.address),
          trailing: _isConnecting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () => _connect(device),
                ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StyledButton(
                  onPressed: () => _sendText('0'),
                  child: Text(
                    'Add Dog',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StyledButton(
                  onPressed: () => _sendText('1'),
                  child: Text(
                    'Add Cat',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StyledButton(
                  onPressed: () => _sendText('2'),
                  child: Text(
                    'Remove Pet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StyledButton(
                  onPressed: () {
                    // In simulator, do not clear persisted UIDs when refreshing list
                    if (!_simulate) {
                      setState(() {
                        _uidList.clear();
                      });
                    }
                    _sendText('GETUIDLIST');
                  },
                  child: Text(
                    'Refresh UID List',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _uidList.isEmpty
                  ? const Center(child: Text('No UIDs yet'))
                  : ListView.builder(
                      itemCount: _uidList.length,
                      itemBuilder: (_, i) {
                        final uid = _uidList[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.memory,
                            color: Colors.white70,
                          ),
                          title: Text(
                            uid,
                            style: const TextStyle(letterSpacing: 1.5),
                          ),
                          onTap: () => _confirmAndDeleteUid(uid),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteUid(String uidHex) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Pet Tag'),
        content: Text('Remove UID $uidHex?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteUid(uidHex);
  }

  Future<void> _deleteUid(String uidHex) async {
    if (_simulate || !_isAndroid) {
      // Simulator: remove locally and persist
      setState(() {
        _uidList.remove(uidHex);
      });
      await ProfileStorage.removeByUid(uidHex);
      _emitSimLine('Removed UID: $uidHex');
      return;
    }
    // Real device: send DEL:XXXXXXXX (no scan needed)
    await _sendText('DEL:$uidHex');
  }
}
