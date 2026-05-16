@echo off
echo ============================================
echo    SOS Help Listener - Build APK
echo ============================================
echo.

echo Building release APK...
flutter build apk --release

if %errorlevel% neq 0 (
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

echo.
echo [OK] Build complete!
echo APK location: build\app\outputs\flutter-apk\app-release.apk
echo.

:: Open output folder
explorer build\app\outputs\flutter-apk\

pause
