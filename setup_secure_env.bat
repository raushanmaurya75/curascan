@echo off
echo Setting up secure environment for CuraScan...
echo.

REM Check if .env file exists
if not exist ".env" (
    echo Creating .env file from template...
    copy ".env.example" ".env"
    echo.
    echo ⚠️  IMPORTANT: Edit .env file and add your actual API keys
    echo.
) else (
    echo .env file already exists
)

REM Check if google-services.json exists
if not exist "android\app\google-services.json" (
    echo Creating google-services.json from template...
    copy "android\app\google-services.json.template" "android\app\google-services.json"
    echo.
    echo ⚠️  IMPORTANT: Edit google-services.json and add your actual Firebase API key
    echo.
) else (
    echo google-services.json already exists
)

echo.
echo 🔒 Security Setup Complete!
echo.
echo Next steps:
echo 1. Edit .env file with your actual API keys
echo 2. Edit android\app\google-services.json with your Firebase config
echo 3. Test your setup with: dart test_ai.dart
echo.
echo ⚠️  NEVER commit .env or google-services.json files to version control!
echo.
pause