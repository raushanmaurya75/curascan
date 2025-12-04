# Security Setup Guide

## 🔒 API Key Security Configuration

### Critical Security Issues Fixed:
- ✅ Removed exposed Gemini API key from .env
- ✅ Secured Firebase API key using environment variables
- ✅ Removed duplicate google-services.json from assets
- ✅ Updated .gitignore to prevent future exposures

### Required Setup Steps:

#### 1. Configure Your API Keys
Add your actual API keys to the `.env` file (this file is NOT committed to git):

```env
GEMINI_API_KEY=your_actual_gemini_api_key_here
FIREBASE_API_KEY=your_actual_firebase_api_key_here
```

#### 2. Get New API Keys (IMPORTANT)
Since your keys were exposed, you should:

**For Gemini API:**
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Delete any old exposed keys
3. Create a new API key
4. Add restrictions (IP addresses, HTTP referrers)

**For Firebase API:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to Project Settings > General
3. Regenerate your API keys
4. Update your google-services.json file

#### 3. Security Best Practices
- Never commit `.env` files to version control
- Always use environment variables for sensitive data
- Regularly rotate your API keys
- Monitor API usage for suspicious activity
- Set up API key restrictions in Google Cloud Console

#### 4. Files That Should NEVER Be Committed:
- `.env` (contains actual API keys)
- `google-services.json` (contains Firebase config)
- Any file with actual API keys or credentials

### Testing Your Setup
Run the test file to verify everything works:
```bash
dart test_ai.dart
```

## 🚨 Emergency Response
If you suspect your API keys are compromised:
1. Immediately revoke the exposed keys
2. Generate new keys
3. Update your application
4. Monitor for unauthorized usage
5. Consider implementing additional security measures