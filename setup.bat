@echo off
setlocal enabledelayedexpansion

echo ============================================
echo    SOS Help Listener - Project Setup
echo ============================================
echo.

:: Check Flutter installation
echo [1/5] Checking Flutter installation...
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not installed or not in PATH.
    echo Please install Flutter from https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

flutter --version
echo [OK] Flutter found.
echo.

:: Check Dart installation
echo [2/5] Checking Dart SDK...
where dart >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Dart SDK not found. It should come with Flutter.
    pause
    exit /b 1
)
echo [OK] Dart SDK found.
echo.

:: Run flutter doctor
echo [3/5] Running Flutter doctor...
flutter doctor
echo.

:: Clean previous build (optional)
echo [4/5] Cleaning previous build artifacts...
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool" 2>nul
)
if exist "build" (
    echo Removing build directory...
    rmdir /s /q "build" 2>nul
)
flutter clean
echo [OK] Clean complete.
echo.

:: Install dependencies
echo [5/5] Installing Flutter dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)
echo [OK] Dependencies installed.
echo.

:: Check connected devices
echo ============================================
echo    Checking Connected Devices
echo ============================================
flutter devices
echo.

:: Success message
echo ============================================
echo    Setup Complete!
echo ============================================
echo.
echo Next steps:
echo   1. Connect an Android device (recommended) or start an emulator
echo   2. Run: flutter run
echo   3. For APK build: flutter build apk
echo.
echo For speech recognition testing, use a physical Android device.
echo.

pause
