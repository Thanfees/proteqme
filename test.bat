@echo off
echo ============================================
echo    SOS Help Listener - Run Tests
echo ============================================
echo.

echo Running all tests...
flutter test

if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Some tests failed.
) else (
    echo.
    echo [OK] All tests passed!
)

pause
