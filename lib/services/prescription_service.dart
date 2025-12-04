import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PrescriptionService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get API key from environment variables
  static String get _apiKey {
    try {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (e) {
      return '';
    }
  }

  static bool get isApiKeyConfigured {
    final key = _apiKey;
    return key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE';
  }

  // Ensure dotenv is loaded before making API calls
  static Future<void> _ensureDotenvLoaded() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // .env file might not exist, that's okay
      }
    }
  }

  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }

  static Future<Map<String, dynamic>> parseTextToProfile(String extractedText) async {
    // Ensure dotenv is loaded before accessing API key
    await _ensureDotenvLoaded();

    if (!isApiKeyConfigured) {
      throw Exception('Gemini API key not configured. Please add your API key to the .env file.');
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = '''
Extract medical information from this prescription text and format as JSON:
"$extractedText"

Return ONLY valid JSON with these fields:
{
  "age": number or null,
  "sex": "Male" or "Female" or null,
  "diseases": ["disease1", "disease2"] or [],
  "allergies": ["allergy1", "allergy2"] or [],
  "medications": ["med1", "med2"] or [],
  "height": number or null,
  "weight": number or null
}

Extract only what's clearly mentioned. Use null for missing data.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null) {
        // Clean the response to extract JSON
        String jsonText = response.text!.trim();
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.substring(7);
        }
        if (jsonText.endsWith('```')) {
          jsonText = jsonText.substring(0, jsonText.length - 3);
        }
        
        // Parse JSON
        final Map<String, dynamic> parsedData = {};
        
        // Simple JSON parsing for the expected format
        final lines = jsonText.split('\n');
        for (String line in lines) {
          line = line.trim();
          if (line.contains(':')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              String key = parts[0].replaceAll('"', '').replaceAll(',', '').trim();
              String value = parts.sublist(1).join(':').replaceAll(',', '').trim();
              
              if (key == 'age' || key == 'height' || key == 'weight') {
                if (value != 'null') {
                  parsedData[key] = int.tryParse(value.replaceAll('"', ''));
                }
              } else if (key == 'sex') {
                if (value != 'null') {
                  parsedData[key] = value.replaceAll('"', '');
                }
              } else if (key == 'diseases' || key == 'allergies' || key == 'medications') {
                if (value.startsWith('[') && value.endsWith(']')) {
                  value = value.substring(1, value.length - 1);
                  if (value.isNotEmpty) {
                    parsedData[key] = value.split(',').map((e) => e.replaceAll('"', '').trim()).where((e) => e.isNotEmpty).toList();
                  } else {
                    parsedData[key] = <String>[];
                  }
                }
              }
            }
          }
        }
        
        return parsedData;
      }
      
      return {};
    } catch (e) {
      throw Exception('Failed to parse prescription: $e');
    }
  }

  static Future<void> saveParsedProfile(Map<String, dynamic> profileData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Add default values for required fields
      final completeProfile = {
        'age': profileData['age'],
        'sex': profileData['sex'],
        'height': profileData['height'],
        'weight': profileData['weight'],
        'bodyType': 'Average', // Default
        'activityLevel': 'Moderate', // Default
        'diseases': profileData['diseases'] ?? [],
        'allergies': profileData['allergies'] ?? [],
        'medications': profileData['medications'] ?? [],
        'dietType': 'Non-Vegetarian', // Default
        'healthGoals': ['General Health'], // Default
        'profileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'prescription',
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .set(completeProfile);
    } catch (e) {
      throw Exception('Failed to save profile: $e');
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}