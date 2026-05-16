@echo off
echo ============================================
echo    SOS Help Listener - Run App
echo ============================================
echo.

:: Check for connected devices
echo Checking connected devices...
flutter devices
echo.

:: Run the app
echo Starting the app...
flutter run

pause
