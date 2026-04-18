import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'user_profile_service.dart';
import 'remote_config_service.dart';

class ChatbotService {
  static String _cachedGroqKey = '';
  
  // Groq API Key (Llama 3.1 8B Instant)
  static Future<String> get groqApiKey async {
    if (_cachedGroqKey.isNotEmpty) return _cachedGroqKey;
    
    try {
      final envKey = dotenv.env['GROQ_API_KEY'];
      if (envKey != null && envKey.isNotEmpty && envKey != 'YOUR_GROQ_API_KEY_HERE') {
        _cachedGroqKey = envKey;
        return envKey;
      }
    } catch (e) {}
    
    final remoteKey = await RemoteConfigService.getGroqApiKey();
    if (remoteKey.isNotEmpty) {
      _cachedGroqKey = remoteKey;
      return remoteKey;
    }
    
    return '';
  }
  
  static Future<void> _ensureDotenvLoaded() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {}
    }
  }
  
  // Main chat method - handles diagnostic and health queries
  static Future<Map<String, dynamic>> sendMessage({
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    Map<String, dynamic>? userProfile,
    String? imageBase64, // For image-based diagnosis
  }) async {
    await _ensureDotenvLoaded();
    
    final groqKey = await groqApiKey;
    
    if (groqKey.isEmpty) {
      return {
        'response': 'I apologize, but the AI service is currently unavailable. Please check your API configuration or try again later.',
        'confidence': 0,
        'suggestions': [],
        'error': 'API key not configured',
      };
    }
    
    // Get user profile if not provided
    final profile = userProfile ?? await UserProfileService.getUserProfile();
    
    // Build the diagnostic prompt
    final prompt = _buildDiagnosticPrompt(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
      userProfile: profile,
      imageBase64: imageBase64,
    );
    
    try {
      print('🌐 Calling Groq API for health assistant...');
      final result = await _callGroqAPI(prompt, groqKey).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Groq timeout'),
      );
      print('✅ Health assistant response received!');
      return result;
    } catch (e) {
      print('❌ Health assistant error: $e');
      return {
        'response': 'I apologize, but I encountered an error processing your request. Please try again.',
        'confidence': 0,
        'suggestions': ['Retry your question', 'Try a simpler query'],
        'error': e.toString(),
      };
    }
  }
  
  static Future<Map<String, dynamic>> _callGroqAPI(String prompt, String apiKey) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: json.encode({
        'model': 'llama-3.1-8b-instant',
        'messages': [
          {
            'role': 'system',
            'content': '''You are "Swasthya", an AI Health Assistant designed for rural healthcare workers and patients in India. 

YOUR CAPABILITIES:
1. Help diagnose common symptoms by asking clarifying questions
2. Analyze skin conditions, rashes, or visible symptoms from images (when provided)
3. Provide personalized health advice based on patient history and profile
4. Suggest when to seek immediate medical attention
5. Offer preventive care recommendations
6. Explain medical terms in simple, local language

IMPORTANT GUIDELINES:
- ALWAYS respond in English only - do not use Hindi or any other language
- Always provide confidence levels (0-100%) for any assessment
- Be culturally sensitive and consider rural healthcare context
- If symptoms suggest emergency, clearly state this with red warning
- Never replace professional medical advice - always recommend consulting a doctor for serious concerns
- Consider the user's medical conditions, allergies, and health goals in your responses
- Provide actionable next steps: "Monitor at home", "Visit PHC", "Seek emergency care", etc.
- Use simple, clear English language - avoid medical jargon unless explained

RESPONSE FORMAT (JSON):
{
  "response": "Your helpful, empathetic response here",
  "confidence": 75,
  "assessment": "Brief diagnosis/assessment summary",
  "suggestions": ["Actionable recommendation 1", "Actionable recommendation 2"],
  "urgency": "low|medium|high|emergency",
  "nextSteps": "What the user should do next",
  "followUpQuestions": ["Question 1 to gather more info", "Question 2"]
}'''
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.5,
        'max_tokens': 1500,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final aiResponse = data['choices']?[0]?['message']?['content'] ?? '';
      return _parseAIResponse(aiResponse);
    }
    throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
  }
  
  static String _buildDiagnosticPrompt({
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    required Map<String, dynamic> userProfile,
    String? imageBase64,
  }) {
    // Format conversation history
    String historyText = '';
    for (var i = 0; i < conversationHistory.length && i < 6; i++) {
      final msg = conversationHistory[i];
      final role = msg['isUser'] == true ? 'User' : 'Swasthya';
      historyText += '$role: ${msg['text']}\n';
    }
    
    // Format user profile
    final conditions = (userProfile['conditions'] as List?)?.join(', ') ?? 'None';
    final allergies = (userProfile['allergies'] as List?)?.join(', ') ?? 'None';
    final age = userProfile['age'] ?? 'Not specified';
    final healthGoals = (userProfile['healthGoals'] as List?)?.join(', ') ?? 'General health';
    
    String imageText = '';
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      imageText = '''

[IMAGE ATTACHED]: The user has shared an image for analysis. Please examine it carefully for any visible symptoms, skin conditions, rashes, or abnormalities.''';
    }
    
    return '''
USER HEALTH PROFILE:
- Age: $age
- Medical Conditions: $conditions
- Allergies: $allergies
- Health Goals: $healthGoals

CONVERSATION HISTORY:
$historyText

CURRENT QUERY:$imageText
$userMessage

Please analyze the user's query considering their health profile. Provide a helpful response in simple English for a rural Indian healthcare context.

Respond ONLY with the JSON format specified in your system instructions.''';  }
  
  static Map<String, dynamic> _parseAIResponse(String aiResponse) {
    try {
      // Try to extract JSON from the response
      final jsonStart = aiResponse.indexOf('{');
      final jsonEnd = aiResponse.lastIndexOf('}') + 1;
      
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = aiResponse.substring(jsonStart, jsonEnd);
        final parsed = json.decode(jsonString);
        
        // Ensure all required fields exist
        return {
          'response': parsed['response'] ?? aiResponse,
          'confidence': parsed['confidence'] ?? 70,
          'assessment': parsed['assessment'] ?? '',
          'suggestions': List<String>.from(parsed['suggestions'] ?? []),
          'urgency': parsed['urgency'] ?? 'low',
          'nextSteps': parsed['nextSteps'] ?? '',
          'followUpQuestions': List<String>.from(parsed['followUpQuestions'] ?? []),
        };
      }
      
      // Fallback if JSON parsing fails
      return {
        'response': aiResponse,
        'confidence': 50,
        'assessment': '',
        'suggestions': [],
        'urgency': 'low',
        'nextSteps': 'Please consult with a healthcare provider for personalized advice.',
        'followUpQuestions': [],
      };
    } catch (e) {
      print('Error parsing AI response: $e');
      return {
        'response': aiResponse,
        'confidence': 50,
        'assessment': '',
        'suggestions': [],
        'urgency': 'low',
        'nextSteps': 'Please consult with a healthcare provider for personalized advice.',
        'followUpQuestions': [],
        'error': 'Parsing error: $e',
      };
    }
  }
  
  // Quick symptom checker for common conditions
  static Future<Map<String, dynamic>> checkSymptoms({
    required List<String> symptoms,
    required Map<String, dynamic> userProfile,
  }) async {
    final symptomsText = symptoms.join(', ');
    final message = 'I am experiencing the following symptoms: $symptomsText. What could this be?';
    
    return sendMessage(
      userMessage: message,
      conversationHistory: [],
      userProfile: userProfile,
    );
  }
  
  // Offline fallback responses for common queries
  static Map<String, dynamic> getOfflineResponse(String query) {
    final queryLower = query.toLowerCase();
    
    // Emergency keywords
    if (queryLower.contains('chest pain') || 
        queryLower.contains('heart attack') ||
        queryLower.contains('can\'t breathe') ||
        queryLower.contains('unconscious') ||
        queryLower.contains('severe bleeding')) {
      return {
        'response': '🚨 EMERGENCY: Please seek immediate medical attention! Call 108 or go to the nearest hospital right away. This could be life-threatening.',
        'confidence': 95,
        'assessment': 'Potential emergency condition',
        'suggestions': ['Call emergency services immediately', 'Do not wait or self-medicate'],
        'urgency': 'emergency',
        'nextSteps': 'Go to nearest hospital or call 108 immediately',
        'followUpQuestions': [],
      };
    }
    
    // Common cold/flu symptoms
    if (queryLower.contains('fever') && queryLower.contains('cold')) {
      return {
        'response': 'Your symptoms suggest a common cold or viral fever. Rest, drink plenty of fluids, and monitor your temperature.',
        'confidence': 75,
        'assessment': 'Likely viral infection',
        'suggestions': ['Rest and hydrate', 'Take paracetamol for fever', 'Steam inhalation'],
        'urgency': 'low',
        'nextSteps': 'Monitor for 2-3 days. Visit doctor if fever persists beyond 3 days or exceeds 102°F.',
        'followUpQuestions': ['How long have you had these symptoms?', 'Do you have any body ache?'],
      };
    }
    
    // Default response
    return {
      'response': 'I apologize, but I\'m currently offline. Please try again when you have an internet connection, or consult with a healthcare provider for immediate concerns.',
      'confidence': 0,
      'assessment': '',
      'suggestions': ['Try again with internet connection', 'Visit nearest health center'],
      'urgency': 'low',
      'nextSteps': 'Reconnect to internet or visit health center',
      'followUpQuestions': [],
    };
  }
}
