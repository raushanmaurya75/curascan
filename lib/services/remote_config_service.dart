import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _instance;
  
  static Future<FirebaseRemoteConfig> getInstance() async {
    if (_instance != null) return _instance!;
    
    _instance = FirebaseRemoteConfig.instance;
    
    await _instance!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Set default values
    await _instance!.setDefaults({
      'gemini_api_key': '',
    });
    
    try {
      await _instance!.fetchAndActivate();
      print('✅ Firebase Remote Config initialized successfully');
    } catch (e) {
      print('⚠️ Firebase Remote Config fetch failed: $e');
    }
    
    return _instance!;
  }
  
  static Future<String> getGeminiApiKey() async {
    try {
      final remoteConfig = await getInstance();
      final key = remoteConfig.getString('gemini_api_key');
      
      if (key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE') {
        print('🔑 API Key loaded from Remote Config');
        return key;
      }
    } catch (e) {
      print('❌ Error getting API key from Remote Config: $e');
    }
    
    return '';
  }
}