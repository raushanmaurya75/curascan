import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanLimitService {
  static const String _scanCountKey = 'daily_scan_count';
  static const String _lastResetDateKey = 'last_reset_date';
  static const int _dailyLimit = 5;
  static const int _scansPerAd = 2;
  static const int _newUserScans = 5;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // AdMob Ad Unit IDs
  static const String _rewardedAdUnitId = 'ca-app-pub-5335259902955088/8735853649';
  static const String _interstitialAdUnitId = 'ca-app-pub-5335259902955088/9797955198';
  
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isInterstitialLoaded = false;
  
  // Callback for real-time scan count updates
  Function(int)? _onScanCountChanged;
  
  // Getter for rewarded ad
  RewardedAd? get rewardedAd => _rewardedAd;
  
  // Set callback for scan count changes
  void setScanCountCallback(Function(int) callback) {
    _onScanCountChanged = callback;
  }
  
  // Notify listeners of scan count change
  void _notifyScanCountChanged(int newCount) {
    _onScanCountChanged?.call((_dailyLimit - newCount).clamp(0, _dailyLimit));
  }

  // Get current scan count from Firestore
  Future<int> getCurrentScanCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    
    await _checkAndResetDaily();
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['dailyScanCount'] ?? 0;
  }

  // Get remaining scans
  Future<int> getRemainingScanCount() async {
    final current = await getCurrentScanCount();
    return (_dailyLimit - current).clamp(0, _dailyLimit);
  }

  // Check if user can scan
  Future<bool> canScan() async {
    final remaining = await getRemainingScanCount();
    return remaining > 0;
  }

  // Use a scan (only call this when result is generated)
  Future<bool> useScan() async {
    final user = _auth.currentUser;
    if (user == null || !await canScan()) return false;
    
    final current = await getCurrentScanCount();
    final newCount = current + 1;
    await _firestore.collection('users').doc(user.uid).update({
      'dailyScanCount': newCount,
      'lastScanDate': FieldValue.serverTimestamp(),
    });
    
    // Notify listeners immediately
    _notifyScanCountChanged(newCount);
    return true;
  }

  // Add scans from watching ad
  Future<void> addScansFromAd() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final current = await getCurrentScanCount();
    final newCount = (current - _scansPerAd).clamp(0, _dailyLimit);
    await _firestore.collection('users').doc(user.uid).update({
      'dailyScanCount': newCount,
    });
    
    // Notify listeners immediately
    _notifyScanCountChanged(newCount);
  }

  // Initialize new user with free scans
  Future<void> initializeNewUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data()?['dailyScanCount'] == null) {
      await _firestore.collection('users').doc(user.uid).set({
        'dailyScanCount': 0,
        'lastResetDate': DateTime.now().toIso8601String().split('T')[0],
        'totalScansUsed': 0,
      }, SetOptions(merge: true));
    }
  }

  // Check and reset daily count if needed
  Future<void> _checkAndResetDaily() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final lastReset = doc.data()?['lastResetDate'];
    
    if (lastReset != today) {
      await _firestore.collection('users').doc(user.uid).update({
        'dailyScanCount': 0,
        'lastResetDate': today,
      });
    }
  }

  // Load rewarded ad
  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _setAdCallbacks();
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // Set ad callbacks
  void _setAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd(); // Load next ad
      },
    );
  }

  // Show rewarded ad
  Future<bool> showRewardedAd() async {
    if (_isAdLoaded && _rewardedAd != null) {
      bool adWatched = false;
      
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          adWatched = true;
          addScansFromAd();
        },
      );
      
      return adWatched;
    }
    return false;
  }

  // Load interstitial ad
  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _setInterstitialCallbacks();
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _isInterstitialLoaded = false;
        },
      ),
    );
  }

  // Set interstitial ad callbacks
  void _setInterstitialCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialLoaded = false;
        loadInterstitialAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialLoaded = false;
        loadInterstitialAd(); // Load next ad
      },
    );
  }

  // Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      await _interstitialAd!.show();
    }
  }

  // Check if ads are ready
  bool isAdReady() => _isAdLoaded;
  bool isInterstitialReady() => _isInterstitialLoaded;

  // Dispose
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}