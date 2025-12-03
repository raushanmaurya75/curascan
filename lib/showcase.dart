import 'package:flutter/material.dart';
import 'auth.dart'; // Navigate to AuthPage (file is `lib/auth.dart`)

// --- PREMIUM COLOR PALETTE ---
const Color primaryGreen = Color(0xFF00796B);      // Primary accent color
const Color primaryDark = Color(0xFF004D40);       // Darker shade for contrast
const Color primaryLight = Color(0xFF4DB6AC);      // Lighter gradient/highlight
const Color backgroundStart = Color(0xFFE0F7FA);   // Very light cyan/gray start
const Color backgroundEnd = Color(0xFFF0F4F7);     // Subtle, soft page background end
const Color cardWhite = Color(0xFFFFFFFF);         // Pure white for cards
const Color textDark = Color(0xFF212121);          // Deep black for headlines
const Color textLight = Color(0xFF757575);         // Subtle gray for body text
const Color shadowColor = Color(0xFFC5DDE8);       // Soft shadow color

// =================================================================
// 0. REUSABLE WIDGETS (Thematic Visual Container - Now Fixed Size)
// =================================================================

// --- Reusable Modern Visual Container (Fixed 200x200 size) ---
Widget _buildVisualContainer({required IconData icon}) {
  const double size = 200.0; // Fixed size for a cleaner look

  return Container(
    width: size, 
    height: size, 
    decoration: BoxDecoration(
      shape: BoxShape.circle, 
      gradient: const LinearGradient(
        colors: [primaryLight, primaryGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: primaryGreen.withOpacity(0.4),
          blurRadius: 25,
          offset: const Offset(0, 15),
        ),
      ],
    ),
    child: Icon(
      icon, 
      size: size * 0.5, // Icon size relative to container size (100.0)
      color: cardWhite,
    ),
  );
}

// =================================================================
// 1. THE MAIN CONTROLLER SCREEN (Handles Sliding, Dots, and Navigation)
// =================================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToAuth() {
    // Navigates to the AuthPage upon skipping or finishing the slides
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  void _onNext() {
    if (_currentPage < _numPages - 1) { 
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
    } else {
      _navigateToAuth(); // Last page action: Go to Auth
    }
  }
  
  // Widget for the dot indicators
  Widget _buildDotIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? primaryGreen : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Modern Gradient Background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundStart, backgroundEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // --- Page View Content ---
              Column(
                children: [
                  // --- Skip Button (Top Right Modern Placement) ---
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0, right: 20.0),
                      child: TextButton(
                        onPressed: _navigateToAuth,
                        child: Text(
                          'Skip',
                          style: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  
                  // --- Expanded PageView ---
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: const [
                        OnboardingPage1(),
                        OnboardingPage2(),
                        OnboardingPage3(),
                      ],
                    ),
                  ),

                  // --- Dot Indicators ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_numPages, (index) => _buildDotIndicator(index == _currentPage)),
                    ),
                  ),
                  const SizedBox(height: 70), // Space for the floating button
                ],
              ),
              
              // --- Floating Next/Get Started Button (Bottom Center) ---
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: cardWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                      elevation: 10,
                      shadowColor: primaryGreen.withOpacity(0.6),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: Text(
                      _currentPage == _numPages - 1 ? 'Get Started' : 'Next Step',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// 2. ONBOARDING PAGE WIDGETS (The Content Slides)
// =================================================================

// Helper function to process Markdown bold text (**) for RichText in Flutter
TextSpan _processText(String text, TextStyle baseStyle) {
  final List<TextSpan> children = [];
  final regex = RegExp(r'\*\*(.*?)\*\*');
  int lastMatchEnd = 0;

  for (final match in regex.allMatches(text)) {
    // Add text before the match (unbolded)
    if (match.start > lastMatchEnd) {
      children.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: baseStyle));
    }
    
    // Add text inside the match (bolded)
    children.add(
      TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.w800, color: primaryGreen), // Highlight bolded text
      ),
    );
    lastMatchEnd = match.end;
  }

  // Add any remaining text after the last match
  if (lastMatchEnd < text.length) {
    children.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
  }

  return TextSpan(children: children);
}


// --- Base Widget for Page Content ---
class OnboardingPageWrapper extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingPageWrapper({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Define the base style for the description
    final TextStyle baseStyle = TextStyle(
      fontSize: 16,
      color: textLight,
      height: 1.6,
      fontWeight: FontWeight.w500,
    );
    
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // --- Thematic Visual Container (Fixed Size) ---
              _buildVisualContainer(icon: icon),
              
              const Spacer(flex: 2),

              // --- Title (Used emoji in headings) ---
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900, 
                  color: primaryDark, 
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 15),

              // --- Description (Uses RichText for **bolding**) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: _processText(description, baseStyle),
                ),
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
        // Logo removed from showcase as requested (no Positioned widget)
      ],
    );
  }
}

// --- Slide 1: Profile Setup ---
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingPageWrapper(
      title: 'Personalized Health Identity 🆔',
      description: 'Start by securely uploading **prescriptions** or filling a quick form. We create a dedicated profile so our advice is always tailored specifically for you.',
      icon: Icons.assignment_ind_outlined,
    );
  }
}

// --- Slide 2: The Scanning Feature ---
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingPageWrapper(
      title: 'Instant Food Safety Scan 🍎',
      description: 'Scan any food item with your camera. CuraScan instantly checks ingredients against your profile to tell you if you **should eat it or avoid it.**',
      icon: Icons.camera_alt_outlined,
    );
  }
}

// --- Slide 3: The Holistic Wellness ---
class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingPageWrapper(
      title: 'Holistic Wellness Journey 🧘‍♀️',
      description: 'Access guided **Yoga practices** to boost recovery and discover curated lists of **curative foods** suggested for your quick and lasting health improvement.',
      icon: Icons.self_improvement_outlined,
    );
  }
}