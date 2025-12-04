@echo off
echo ========================================
echo    CuraScan Security Verification
echo ========================================
echo.
echo Checking for potential security issues...
echo.

echo 1. Checking for hardcoded API keys...
findstr /R /C:"AIzaSy" lib\*.dart > nul
if %errorlevel% equ 0 (
    echo ❌ SECURITY ISSUE: Hardcoded API keys found in source code!
    findstr /R /C:"AIzaSy" lib\*.dart
) else (
    echo ✅ No hardcoded API keys found in source code
)

echo.
echo 2. Checking .env file protection...
findstr /C:".env" .gitignore > nul
if %errorlevel% equ 0 (
    echo ✅ .env file is protected by .gitignore
) else (
    echo ❌ WARNING: .env file not in .gitignore!
)

echo.
echo 3. Checking .env file content...
if exist .env (
    findstr /C:"YOUR_NEW_" .env > nul
    if %errorlevel% equ 0 (
        echo ⚠️  .env file contains placeholder values - you need to add your actual API keys
    ) else (
        echo ✅ .env file appears to be configured
    )
) else (
    echo ❌ .env file not found!
)

echo.
echo 4. Checking Firebase configuration...
findstr /C:"String.fromEnvironment" lib\firebase_options.dart > nul
if %errorlevel% equ 0 (
    echo ✅ Firebase options using environment variables
) else (
    echo ❌ Firebase options may have hardcoded keys
)

echo.
echo 5. Checking AI service configuration...
findstr /C:"dotenv.env" lib\services\ai_service.dart > nul
if %errorlevel% equ 0 (
    echo ✅ AI service using environment variables
) else (
    echo ❌ AI service may have hardcoded keys
)

echo.
echo ========================================
echo Security verification complete!
echo ========================================
echo.
echo If you see any ❌ or ⚠️ above, please address those issues.
echo.
pause