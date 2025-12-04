import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/services/ai_service.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  print('Testing AI Service...');
  print('API Key configured: ${AIService.isApiKeyConfigured}');
  
  if (!AIService.isApiKeyConfigured) {
    print('❌ API key not configured properly');
    exit(1);
  }
  
  try {
    // Test food analysis
    final result = await AIService.analyzeFoodForUser(
      extractedText: "Coca Cola - Contains sugar, caffeine, artificial flavors",
      userProfile: {
        'age': 25,
        'conditions': ['diabetes'],
        'allergies': [],
        'dietaryRestrictions': [],
        'healthGoals': ['weight loss']
      }
    );
    
    print('✅ AI Service working correctly!');
    print('Recommendation: ${result['recommendation']}');
    print('Title: ${result['title']}');
    
  } catch (e) {
    print('❌ AI Service error: $e');
    exit(1);
  }
}