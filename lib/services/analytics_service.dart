import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // User Events
  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  // App Events
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // Food Scanning Events
  static Future<void> logFoodScan() async {
    await _analytics.logEvent(name: 'food_scan_started');
  }

  static Future<void> logFoodScanComplete(String result) async {
    await _analytics.logEvent(
      name: 'food_scan_completed',
      parameters: {'result': result},
    );
  }

  // Meal Plan Events
  static Future<void> logMealPlanGenerated() async {
    await _analytics.logEvent(name: 'meal_plan_generated');
  }

  static Future<void> logMealPlanProgress(int day) async {
    await _analytics.logEvent(
      name: 'meal_plan_progress',
      parameters: {'day': day},
    );
  }

  // Profile Events
  static Future<void> logProfileSetup() async {
    await _analytics.logEvent(name: 'profile_setup_started');
  }

  static Future<void> logProfileComplete() async {
    await _analytics.logEvent(name: 'profile_setup_completed');
  }

  // Ad Events
  static Future<void> logAdViewed(String adType) async {
    await _analytics.logEvent(
      name: 'ad_viewed',
      parameters: {'ad_type': adType},
    );
  }

  static Future<void> logRewardedAdWatched() async {
    await _analytics.logEvent(name: 'rewarded_ad_watched');
  }

  // Set user properties
  static Future<void> setUserProperties({
    String? userId,
    String? userType,
  }) async {
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }
    if (userType != null) {
      await _analytics.setUserProperty(name: 'user_type', value: userType);
    }
  }
}