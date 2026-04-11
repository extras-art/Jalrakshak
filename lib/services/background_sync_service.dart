import 'dart:async';
import 'weather_service.dart';
import 'firebase_service.dart';
import '../data/location_data.dart';

class BackgroundSyncService {
  final WeatherService _weatherService = WeatherService();
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _pollingTimer;
  bool _isSyncing = false;

  // Singleton pattern
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  /// Starts the 5-second polling loop
  void startSync() {
    if (_pollingTimer != null) return;
    
    // SENTINEL: Initializing Continuous Sync Engine
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _performGlobalSweep();
    });
    
    // Immediate first sweep
    _performGlobalSweep();
  }

  /// Stops the polling loop
  void stopSync() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    // SENTINEL: Sync Engine Deactivated.
  }

  Future<void> _performGlobalSweep() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Staggered sweep to spread the 40 requests across the 5-second window
      const int batchSize = 5;
      for (int i = 0; i < locations.length; i += batchSize) {
        final batch = locations.skip(i).take(batchSize);
        
        await Future.wait(batch.map((node) async {
          try {
            final data = await _weatherService.fetchCurrentWeather(node.latitude, node.longitude);
            await _firebaseService.syncTelemetry(node.name, data);
          } catch (e) {
            // Sector-specific failure
          }
        }));
        
        // Stagger batches by 500ms
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await _firebaseService.updateMissionStatus(locations.length);
    } catch (e) {
      // Global sweep failure
    } finally {
      _isSyncing = false;
    }
  }
}
