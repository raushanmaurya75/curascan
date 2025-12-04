import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'remote_config_service.dart';

class AIService {
  static String _cachedApiKey = '';
  
  static Future<String> get apiKey async {
    // Try cached key first
    if (_cachedApiKey.isNotEmpty) {
      return _cachedApiKey;
    }
    
    // Try environment variables first (for local development)
    try {
      final envKey = dotenv.env['GEMINI_API_KEY'];
      if (envKey != null && envKey.isNotEmpty && envKey != 'YOUR_GEMINI_API_KEY_HERE') {
        _cachedApiKey = envKey;
        print('🔑 API Key loaded from environment');
        return envKey;
      }
    } catch (e) {
      print('⚠️ Environment file not loaded');
    }
    
    // Try Firebase Remote Config (for production)
    final remoteKey = await RemoteConfigService.getGeminiApiKey();
    if (remoteKey.isNotEmpty) {
      _cachedApiKey = remoteKey;
      return remoteKey;
    }
    
    print('❌ No API key found in any source');
    return '';
  }

  static const String baseUrl = "https://generativelanguage.googleapis.com/v1beta/models";
  static String _selectedModel = "gemini-2.5-flash";
  
  static String get generateUrl => "https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent";

  static Future<bool> get isApiKeyConfigured async {
    final key = await apiKey;
    return key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE';
  }

  static Future<void> _selectBestModel() async {
    try {
      final key = await apiKey;
      final response = await http.get(
        Uri.parse("$baseUrl?key=$key"),
        headers: {"Content-Type": "application/json"},
      );
      
      print('🌐 Model list API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List;
        
        print('📋 Available models for your API key:');
        for (final model in models) {
          final name = model['name'] as String;
          final methods = model['supportedGenerationMethods'] as List?;
          print('  - $name (methods: ${methods?.join(", ") ?? "none"})');
        }
        
        // Priority order for model selection (use working models)
        final preferredModels = [
          'gemini-2.5-flash',
          'gemini-flash-latest',
          'gemini-pro-latest', 
          'gemini-2.0-flash',
        ];
        
        // Find preferred model that supports generateContent
        for (final preferred in preferredModels) {
          final fullModelName = 'models/$preferred';
          final model = models.firstWhere(
            (m) => m['name'] == fullModelName,
            orElse: () => null,
          );
          
          if (model != null) {
            final supportedMethods = model['supportedGenerationMethods'] as List?;
            if (supportedMethods?.contains('generateContent') == true) {
              print('✅ Using preferred model: $preferred');
              _selectedModel = preferred;
              return;
            }
          }
        }
        
        // Fallback: find any model that supports generateContent
        for (final model in models) {
          final supportedMethods = model['supportedGenerationMethods'] as List?;
          if (supportedMethods?.contains('generateContent') == true) {
            final fullModelName = model['name'] as String;
            final modelName = fullModelName.replaceFirst('models/', '');
            print('✅ Using fallback model: $modelName');
            _selectedModel = modelName;
            return;
          }
        }
      } else {
        print('❌ Failed to get models: ${response.statusCode} - ${response.body}');
      }
      
      print('⚠️ Using default model: gemini-2.5-flash');
      _selectedModel = 'gemini-2.5-flash';
    } catch (e) {
      print('💥 Error getting models: $e');
      _selectedModel = 'gemini-2.5-flash';
    }
  }

  static Future<void> _ensureDotenvLoaded() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
        print('✅ Environment loaded');
      } catch (e) {
        print('⚠️ .env file not found');
        return;
      }
    }
    
    final currentApiKey = await apiKey;
    if (currentApiKey.isNotEmpty) {
      print('🔑 API Key configured: true');
      // Always get available models first
      await _selectBestModel();
    } else {
      print('⚠️ API Key not configured');
    }
  }

  static Future<Map<String, dynamic>> analyzeFoodForUser({
    required String extractedText,
    required Map<String, dynamic> userProfile,
  }) async {
    // Ensure dotenv is loaded before accessing API key
    await _ensureDotenvLoaded();

    // Check API key after loading environment
    final currentApiKey = await apiKey;
    if (currentApiKey.isEmpty) {
      return {
        "recommendation": "CAUTION",
        "title": "AI Analysis Unavailable",
        "summary": "AI analysis requires API key configuration.",
        "reasons": ["API key not configured", "Please set up .env file with GEMINI_API_KEY"],
        "nutritionalHighlights": ["Manual review required"],
        "alternatives": ["Review ingredients manually", "Consult healthcare provider"],
        "healthImpact": "Please review the product label manually and consult with a healthcare provider if needed."
      };
    }
    
    try {
      final prompt = _buildPrompt(extractedText, userProfile);
      final url = "$generateUrl?key=$currentApiKey";
      print('🌐 Making API request to Gemini API');
      print('📝 Request payload size: ${prompt.length} characters');
      
      final response = await http.post(
        Uri.parse(url),
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
      
      print('📡 Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('❌ Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "No response received";
        
        return _parseAIResponse(aiResponse);
      } else if (response.statusCode == 403) {
        return {
          "recommendation": "CAUTION",
          "title": "API Key Issue",
          "summary": "API key is restricted or invalid.",
          "reasons": ["API key configuration issue", "Please check your API key setup"],
          "nutritionalHighlights": ["Manual review required"],
          "alternatives": ["Review ingredients manually", "Consult healthcare provider"],
          "healthImpact": "Please review the product label manually."
        };
      } else {
        print('❌ API Error ${response.statusCode}: ${response.body}');
        return {
          "recommendation": "CAUTION",
          "title": "Service Unavailable (${response.statusCode})",
          "summary": "AI analysis service returned error ${response.statusCode}.",
          "reasons": ["API Error: ${response.statusCode}", "Response: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}"],
          "nutritionalHighlights": ["Manual review recommended"],
          "alternatives": ["Review ingredients manually", "Consult healthcare provider"],
          "healthImpact": "Please review the product label manually."
        };
      }
    } catch (e) {
      print('💥 Exception in AI analysis: $e');
      return {
        "recommendation": "CAUTION",
        "title": "Analysis Error",
        "summary": "Unable to complete AI analysis: ${e.toString()}",
        "reasons": ["Technical error: ${e.toString()}", "Please try again later"],
        "nutritionalHighlights": ["Manual review recommended"],
        "alternatives": ["Review ingredients manually", "Consult healthcare provider"],
        "healthImpact": "Please review the product label manually and consult with a healthcare provider if needed."
      };
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
    // Ensure dotenv is loaded before accessing API key
    await _ensureDotenvLoaded();

    final key = await apiKey;
    if (key.isEmpty) {
      return _getDefaultMealPlan();
    }

    try {
      final prompt = _buildMealPlanPrompt(userProfile);
      
      final response = await http.post(
        Uri.parse("$generateUrl?key=$key"),
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