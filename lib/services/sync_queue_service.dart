import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puppal_app1/model/pet_profile.dart';
import 'package:puppal_app1/services/arduino_service.dart';

class SyncQueueService {
  static const String _queueKey = 'sync_queue_v1';
  static const String _lastSyncKey = 'last_sync_timestamp';

  /// Add a profile to the sync queue for offline devices
  static Future<void> queueForSync(PetProfile profile) async {
    final queue = await _loadQueue();

    // Remove any existing entry for this UID to avoid duplicates
    queue.removeWhere((item) => item['uidHex'] == profile.uidHex);

    // Add new entry with timestamp
    queue.add({
      'profile': profile.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });

    await _saveQueue(queue);
    print('📝 Queued profile ${profile.uidHex} for sync');
  }

  /// Process sync queue when a device comes online
  static Future<void> processSyncQueue() async {
    if (!ArduinoService.isConnected) {
      print('⚠️ No device connected, skipping sync queue');
      return;
    }

    final queue = await _loadQueue();
    if (queue.isEmpty) {
      print('✅ Sync queue is empty');
      return;
    }

    print('🔄 Processing sync queue (${queue.length} items)');

    final List<Map<String, dynamic>> failedItems = [];

    for (final item in queue) {
      try {
        final profile = PetProfile.fromJson(item['profile']);
        await ArduinoService.syncProfile(profile);

        print('✅ Synced profile ${profile.uidHex} to device');

        // Update last sync timestamp
        await _updateLastSync();
      } catch (e) {
        print('❌ Failed to sync profile ${item['profile']['uidHex']}: $e');

        // Increment retry count
        item['retryCount'] = (item['retryCount'] ?? 0) + 1;

        // Only keep items that haven't failed too many times
        if ((item['retryCount'] ?? 0) < 3) {
          failedItems.add(item);
        } else {
          print(
            '🗑️ Removing profile ${item['profile']['uidHex']} after 3 failed attempts',
          );
        }
      }
    }

    // Save back only the failed items
    await _saveQueue(failedItems);

    if (failedItems.isEmpty) {
      print('🎉 All profiles synced successfully!');
    } else {
      print('⚠️ ${failedItems.length} profiles still need syncing');
    }
  }

  /// Get the current sync queue status
  static Future<Map<String, dynamic>> getQueueStatus() async {
    final queue = await _loadQueue();
    final lastSync = await _getLastSync();

    return {
      'pendingCount': queue.length,
      'lastSync': lastSync,
      'hasPending': queue.isNotEmpty,
    };
  }

  /// Clear the sync queue (useful for testing or manual cleanup)
  static Future<void> clearQueue() async {
    await _saveQueue([]);
    print('🗑️ Sync queue cleared');
  }

  /// Load sync queue from storage
  static Future<List<Map<String, dynamic>>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey);

    if (queueJson == null) return [];

    try {
      final List<dynamic> queueList = jsonDecode(queueJson);
      return queueList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading sync queue: $e');
      return [];
    }
  }

  /// Save sync queue to storage
  static Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Update last sync timestamp
  static Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get last sync timestamp
  static Future<DateTime?> _getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }
}
