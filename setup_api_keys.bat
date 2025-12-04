@echo off
echo ========================================
echo    CuraScan API Key Setup
echo ========================================
echo.
echo This script will help you securely configure your API keys.
echo.
echo IMPORTANT: Make sure you have regenerated your API keys after the exposure!
echo.
echo 1. Get your new Gemini API key from: https://aistudio.google.com/app/apikey
echo 2. Get your Firebase API key from your Firebase project console
echo.
set /p GEMINI_KEY="Enter your new Gemini API key: "
set /p FIREBASE_KEY="Enter your new Firebase API key: "
echo.
echo Creating secure .env file...
echo GEMINI_API_KEY=%GEMINI_KEY%> .env
echo FIREBASE_API_KEY=%FIREBASE_KEY%>> .env
echo.
echo ✅ API keys configured successfully!
echo.
echo Testing API connection...
flutter pub get
dart test_ai.dart
echo.
echo Setup complete! Your API keys are now securely stored in .env file.
echo The .env file is already in .gitignore to prevent accidental commits.
echo.
pause