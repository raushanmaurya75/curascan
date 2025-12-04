import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String baseUrl = "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent";
  
  static bool get isApiKeyConfigured => apiKey.isNotEmpty && apiKey != 'YOUR_NEW_API_KEY_HERE';

  static Future<Map<String, dynamic>> analyzeFoodForUser({
    required String extractedText,
    required Map<String, dynamic> userProfile,
  }) async {
    if (!isApiKeyConfigured) {
      throw Exception('Gemini API key not configured. Please add your API key to the .env file.');
    }
    
    try {
      final prompt = _buildPrompt(extractedText, userProfile);
      
      final response = await http.post(
        Uri.parse("$baseUrl?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "No response received";
        
        return _parseAIResponse(aiResponse);
      } else if (response.statusCode == 403) {
        throw Exception('API key is restricted or invalid. Please check your Gemini API key configuration.');
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('AI analysis failed: $e');
    }
  }

  static String _buildPrompt(String extractedText, Map<String, dynamic> userProfile) {
    return """
Analyze this food product for a user with the following health profile:

USER PROFILE:
- Age: ${userProfile['age'] ?? 'Not specified'}
- Medical Conditions: ${userProfile['conditions']?.join(', ') ?? 'None specified'}
- Allergies: ${userProfile['allergies']?.join(', ') ?? 'None specified'}
- Dietary Restrictions: ${userProfile['dietaryRestrictions']?.join(', ') ?? 'None specified'}
- Health Goals: ${userProfile['healthGoals']?.join(', ') ?? 'None specified'}

FOOD PRODUCT INFORMATION:
$extractedText

Please provide a JSON response with the following structure:
{
  "recommendation": "SAFE" or "CAUTION" or "AVOID",
  "title": "Brief recommendation title",
  "summary": "One sentence summary of your recommendation",
  "reasons": ["List of specific reasons for this recommendation"],
  "nutritionalHighlights": ["Key nutritional points to note"],
  "alternatives": ["Suggested alternatives if not recommended"],
  "healthImpact": "Brief explanation of how this affects their health goals"
}

Focus on their specific medical conditions, allergies, and health goals. Be specific and actionable.
""";
  }

  static Map<String, dynamic> _parseAIResponse(String aiResponse) {
    try {
      // Try to extract JSON from the response
      final jsonStart = aiResponse.indexOf('{');
      final jsonEnd = aiResponse.lastIndexOf('}') + 1;
      
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = aiResponse.substring(jsonStart, jsonEnd);
        return json.decode(jsonString);
      }
      
      // Fallback if JSON parsing fails
      return {
        "recommendation": "CAUTION",
        "title": "Analysis Complete",
        "summary": "Please review the detailed analysis below.",
        "reasons": ["AI analysis completed"],
        "nutritionalHighlights": ["Check product details carefully"],
        "alternatives": ["Consult with healthcare provider"],
        "healthImpact": aiResponse.length > 200 ? aiResponse.substring(0, 200) + "..." : aiResponse
      };
    } catch (e) {
      return {
        "recommendation": "CAUTION",
        "title": "Analysis Error",
        "summary": "Unable to parse AI response properly.",
        "reasons": ["Technical error occurred"],
        "nutritionalHighlights": ["Manual review recommended"],
        "alternatives": ["Consult healthcare provider"],
        "healthImpact": "Please review product manually"
      };
    }
  }

  static Future<Map<String, dynamic>> generateMealPlan(Map<String, dynamic> userProfile) async {
    if (!isApiKeyConfigured) {
      throw Exception('Gemini API key not configured. Please add your API key to the .env file.');
    }
    
    try {
      final prompt = _buildMealPlanPrompt(userProfile);
      
      final response = await http.post(
        Uri.parse("$baseUrl?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "No response received";
        
        return _parseMealPlanResponse(aiResponse);
      } else if (response.statusCode == 403) {
        throw Exception('API key is restricted or invalid. Please check your Gemini API key configuration.');
      } else {
        throw Exception('Failed to get meal plan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      return _getDefaultMealPlan();
    }
  }

  static String _buildMealPlanPrompt(Map<String, dynamic> userProfile) {
    return """
Create a personalized daily meal plan for a user with the following profile:

USER PROFILE:
- Age: ${userProfile['age'] ?? 'Not specified'}
- Sex: ${userProfile['sex'] ?? 'Not specified'}
- Weight: ${userProfile['weight'] ?? 'Not specified'} kg
- Height: ${userProfile['height'] ?? 'Not specified'} cm
- Activity Level: ${userProfile['activityLevel'] ?? 'Not specified'}
- Medical Conditions: ${userProfile['diseases']?.join(', ') ?? 'None'}
- Food Allergies: ${userProfile['allergies']?.join(', ') ?? 'None'}
- Diet Type: ${userProfile['dietType'] ?? 'Not specified'}
- Health Goals: ${userProfile['healthGoals']?.join(', ') ?? 'General health'}

Please provide a JSON response with this structure:
{
  "breakfast": {
    "items": ["List of breakfast items"],
    "calories": estimated_calories
  },
  "lunch": {
    "items": ["List of lunch items"],
    "calories": estimated_calories
  },
  "dinner": {
    "items": ["List of dinner items"],
    "calories": estimated_calories
  },
  "snacks": {
    "items": ["List of healthy snacks"],
    "calories": estimated_calories
  }
}

Consider their medical conditions, allergies, diet type, and health goals. Make it practical and achievable.
""";
  }

  static Map<String, dynamic> _parseMealPlanResponse(String aiResponse) {
    try {
      final jsonStart = aiResponse.indexOf('{');
      final jsonEnd = aiResponse.lastIndexOf('}') + 1;
      
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = aiResponse.substring(jsonStart, jsonEnd);
        return json.decode(jsonString);
      }
      
      return _getDefaultMealPlan();
    } catch (e) {
      return _getDefaultMealPlan();
    }
  }

  static Map<String, dynamic> _getDefaultMealPlan() {
    return {
      "breakfast": {
        "items": ["Oatmeal with fruits", "Green tea", "Nuts and seeds"],
        "calories": 350
      },
      "lunch": {
        "items": ["Grilled chicken salad", "Brown rice", "Steamed vegetables"],
        "calories": 450
      },
      "dinner": {
        "items": ["Baked fish", "Quinoa", "Mixed vegetables", "Herbal tea"],
        "calories": 400
      },
      "snacks": {
        "items": ["Fresh fruits", "Greek yogurt", "Handful of almonds"],
        "calories": 200
      }
    };
  }
}