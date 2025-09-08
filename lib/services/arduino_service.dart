import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:my_new_app/model/pet_profile.dart';

class ArduinoService {
  static BluetoothConnection? _connection;

  // Set pet metadata on Arduino: SETMETA:UID:grams:density
  static Future<void> setMetadata(
    String uidHex,
    int gramsPerDay,
    int densityGramsPerCup,
  ) async {
    final command =
        'SETMETA:${uidHex.toUpperCase()}:$gramsPerDay:$densityGramsPerCup';
    await _sendCommand(command);
  }

  // Set time windows on Arduino: SETWINS:UID:start1,end1:start2,end2...
  static Future<void> setTimeWindows(
    String uidHex,
    List<TimeWindow> windows,
  ) async {
    if (windows.isEmpty) return;

    final windowsStr = windows
        .map((w) => '${w.startMinutes},${w.endMinutes}')
        .join(':');
    final command = 'SETWINS:${uidHex.toUpperCase()}:$windowsStr';
    await _sendCommand(command);
  }

  // Send complete profile to Arduino
  static Future<void> syncProfile(PetProfile profile) async {
    if (profile.gramsPerDay != null && profile.foodDensityGramsPerCup != null) {
      await setMetadata(
        profile.uidHex,
        profile.gramsPerDay!,
        profile.foodDensityGramsPerCup!,
      );
    }

    if (profile.allowedWindows?.isNotEmpty == true) {
      await setTimeWindows(profile.uidHex, profile.allowedWindows!);
    }
  }

  // Low-level command sender
  static Future<void> _sendCommand(String command) async {
    try {
      if (_connection == null || !_connection!.isConnected) {
        throw Exception('No active Bluetooth connection to Arduino');
      }

      _connection!.output.add(utf8.encode(command + '\n'));
      await _connection!.output.allSent;

      print('✅ Sent to Arduino: $command');
    } catch (e) {
      print('❌ Arduino command failed: $e');
      rethrow;
    }
  }

  // Set connection from BleManagerScreen
  static void setConnection(BluetoothConnection? connection) {
    _connection = connection;
  }
}
