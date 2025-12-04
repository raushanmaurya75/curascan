# API Setup Instructions

## 🚨 SECURITY ALERT: API Keys Were Exposed

❌ **Previous Status**: API keys were publicly exposed
✅ **Current Status**: API keys secured with environment variables
🔄 **Action Required**: You must regenerate all API keys immediately

### Current Setup

### 🚨 IMMEDIATE ACTION REQUIRED

**Your API keys were exposed in your code repository. You must:**
1. **Immediately revoke the exposed keys**:
   - Gemini API Key: `AIzaSyBzn0kkuE1kUWBhNjAIa9kCfKQtxALTqwo`
   - Firebase API Key: `AIzaSyB0kolT-I5-pM8U4BcPencDIJE6wLibUdk`
2. **Generate new keys following the steps below**
3. **Monitor your accounts for unauthorized usage**

### Step 1: Get a New API Key
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the new API key

### Step 2: Configure API Key Restrictions
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Find your API key and click on it
3. Under "API restrictions", select "Restrict key"
4. Choose "Generative Language API"
5. Under "Application restrictions", choose "HTTP referrers (web sites)" or "IP addresses" for better security
6. Save the restrictions

### Step 3: Add API Key to Your App
1. Open the `.env` file in your project root
2. Replace `YOUR_NEW_API_KEY_HERE` with your actual API key:
   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```
3. Save the file

### Step 4: Test the API
1. Run your Flutter app
2. Try scanning a food label
3. The AI analysis should now work properly

## Security Notes
- Never commit your actual API key to version control
- The `.env` file is already in `.gitignore` to prevent accidental commits
- Always restrict your API keys in Google Cloud Console
- Monitor your API usage regularly

## Troubleshooting
- If you get a 403 error, check that your API key is correctly configured and not restricted
- If you get a 400 error, check that the Generative Language API is enabled in your Google Cloud project
- Make sure your API key has the necessary permissions for the Generative Language API