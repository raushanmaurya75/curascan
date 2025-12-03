import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'form.dart';
import 'scan_food.dart';
import 'meal_plan.dart';
import 'yoga_session.dart';
import 'services/auth_service.dart';
import 'services/scan_limit_service.dart';
import 'services/prescription_service.dart';
import 'services/analytics_service.dart';
import 'showcase.dart';

// --- UPDATED PREMIUM COLOR PALETTE ---
// This palette is now the source of colors.
const Color primaryGreen = Color(0xFF00796B);       // Primary accent color (Theme Color)
const Color primaryDark = Color(0xFF00796B);        // Using Primary Green for dark text/icons based on the provided colors
const Color primaryLight = Color(0xFF4DB6AC);       // Lighter gradient/highlight
const Color backgroundLight = Color(0xFFF0F4F7);    // Background/soft screen background (using your backgroundGray)
const Color cardWhite = Color(0xFFFFFFFF);          // Pure white for floating elements
const Color textDark = Color(0xFF212121);           // Deep black for headlines
const Color textLight = Color(0xFF757575);          // Subtle gray for body text
const Color shadowDark = Color(0xFFC5DDE8);         // Using your shadowColor
const Color shadowLight = Color(0xFFFFFFFF);        // Pure white for lift (kept for consistency in neumorphic style)
const Color lightFill = Color(0xFFE8F5E9);          // Very light green for form field background

// Placeholder Classes 
class AuthPage extends StatelessWidget { 
  const AuthPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Auth Page / Login")));
}

// Backwards-compatible wrappers expected by tests and the web entrypoint
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomePage();
}

class DoctorFinderApp extends StatelessWidget {
  const DoctorFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CuraScan',
      // Using the primaryGreen as the application's primary color
      theme: ThemeData(
        useMaterial3: true, 
        // 🎯 FIX: primaryColor is now set to your new primaryGreen
        primaryColor: primaryGreen, 
        // Setting color scheme for consistent button/tab bar colors
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen, primary: primaryGreen),
        scaffoldBackgroundColor: backgroundLight, // Set default scaffold background
      ),
      home: const HomeScreen(),
    );
  }
}

void main() {
  runApp(const DoctorFinderApp());
}
// =================================================================
// 0. DIALOG WIDGET (Using Theme Primary Color)
// =================================================================
class _ProfileSetupDialog extends StatelessWidget {
  const _ProfileSetupDialog();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      backgroundColor: cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 20,
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Text(
                  'Health ID & Prescription 📝',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 24),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: primaryColor,
                  ),
                  labelColor: cardWhite,
                  unselectedLabelColor: textDark.withOpacity(0.7),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: '✓ Fill Form (Recommended)'),
                    Tab(text: 'Upload Rx'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFillFormTabWithForm(context, primaryColor),
                    _buildUploadRxTab(context, primaryLight),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Maybe Later', style: TextStyle(color: textLight, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadRxTab(BuildContext context, Color primaryLight) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Upload a clear image of your prescription to auto-fill your medical profile.", 
            textAlign: TextAlign.center, 
            style: TextStyle(color: textLight, fontSize: 15),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: () => _uploadPrescription(context),
            icon: const Icon(Icons.camera_alt_outlined, size: 24),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryLight.withOpacity(0.8),
              foregroundColor: cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
          ),
          const SizedBox(height: 15),
          Text("— OR —", style: TextStyle(fontWeight: FontWeight.bold, color: textLight.withOpacity(0.5))),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () => _uploadPrescription(context, fromGallery: true),
            icon: const Icon(Icons.photo_library_outlined, size: 24),
            label: const Text('Choose from Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryLight.withOpacity(0.6),
              foregroundColor: cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPrescription(BuildContext context, {bool fromGallery = false}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        Navigator.pop(context); // Close dialog
        _showProcessingDialog(context);
        
        final File imageFile = File(image.path);
        final extractedText = await PrescriptionService.extractTextFromImage(imageFile);
        final profileData = await PrescriptionService.parseTextToProfile(extractedText);
        await PrescriptionService.saveParsedProfile(profileData);
        
        Navigator.pop(context); // Close processing dialog
        _showSuccessDialog(context, profileData);
      }
    } catch (e) {
      Navigator.pop(context); // Close processing dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing prescription: $e')),
      );
    }
  }

  void _showProcessingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Processing prescription...'),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, Map<String, dynamic> profileData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medical profile extracted from prescription:'),
            const SizedBox(height: 8),
            if (profileData['diseases']?.isNotEmpty == true)
              Text('Conditions: ${(profileData['diseases'] as List).join(', ')}'),
            if (profileData['medications']?.isNotEmpty == true)
              Text('Medications: ${(profileData['medications'] as List).join(', ')}'),
            if (profileData['allergies']?.isNotEmpty == true)
              Text('Allergies: ${(profileData['allergies'] as List).join(', ')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildFillFormTabWithForm(BuildContext context, Color primaryColor) {
    // Display the full MedicalProfileForm from form.dart
    return const MedicalProfileForm();
  }
}

// =================================================================
// 1. HOME PAGE IMPLEMENTATION (Updated)
// =================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Corrected index list to place Scan (index 2) in the center of the UI elements
  // The actual pages list will remain [0:Home, 1:Yoga, 2:Scan, 3:Diet]
  // The bottom bar order will be [Home(0), Diet(3), Scan(2), Yoga(1)] 
  int _selectedIndex = 0; // The index of the selected page in the _pages list
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // User Data
  String _userName = 'Loading...';
  String _userEmail = 'Loading...';
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScanLimitService _scanLimitService = ScanLimitService();
  int _remainingScans = 5;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeScanService();
    _scanLimitService.loadRewardedAd();
    _pages = <Widget>[
      _HomeContent(
        onStartProfileSetup: _showProfileSetupDialog,
        onNavigateToScan: _navigateToScan,
      ), 
      const Center(child: Text('🧘‍♀️ Yoga & Meditation Dashboard')),
      const ScanFoodPage(),
      const Center(child: Text('🥗 Personalized Diet Plan')),
    ];
  }
  
  Future<void> _initializeScanService() async {
    await _scanLimitService.initializeNewUser();
    final remaining = await _scanLimitService.getRemainingScanCount();
    setState(() {
      _remainingScans = remaining;
    });
  }

  Future<void> _loadScanLimit() async {
    final remaining = await _scanLimitService.getRemainingScanCount();
    setState(() {
      _remainingScans = remaining;
    });
  }

  @override
  void dispose() {
    _scanLimitService.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        setState(() {
          _userName = userData['name'] ?? user.displayName ?? 'User';
          _userEmail = userData['email'] ?? user.email ?? 'No email';
        });
      } else {
        setState(() {
          _userName = user.displayName ?? 'User';
          _userEmail = user.email ?? 'No email';
        });
      }
    }
  }

  // Helper to map the bottom bar tap index to the actual page index
  void _onBottomBarTapped(int barIndex) async {
    if (barIndex == 2) { // Scan option
      _navigateToScan();
      return;
    }
    
    if (barIndex == 1) { // Diet option
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MealPlanPage()),
      );
      return;
    }
    
    if (barIndex == 3) { // Yoga option
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const YogaSessionPage()),
      );
      return;
    }
    
    int pageIndex;
    switch (barIndex) {
      case 0: // Home
        pageIndex = 0;
        break;
      default:
        pageIndex = 0;
    }

    setState(() {
      _selectedIndex = pageIndex;
    });
  }

  // Helper to get the bottom bar index from the page index (for indicator)
  // (Removed unused helper _getPageToBarIndex) 

  void _showProfileSetupDialog() {
    AnalyticsService.logProfileSetup();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const _ProfileSetupDialog();
      },
    );
  }

  // =================================================================
  // WIDGET: THE APP BAR (Logo to Left)
  // =================================================================
  PreferredSizeWidget _buildHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 20, right: 20),
        child: Row(
          children: [
            Image.asset(
              'assets/images/curascan_transparent_croped.png',
              height: 60,
              width: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.healing_outlined, color: primaryDark, size: 64);
              },
            ),
            const Spacer(),
            // Scan limit display
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
                  Icon(Icons.qr_code_scanner, color: primaryGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_remainingScans/5',
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: Container(
                margin: const EdgeInsets.only(right: 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: primaryLight.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: const AssetImage('assets/images/boy.jpg'),
                  backgroundColor: primaryLight.withOpacity(0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... _buildDrawer remains the same ...
  Widget _buildDrawer() {
    // Drawer code remains the same, using Theme.of(context).primaryColor
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75, 
      child: Container(
        color: backgroundLight,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              height: 200, 
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor.withOpacity(0.8), primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cardWhite, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: const AssetImage('assets/images/boy.jpg'),
                      backgroundColor: primaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cardWhite)),
                  Text(_userEmail, style: TextStyle(fontSize: 13, color: cardWhite.withOpacity(0.8))),
                ],
              ),
            ),
            
            // Change Name - Connected to database
            _buildDrawerTile(
              Icons.edit_note_outlined,
              'Change Name',
              onTap: () {
                Navigator.pop(context);
                _showChangeNameDialog();
              },
            ),

            // Edit Health Form - Connected to database
            _buildDrawerTile(
              Icons.assignment_add,
              'Edit Health Form',
              onTap: () {
                Navigator.pop(context);
                _showProfileSetupDialog();
              },
            ),

            // View Profile Data - Connected to database
            _buildDrawerTile(
              Icons.person_outline,
              'View Profile Data',
              onTap: () {
                Navigator.pop(context);
                _showProfileData();
              },
            ),

            // Help & Feedback - Placeholder (as requested)
            _buildDrawerTile(
              Icons.help_outline,
              'Help & Feedback',
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),

            const Divider(height: 30, thickness: 1, indent: 20, endIndent: 20, color: textLight),
            _buildDrawerTile(
              Icons.logout_outlined, 
              'Logout', 
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, {bool isDestructive = false, VoidCallback? onTap}) {
    Color color = isDestructive ? Colors.red.shade700 : primaryDark;
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(
        title, 
        style: TextStyle(
          color: color, 
          fontSize: 16, 
          fontWeight: FontWeight.w600
        ),
      ),
      onTap: onTap ?? () { Navigator.pop(context); /* Navigate */ },
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
    );
  }

  // Show dialog to change the user's name with database update
  void _showChangeNameDialog() {
    final TextEditingController _nameController = TextEditingController(text: _userName);
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final primaryColor = Theme.of(context).primaryColor;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Display Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        filled: true,
                        fillColor: lightFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: Text('Cancel', style: TextStyle(color: textLight)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            final newName = _nameController.text.trim();
                            if (newName.isEmpty) return;
                            
                            setState(() => _isLoading = true);
                            
                            try {
                              final user = _authService.currentUser;
                              if (user != null) {
                                // Update in Firestore
                                await _firestore.collection('users').doc(user.uid).update({
                                  'name': newName,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                
                                // Update local state
                                this.setState(() {
                                  _userName = newName;
                                });
                                
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Name updated successfully!')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update name: $e')),
                              );
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: cardWhite,
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cardWhite))
                            : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help & Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Need help or want to share feedback?'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _launchEmail('tivitji@gmail.com', 'Help Request'),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Help: tivitji@gmail.com',
                        style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _launchEmail('nitinpatel.myname10@gmail.com', 'Feedback'),
                child: Row(
                  children: [
                    Icon(Icons.feedback_outlined, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Feedback: nitinpatel.myname10@gmail.com',
                        style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _launchEmail(String email, String subject) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app. Please email: $email')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app. Please email: $email')),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              AnalyticsService.logLogout();
              await _authService.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: cardWhite,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Check if medical profile exists
  Future<bool> _checkMedicalProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;
      
      final profileDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .get();
      
      return profileDoc.exists && profileDoc.data()?['profileComplete'] == true;
    } catch (e) {
      return false;
    }
  }

  // Navigate to scan with profile and limit check
  void _navigateToScan() async {
    final hasProfile = await _checkMedicalProfile();
    
    if (!hasProfile) {
      _showProfileRequiredDialog();
      return;
    }
    
    final canScan = await _scanLimitService.canScan();
    if (!canScan) {
      _showScanLimitDialog();
      return;
    }
    
    AnalyticsService.logFoodScan();
    
    // Navigate to scan page without deducting scan count
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ScanFoodPage(
        onScanComplete: () async {
          // Deduct scan count only when result is generated
          await _scanLimitService.useScan();
          await _loadScanLimit();
        },
      )),
    );
  }
  
  // Show dialog when scan limit is reached
  void _showScanLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Daily Limit Reached'),
          ],
        ),
        content: const Text(
          'You\'ve used all 5 daily scans. Watch an ad to get 2 more scans or wait until tomorrow for a fresh start!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_scanLimitService.isAdReady()) {
                _scanLimitService.rewardedAd!.show(
                  onUserEarnedReward: (ad, reward) async {
                    await _scanLimitService.addScansFromAd();
                    await _loadScanLimit();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Great! You earned 2 more scans!')),
                      );
                    }
                  },
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ad not ready. Please try again in a moment.')),
                );
                _scanLimitService.loadRewardedAd();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: cardWhite,
            ),
            child: const Text('Watch Ad (+2 Scans)'),
          ),
        ],
      ),
    );
  }

  // Show dialog when profile is required
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Profile Required'),
          ],
        ),
        content: const Text(
          'Please complete your medical profile first to use the food scan feature safely. This helps us provide personalized recommendations.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showProfileSetupDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: cardWhite,
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  // Show user's medical profile data
  void _showProfileData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final profileDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .get();
      
      if (!profileDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No profile data found. Please complete your health form first.')),
        );
        return;
      }
      
      final data = profileDoc.data()!;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Health Profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Age: ${data['age'] ?? 'Not set'}'),
                Text('Sex: ${data['sex'] ?? 'Not set'}'),
                Text('Height: ${data['height'] ?? 'Not set'} cm'),
                Text('Weight: ${data['weight'] ?? 'Not set'} kg'),
                Text('Body Type: ${data['bodyType'] ?? 'Not set'}'),
                Text('Activity Level: ${data['activityLevel'] ?? 'Not set'}'),
                const SizedBox(height: 10),
                Text('Diseases: ${(data['diseases'] as List?)?.join(', ') ?? 'None'}'),
                Text('Allergies: ${(data['allergies'] as List?)?.join(', ') ?? 'None'}'),
                const SizedBox(height: 10),
                Text('Diet Type: ${data['dietType'] ?? 'Not set'}'),
                Text('Health Goals: ${(data['healthGoals'] as List?)?.join(', ') ?? 'None'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  // =================================================================
  // WIDGET: MODERN BOTTOM NAV BAR (Transparent, Shorter, Rearranged)
  // =================================================================
  Widget _buildBottomNavBar() {
    final primaryColor = Theme.of(context).primaryColor;
    // Map pages to bottom bar icons
    final List<Map<String, dynamic>> barItems = [
      {'icon': Icons.home_rounded, 'label': 'Home', 'pageIndex': 0},
      {'icon': Icons.restaurant_menu_rounded, 'label': 'Diet', 'pageIndex': 3}, // Moved Diet (3)
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'Scan', 'pageIndex': 2}, // Center Scan (2)
      {'icon': Icons.self_improvement_rounded, 'label': 'Yoga', 'pageIndex': 1}, // Moved Yoga (1)
    ];

    return Container(
      // ✅ FIX: Decreased height to 65
      height: 65, 
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.symmetric(vertical: 5),
      // ✅ FIX: Background color is transparent
      decoration: const BoxDecoration(
        color: Colors.transparent, 
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(barItems.length, (index) {
            return _buildNavBarItem(
              barItems[index]['pageIndex'], // The index of the actual page
              barItems[index]['icon'] as IconData,
              barItems[index]['label'] as String,
              index, // The index of the item in the bar (0, 1, 2, 3)
              primaryColor,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int pageIndex, IconData icon, String label, int barIndex, Color primaryColor) {
    // Check if the current page index is the one represented by this bar item
    bool isSelected = _selectedIndex == pageIndex;
    
    return GestureDetector(
      // Use the bar index to trigger the correct page index update
      onTap: () => _onBottomBarTapped(barIndex), 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryColor : textLight.withOpacity(0.7), // Using Theme Color
            size: 28,
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isSelected ? 25 : 0, // Indicator bar at the bottom
            decoration: BoxDecoration(
              color: primaryColor, // Using Theme Color
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // FINAL BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    // Set the status bar color to match the background just below it
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: backgroundLight, // Match the color just below the status bar
      statusBarIconBrightness: Brightness.dark, // Adjust for light background
    ));
    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: backgroundLight,
      extendBodyBehindAppBar: true, 
      endDrawer: _buildDrawer(), 
      
      body: SafeArea(
        bottom: false, 
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _pages.elementAt(_selectedIndex), 
            ),
          ],
        ),
      ),
      // bottomNavigationBar needs to be outside of SafeArea for the floating effect
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}

// =================================================================
// WIDGET: HOME TAB CONTENT (Using Theme Primary Color)
// =================================================================
class _HomeContent extends StatelessWidget {
  final VoidCallback onStartProfileSetup;
  final VoidCallback onNavigateToScan;

  const _HomeContent({required this.onStartProfileSetup, required this.onNavigateToScan});

  // Helper for consistent Quick Action Cards (Neumorphic/Layered Look)
  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: shadowLight.withOpacity(0.8),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: InkWell( 
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: primaryColor, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textLight),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textLight.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }


  // WIDGET: THE FEATURE BANNER (Responsive Design)
  Widget _buildFeatureBanner(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing based on screen width
    final bannerHeight = screenHeight * 0.24;
    final horizontalMargin = screenWidth * 0.06;
    final contentPadding = screenWidth * 0.04;
    final titleFontSize = screenWidth * 0.032;
    final mainFontSize = screenWidth * 0.042;
    final buttonFontSize = screenWidth * 0.025;
    final buttonPadding = screenWidth * 0.03;
    final iconSize = screenWidth * 0.04;
    final spacingSmall = screenHeight * 0.008;
    final spacingMedium = screenHeight * 0.018;

    return Container(
      width: double.infinity,
      height: bannerHeight,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 25.0),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome to CuraScan',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w300,
                        color: cardWhite,
                      ),
                    ),
                    SizedBox(height: spacingSmall),
                    Flexible(
                      child: Text(
                        'Your Health,\nPersonalized.',
                        style: TextStyle(
                          fontSize: mainFontSize,
                          fontWeight: FontWeight.w800,
                          color: cardWhite,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: spacingMedium),
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: onStartProfileSetup,
                        icon: Icon(Icons.person_add_alt_1_outlined, color: textDark, size: iconSize),
                        label: Text(
                          'Personalize My Care',
                          style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.w700, color: textDark),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardWhite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(horizontal: buttonPadding, vertical: screenHeight * 0.012),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                child: Image.asset(
                  'assets/images/Doctor.png',
                  height: bannerHeight * 0.8,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomRight,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(Icons.error, color: cardWhite.withOpacity(0.5)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureBanner(context), // The main action banner
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  // Using textDark/primaryColor for headings based on style preference
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 15),
                // Quick Action Cards
                _buildQuickActionCard(
                  context,
                  icon: Icons.qr_code_scanner_rounded, 
                  title: 'Instant Food Scan', 
                  subtitle: 'Get immediate dietary insights for any item.', 
                  onTap: onNavigateToScan,
                ),
                _buildQuickActionCard(
                  context,
                  icon: Icons.restaurant_menu_rounded, 
                  title: 'Personalized Meal Plan', 
                  subtitle: 'View custom diet suggestions based on your profile.', 
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const MealPlanPage()),
                    );
                  },
                ),
                _buildQuickActionCard(
                  context,
                  icon: Icons.self_improvement_rounded, 
                  title: 'Daily Yoga Session', 
                  subtitle: 'Access guided practices for relaxation and health.', 
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const YogaSessionPage()),
                    );
                  },
                ),

              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}