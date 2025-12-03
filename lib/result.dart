import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

// Color Palette (matching yoga theme)
const Color primaryGreen = Color(0xFF00796B);
const Color primaryLight = Color(0xFF4DB6AC);
const Color backgroundLight = Color(0xFFF0F4F7);
const Color cardWhite = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF212121);
const Color textLight = Color(0xFF757575);
const Color safeGreen = Color(0xFF4CAF50);
const Color cautionOrange = Color(0xFFFF9800);
const Color avoidRed = Color(0xFFF44336);

class FoodAnalysisResultPage extends StatefulWidget {
  final File? scannedImage;
  final String extractedText;
  final Map<String, dynamic> analysisResult;

  const FoodAnalysisResultPage({
    super.key,
    this.scannedImage,
    required this.extractedText,
    required this.analysisResult,
  });

  @override
  State<FoodAnalysisResultPage> createState() => _FoodAnalysisResultPageState();
}

class _FoodAnalysisResultPageState extends State<FoodAnalysisResultPage> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5335259902955088/8648223730',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load banner ad: ${err.message}');
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Color _getRecommendationColor() {
    switch (widget.analysisResult['recommendation']?.toString().toUpperCase()) {
      case 'SAFE':
        return safeGreen;
      case 'CAUTION':
        return cautionOrange;
      case 'AVOID':
        return avoidRed;
      default:
        return cautionOrange;
    }
  }

  IconData _getRecommendationIcon() {
    switch (widget.analysisResult['recommendation']?.toString().toUpperCase()) {
      case 'SAFE':
        return Icons.check_circle_rounded;
      case 'CAUTION':
        return Icons.warning_rounded;
      case 'AVOID':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getRecommendationEmoji() {
    switch (widget.analysisResult['recommendation']?.toString().toUpperCase()) {
      case 'SAFE':
        return '✅';
      case 'CAUTION':
        return '⚠️';
      case 'AVOID':
        return '❌';
      default:
        return '🤔';
    }
  }

  String _getSimplifiedSummary() {
    final recommendation = widget.analysisResult['recommendation']?.toString().toUpperCase();
    switch (recommendation) {
      case 'SAFE':
        return 'This food is good for you! Feel free to enjoy it as part of your healthy diet.';
      case 'CAUTION':
        return 'This food is okay in moderation. Consider your health goals when consuming.';
      case 'AVOID':
        return 'This food may not be the best choice for your health profile. Consider alternatives.';
      default:
        return 'We\'ve analyzed this food item for you. Check the details below for more information.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendationColor = _getRecommendationColor();
    
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('Food Analysis Result'),
        backgroundColor: backgroundLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              recommendationColor.withOpacity(0.1),
              backgroundLight,
              primaryLight.withOpacity(0.2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Main Result Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardWhite.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: recommendationColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Recommendation Icon & Status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: recommendationColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getRecommendationIcon(),
                        size: 60,
                        color: recommendationColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      '${_getRecommendationEmoji()} ${widget.analysisResult['title'] ?? 'Analysis Complete'}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: recommendationColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.analysisResult['recommendation']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: const TextStyle(
                          color: cardWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      _getSimplifiedSummary(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: textLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: primaryGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, color: primaryGreen, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Personalized for you',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Banner Ad
              if (_isBannerAdReady)
                Container(
                  width: double.infinity,
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryLight.withOpacity(0.3)),
                  ),
                  child: AdWidget(ad: _bannerAd!),
                ),
              
              // Scanned Image (if available)
              if (widget.scannedImage != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      widget.scannedImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              // Key Points (simplified)
              if (widget.analysisResult['reasons'] != null && (widget.analysisResult['reasons'] as List).isNotEmpty)
                _buildSimpleInfoCard(
                  title: 'Key Points',
                  icon: Icons.info_outline,
                  items: _getSimplifiedReasons(),
                  color: recommendationColor,
                ),
              
              // Quick Tips
              if (widget.analysisResult['alternatives'] != null && (widget.analysisResult['alternatives'] as List).isNotEmpty)
                _buildSimpleInfoCard(
                  title: 'Better Choices',
                  icon: Icons.lightbulb_outline,
                  items: _getSimplifiedAlternatives(),
                  color: safeGreen,
                ),
              
              const SizedBox(height: 20),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Scan Another Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: cardWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  List<String> _getSimplifiedReasons() {
    final reasons = widget.analysisResult['reasons'] as List?;
    if (reasons == null || reasons.isEmpty) return [];
    
    // Take only the first 2-3 most important reasons and simplify them
    return reasons.take(3).map((reason) {
      String simplified = reason.toString();
      // Remove technical jargon and make it more user-friendly
      simplified = simplified.replaceAll(RegExp(r'\b(contains|has|includes)\b', caseSensitive: false), 'Has');
      simplified = simplified.replaceAll(RegExp(r'\b(due to|because of)\b', caseSensitive: false), 'because');
      return simplified; // Remove length truncation
    }).toList();
  }
  
  List<String> _getSimplifiedAlternatives() {
    final alternatives = widget.analysisResult['alternatives'] as List?;
    if (alternatives == null || alternatives.isEmpty) return [];
    
    // Take only the first 3 alternatives
    return alternatives.take(3).map((alt) => alt.toString()).toList();
  }
  
  Widget _buildSimpleInfoCard({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color color,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite.withOpacity(0.9),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: textDark,
                      height: 1.5,
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
}