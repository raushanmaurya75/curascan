import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/ai_service.dart';
import 'services/user_profile_service.dart';
import 'services/meal_plan_service.dart';
import 'services/alarm_service.dart';
import 'form.dart';

// Color Palette
const Color primaryGreen = Color(0xFF00796B);
const Color primaryLight = Color(0xFF4DB6AC);
const Color backgroundLight = Color(0xFFF0F4F7);
const Color cardWhite = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF212121);
const Color textLight = Color(0xFF757575);
const Color safeGreen = Color(0xFF4CAF50);

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _hasProfile = false;
  bool _isLoading = true;
  bool _isGeneratingPlan = false;
  Map<String, dynamic>? _mealPlan;
  String? _userGoal;
  Map<String, dynamic> _progress = {};
  bool _hasExistingPlan = false;
  bool _remindersEnabled = false;
  Map<String, String> _reminderTimes = {};
  int _mealPlanPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _checkProfile();
    _checkExistingMealPlan();
    _loadAlarmSettings();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ad unit
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('Banner ad loaded successfully');
          setState(() => _isBannerAdReady = true);
        },
        onAdFailedToLoad: (ad, err) {
          print('Banner ad failed to load: $err');
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  Future<void> _checkProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final profileDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('medicalProfile')
            .doc('current')
            .get();
        
        final hasProfile = profileDoc.exists && profileDoc.data()?['profileComplete'] == true;
        setState(() {
          _hasProfile = hasProfile;
          _isLoading = false;
        });

        if (hasProfile) {
          _generateMealPlan();
        }
      } else {
        setState(() {
          _hasProfile = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasProfile = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkExistingMealPlan() async {
    final hasExisting = await MealPlanService.hasMealPlan();
    if (hasExisting) {
      final existingPlan = await MealPlanService.getMealPlan();
      final progress = await MealPlanService.getMealProgress();
      if (existingPlan != null) {
        final goals = existingPlan['healthGoals'] as List?;
        _userGoal = goals?.isNotEmpty == true ? goals!.first : 'General Health';
        setState(() {
          _hasExistingPlan = true;
          _mealPlan = existingPlan;
          _progress = progress;
        });
      }
    }
  }

  Future<void> _loadAlarmSettings() async {
    final enabled = await AlarmService.areRemindersEnabled();
    final times = await AlarmService.getSavedTimes();
    final points = await MealPlanService.getMealPlanPoints();
    setState(() {
      _remindersEnabled = enabled;
      _reminderTimes = times;
      _mealPlanPoints = points;
    });
  }

  Future<void> _generateMealPlan() async {
    final canGenerate = await MealPlanService.canGenerateNewPlan();
    if (!canGenerate) {
      final watchedAd = await MealPlanService.showRewardedAdForMealPlan();
      if (!watchedAd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch ad to generate new meal plan')),
        );
        return;
      }
    }

    setState(() => _isGeneratingPlan = true);
    try {
      final userProfile = await UserProfileService.getUserProfile();
      if (userProfile != null) {
        final goals = userProfile['healthGoals'] as List?;
        _userGoal = goals?.isNotEmpty == true ? goals!.first : 'General Health';
        
        final mealPlan = await AIService.generateMealPlan(userProfile);
        await MealPlanService.saveMealPlan(mealPlan);
        await MealPlanService.incrementGenerationCount();
        
        setState(() {
          _mealPlan = mealPlan;
          _hasExistingPlan = true;
          _progress = {};
          _isGeneratingPlan = false;
        });
      }
    } catch (e) {
      setState(() => _isGeneratingPlan = false);
    }
  }

  Future<void> _generateNewPlan() async {
    final canGenerate = await MealPlanService.canGenerateNewPlan();
    final points = await MealPlanService.getMealPlanPoints();
    
    if (!canGenerate) {
      _showPointsDialog();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate New Plan'),
        content: Text(points > 0 ? 'This will use 1 point and replace your current meal plan. Continue?' : 'This will replace your current meal plan. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (points > 0) {
        await MealPlanService.useMealPlanPoint();
        setState(() => _mealPlanPoints = _mealPlanPoints - 1);
      }
      
      await MealPlanService.deleteMealPlan();
      setState(() => _isGeneratingPlan = true);
      
      try {
        final userProfile = await UserProfileService.getUserProfile();
        if (userProfile != null) {
          final goals = userProfile['healthGoals'] as List?;
          _userGoal = goals?.isNotEmpty == true ? goals!.first : 'General Health';
          
          final mealPlan = await AIService.generateMealPlan(userProfile);
          await MealPlanService.saveMealPlan(mealPlan);
          await MealPlanService.incrementGenerationCount();
          
          setState(() {
            _mealPlan = mealPlan;
            _hasExistingPlan = true;
            _progress = {};
            _isGeneratingPlan = false;
          });
        }
      } catch (e) {
        setState(() => _isGeneratingPlan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating meal plan: $e')),
        );
      }
    }
  }

  void _showPointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Points'),
        content: Text('You need 1 point to generate a new meal plan.\nCurrent points: $_mealPlanPoints\n\nWatch an ad to earn 1 point.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final watchedAd = await MealPlanService.showRewardedAdForMealPlan();
              if (watchedAd) {
                // Reload points from storage and update UI
                await _loadAlarmSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Earned 1 point! You can now generate a new meal plan.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ad not available. Please try again later.')),
                );
              }
            },
            child: const Text('Watch Ad (+1 Point)'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMealProgress(String day, String mealType) async {
    final currentStatus = _progress[day]?[mealType] ?? false;
    await MealPlanService.updateMealProgress(day, mealType, !currentStatus);
    
    setState(() {
      if (_progress[day] == null) _progress[day] = {};
      _progress[day][mealType] = !currentStatus;
    });
  }

  Future<void> _setupReminders() async {
    final times = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ReminderDialog(initialTimes: _reminderTimes),
    );

    if (times != null && times.isNotEmpty) {
      final breakfast = times['breakfast'] ?? '08:00';
      final lunch = times['lunch'] ?? '13:00';
      final dinner = times['dinner'] ?? '19:00';
      
      await AlarmService.scheduleMealReminders(
        breakfastTime: breakfast,
        lunchTime: lunch,
        dinnerTime: dinner,
      );
      
      setState(() {
        _remindersEnabled = true;
        _reminderTimes = times;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal reminders set successfully!')),
      );
    }
  }

  Future<void> _toggleReminders() async {
    if (_remindersEnabled) {
      await AlarmService.disableReminders();
      setState(() {
        _remindersEnabled = false;
        _reminderTimes = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal reminders turned off')),
      );
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundLight,
        appBar: AppBar(
          title: const Text('Meal Plan'),
          backgroundColor: backgroundLight,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    if (!_hasProfile) {
      return _buildProfileRequiredScreen();
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('My Meal Plan'),
        backgroundColor: backgroundLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: _isGeneratingPlan
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _hasExistingPlan && _mealPlan != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildPersonalizedHeader(),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                      if (_isBannerAdReady) _buildBannerAd(),
                      const SizedBox(height: 20),
                      ..._buildMealSections(),
                      const SizedBox(height: 20),
                      _buildTipsCard(),
                    ],
                  ),
                )
              : _buildEmptyState(),
    );
  }

  Widget _buildProfileRequiredScreen() {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('Meal Plan'),
        backgroundColor: backgroundLight,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu_rounded, size: 80, color: primaryGreen),
                  const SizedBox(height: 24),
                  Text('Setup Your Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 16),
                  Text(
                    'To get your personalized meal plan, we need to know about your health profile, dietary preferences, and goals.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textLight, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const MedicalProfileForm()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: cardWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      child: const Text('Complete Health Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu, color: cardWhite, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Your Personalized Meal Plan',
            style: TextStyle(color: cardWhite, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cardWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, color: cardWhite, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Goal: ${_userGoal ?? "General Health"}',
                  style: const TextStyle(color: cardWhite, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryLight.withOpacity(0.3)),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  List<Widget> _buildMealSections() {
    final meals = ['breakfast', 'lunch', 'dinner', 'snacks'];
    final icons = [Icons.wb_sunny, Icons.wb_cloudy, Icons.nightlight_round, Icons.local_cafe];
    final colors = [Colors.orange, primaryGreen, Colors.indigo, Colors.brown];
    
    return meals.asMap().entries.map((entry) {
      final index = entry.key;
      final meal = entry.value;
      final mealData = _mealPlan?[meal] as Map<String, dynamic>?;
      
      return _buildMealCard(
        meal.toUpperCase(),
        mealData?['items'] as List? ?? ['Sample meal item'],
        mealData?['calories'] ?? 300,
        icons[index],
        colors[index],
      );
    }).toList();
  }

  Widget _buildMealCard(String title, List items, int calories, IconData icon, Color color) {
    final mealType = title.toLowerCase();
    final today = DateTime.now().weekday;
    final dayKey = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][today - 1];
    final isCompleted = _progress[dayKey]?[mealType] ?? false;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text('~$calories calories', style: TextStyle(fontSize: 14, color: textLight)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleMealProgress(dayKey, mealType),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCompleted ? safeGreen : Colors.grey,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted ? textLight.withOpacity(0.6) : textDark,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: primaryGreen.withOpacity(0.5)),
          const SizedBox(height: 24),
          const Text('No Meal Plan Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 12),
          const Text(
            'Generate your personalized meal plan based on your health profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: textLight, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'First meal plan is FREE!\nAdditional plans require watching an ad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: primaryGreen, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _generateMealPlan,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate My Meal Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: cardWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryGreen.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars, color: primaryGreen, size: 16),
              const SizedBox(width: 4),
              Text(
                'Points: $_mealPlanPoints',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generateNewPlan,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('New Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: cardWhite,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _remindersEnabled ? _toggleReminders : _setupReminders,
                icon: Icon(_remindersEnabled ? Icons.notifications_active : Icons.notifications_off, size: 18),
                label: Text(_remindersEnabled ? 'Turn Off' : 'Set Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _remindersEnabled ? Colors.orange : Colors.grey,
                  foregroundColor: cardWhite,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: safeGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: safeGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: safeGreen, size: 24),
              const SizedBox(width: 12),
              const Text('Helpful Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Drink plenty of water throughout the day\n• Eat slowly and mindfully\n• Include variety in your meals\n• Listen to your body\'s hunger cues',
            style: TextStyle(fontSize: 14, color: textDark, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  final Map<String, String> initialTimes;
  
  const _ReminderDialog({required this.initialTimes});
  
  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late Map<String, String> times;
  
  @override
  void initState() {
    super.initState();
    times = Map.from(widget.initialTimes);
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Meal Reminders'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeSelector('Breakfast', 'breakfast'),
          _buildTimeSelector('Lunch', 'lunch'),
          _buildTimeSelector('Dinner', 'dinner'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, times),
          child: const Text('Save'),
        ),
      ],
    );
  }
  
  Widget _buildTimeSelector(String label, String key) {
    final currentTime = times[key] ?? '08:00';
    return ListTile(
      title: Text(label),
      trailing: Text(currentTime),
      onTap: () async {
        final timeParts = currentTime.split(':');
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 8,
            minute: int.tryParse(timeParts[1]) ?? 0,
          ),
        );
        if (time != null) {
          setState(() {
            times[key] = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          });
        }
      },
    );
  }
}