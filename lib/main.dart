import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'showcase.dart';
import 'home.dart';
import 'services/alarm_service.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation immediately (non-blocking)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Show app immediately with loading state, then initialize in background
  runApp(const CuraScanApp());
}

class CuraScanApp extends StatefulWidget {
  const CuraScanApp({super.key});

  @override
  State<CuraScanApp> createState() => _CuraScanAppState();
}

class _CuraScanAppState extends State<CuraScanApp> {
  bool _isInitialized = false;
  bool _initializationError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load environment variables and Firebase in parallel for faster startup
      await Future.wait([
        dotenv.load(fileName: ".env").catchError((_) {}), // Don't fail if .env missing
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      ]);

      // Initialize non-critical services in background (don't wait)
      _initializeBackgroundServices();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _initializationError = true;
          _isInitialized = true; // Still show UI to handle error
        });
      }
    }
  }

  void _initializeBackgroundServices() {
    // These run in background, don't block UI
    Future.microtask(() {
      MobileAds.instance.initialize();
      tz.initializeTimeZones();
      AlarmService.initialize();
      AnalyticsService.logAppOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CuraScan',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00796B),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        scaffoldBackgroundColor: const Color(0xFFF0F4F7),
      ),
      navigatorObservers: _isInitialized ? [AnalyticsService.observer] : [],
      home: _isInitialized ? const AuthWrapper() : const FastSplashScreen(),
    );
  }
}

// Lightweight splash screen that shows immediately while app initializes
class FastSplashScreen extends StatelessWidget {
  const FastSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFF0F4F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/curascan_transparent_croped.png',
                width: MediaQuery.of(context).size.width * 0.6,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.healing_outlined, size: 72, color: Color(0xFF00796B));
                },
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        // If user is logged in, go to home
        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User is authenticated: ${snapshot.data!.uid}');
          return const HomePage();
        }
        
        // If no user, show splash screen first
        print('ℹ️ No authenticated user, showing splash');
        return const SplashScreen();
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _dotsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    
    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animCtrl.forward();
      _dotsCtrl.repeat();
    });

    // Reduced splash time for faster startup (800ms is enough for branding)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFF0F4F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack)),
                        child: _buildLogoCard(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildLoadingHint(),
                  ],
                ),
              ),

              // BETA badge positioned near bottom center
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Center(child: _buildBetaBadge()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.8; // 80% of screen width for better visibility
    
    return SizedBox(
      width: logoSize,
      height: logoSize * 0.7,
      child: Image.asset(
        'assets/images/curascan_transparent_croped.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: logoSize,
            height: logoSize * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF00796B).withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: const Center(
              child: Icon(Icons.healing_outlined, size: 72, color: Color(0xFF00796B)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingHint() {
    // Animated three-dot pulse next to a small icon and label.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top, size: 18, color: Color(0xFF00796B)),
        const SizedBox(width: 10),
        const Text(
          'Loading',
          style: TextStyle(color: Color(0xFF00796B), fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        // Animated dots
        SizedBox(
          width: 48,
          height: 18,
          child: AnimatedBuilder(
            animation: _dotsCtrl,
            builder: (context, child) {
              // Build three dots with staggered opacity
              List<Widget> dots = List.generate(3, (i) {
                final double phase = (_dotsCtrl.value + (i * 0.18)) % 1.0;
                // Map phase (0..1) to opacity peak around 0.5
                double opacity = 0.2;
                if (phase < 0.5) {
                  opacity = 0.2 + (phase / 0.5) * 0.8; // 0.2 -> 1.0
                } else {
                  opacity = 0.2 + ((1 - phase) / 0.5) * 0.8; // 1.0 -> 0.2
                }
                return Opacity(
                  opacity: opacity.clamp(0.2, 1.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00796B),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              });

              return Row(mainAxisAlignment: MainAxisAlignment.center, children: dots);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBetaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        'BETA VERSION',
        style: TextStyle(
          color: Color(0xFF00796B),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 12,
        ),
      ),
    );
  }
}
