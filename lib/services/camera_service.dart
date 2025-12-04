import 'package:camera/camera.dart';

class CameraService {
  static List<CameraDescription>? _cameras;
  static bool _isInitialized = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cameras = await availableCameras();
      _isInitialized = true;
      print('✅ Camera service initialized with ${_cameras?.length ?? 0} cameras');
    } catch (e) {
      print('❌ Camera service failed: $e');
      _isInitialized = false;
    }
  }
  
  static Future<List<CameraDescription>?> getCameras() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _cameras;
  }
  
  static bool get isInitialized => _isInitialized;
}