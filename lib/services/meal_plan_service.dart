import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealPlanService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user's meal plan document reference
  static DocumentReference get _userMealPlanDoc {
    final userId = _auth.currentUser?.uid ?? '';
    return _firestore.collection('meal_plans').doc(userId);
  }

  // Check if user has generated a meal plan
  static Future<bool> hasMealPlan() async {
    try {
      final doc = await _userMealPlanDoc.get();
      return doc.exists && doc.data() != null;
    } catch (e) {
      return false;
    }
  }

  // Get stored meal plan
  static Future<Map<String, dynamic>?> getMealPlan() async {
    try {
      final doc = await _userMealPlanDoc.get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Save meal plan to Firestore
  static Future<void> saveMealPlan(Map<String, dynamic> mealPlan) async {
    try {
      await _userMealPlanDoc.set({
        ...mealPlan,
        'createdAt': FieldValue.serverTimestamp(),
        'progress': {},
        'lastProgressReset': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save meal plan');
    }
  }

  // Check if user can generate new meal plan (free or with points)
  static Future<bool> canGenerateNewPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final generatedCount = prefs.getInt('meal_plan_generated_count') ?? 0;
    final hasExisting = await hasMealPlan();
    final points = prefs.getInt('meal_plan_points') ?? 0;
    return generatedCount == 0 || !hasExisting || points > 0; // First free OR no existing OR has points
  }

  // Get meal plan points
  static Future<int> getMealPlanPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('meal_plan_points') ?? 0;
  }

  // Use meal plan point
  static Future<void> useMealPlanPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final points = prefs.getInt('meal_plan_points') ?? 0;
    if (points > 0) {
      await prefs.setInt('meal_plan_points', points - 1);
    }
  }

  // Add meal plan point from ad
  static Future<void> addMealPlanPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final points = prefs.getInt('meal_plan_points') ?? 0;
    await prefs.setInt('meal_plan_points', points + 1);
  }

  // Increment generation count
  static Future<void> incrementGenerationCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('meal_plan_generated_count') ?? 0;
    await prefs.setInt('meal_plan_generated_count', count + 1);
  }

  // Show rewarded ad for meal plan point
  static Future<bool> showRewardedAdForMealPlan() async {
    try {
      RewardedAd? rewardedAd;
      bool adWatched = false;
      bool adLoaded = false;

      RewardedAd.load(
        adUnitId: 'ca-app-pub-5335259902955088/8735853649',
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedAd = ad;
            adLoaded = true;
            print('Rewarded ad loaded successfully');
          },
          onAdFailedToLoad: (error) {
            print('Rewarded ad failed to load: $error');
            adLoaded = false;
          },
        ),
      );

      // Wait for ad to load
      int attempts = 0;
      while (!adLoaded && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (rewardedAd != null && adLoaded) {
        rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
          },
        );

        await rewardedAd!.show(onUserEarnedReward: (ad, reward) {
          adWatched = true;
          print('User earned reward: ${reward.amount}');
        });

        // Wait a moment for the reward callback to complete
        await Future.delayed(const Duration(milliseconds: 500));

        if (adWatched) {
          await addMealPlanPoint();
          print('Point added successfully');
        }
        return adWatched;
      } else {
        print('Rewarded ad not ready after waiting');
        return false;
      }
    } catch (e) {
      print('Error showing rewarded ad: $e');
      return false;
    }
  }

  // Update meal progress
  static Future<void> updateMealProgress(String day, String mealType, bool completed) async {
    try {
      await _userMealPlanDoc.update({
        'progress.$day.$mealType': completed,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update progress');
    }
  }

  // Get meal progress
  static Future<Map<String, dynamic>> getMealProgress() async {
    try {
      final doc = await _userMealPlanDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final progress = data['progress'] ?? {};
        
        // Reset progress if it's a new day
        final lastReset = data['lastProgressReset'] as Timestamp?;
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        
        if (lastReset == null || lastReset.toDate().isBefore(todayStart)) {
          // Reset progress for new day
          await _userMealPlanDoc.update({
            'progress': {},
            'lastProgressReset': FieldValue.serverTimestamp(),
          });
          return {};
        }
        
        return progress;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Delete current meal plan (for generating new one)
  static Future<void> deleteMealPlan() async {
    try {
      await _userMealPlanDoc.delete();
    } catch (e) {
      throw Exception('Failed to delete meal plan');
    }
  }
}