import 'package:flutter/material.dart';

// --- Color Palette ---
const Color primaryGreen = Color(0xFF00796B);
const Color primaryLight = Color(0xFF4DB6AC);
const Color backgroundLight = Color(0xFFF0F4F7);
const Color cardWhite = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF212121);
const Color textLight = Color(0xFF757575);

class YogaSessionPage extends StatelessWidget {
  const YogaSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('Yoga & Meditation'),
        backgroundColor: backgroundLight,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryGreen.withOpacity(0.1),
              backgroundLight,
              primaryLight.withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: cardWhite.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.self_improvement_rounded,
                        size: 100,
                        color: primaryGreen.withOpacity(0.8),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Yoga & Meditation',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Guided yoga sessions and meditation practices tailored to your wellness journey.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: textLight,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: primaryLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryLight.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Get notified when available',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}