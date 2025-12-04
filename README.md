# CuraScan

AI-powered food label scanner for personalized health recommendations.

## 🚀 Quick Setup

### 1. Environment Configuration

**⚠️ IMPORTANT: Set up API keys before running the app**

```bash
# Copy the environment template
cp .env.example .env

# Edit .env and add your actual API keys
# Get Gemini API key from: https://makersuite.google.com/app/apikey

# Copy Firebase configuration template
cp android/app/google-services.json.template android/app/google-services.json

# Add your actual Firebase configuration to google-services.json
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## 🔐 Security

- **Never commit `.env` file to version control**
- API keys are loaded from environment variables only
- See [SECURITY.md](SECURITY.md) for detailed security guidelines

## 📱 Features

- AI-powered food label scanning
- Personalized health recommendations
- User profile management
- Meal planning suggestions
