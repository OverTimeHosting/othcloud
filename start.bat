@echo off
REM OthCloud Windows Starter Script
REM This script helps Windows users start OthCloud easily

echo.
echo ======================================
echo    OthCloud Windows Starter
echo ======================================
echo.

REM Check if we're in the right directory
if not exist "package.json" (
    echo Error: package.json not found. Make sure you're in the othcloud directory.
    echo.
    pause
    exit /b 1
)

REM Check if make is available (from Git Bash, WSL, or other tools)
where make >nul 2>&1
if %errorlevel%==0 (
    echo Found 'make' command. Using Makefile...
    echo.
    echo Available commands:
    echo   1. Development mode  (make dev)
    echo   2. Production mode   (make prod)  
    echo   3. Stop services     (make stop)
    echo   4. View logs         (make logs)
    echo   5. View status       (make status)
    echo.
    set /p choice="Enter your choice (1-5): "
    
    if "%choice%"=="1" make dev
    if "%choice%"=="2" make prod
    if "%choice%"=="3" make stop
    if "%choice%"=="4" make logs
    if "%choice%"=="5" make status
    
    pause
    exit /b 0
)

REM Check if bash is available (Git Bash, WSL)
where bash >nul 2>&1
if %errorlevel%==0 (
    echo Found bash. Running start.sh script...
    echo.
    echo Available options:
    echo   1. Development mode  (--dev)
    echo   2. Production mode   (--prod)
    echo   3. Setup only        (--setup)
    echo   4. Stop services     (--stop)
    echo.
    set /p choice="Enter your choice (1-4): "
    
    if "%choice%"=="1" bash start.sh --dev
    if "%choice%"=="2" bash start.sh --prod
    if "%choice%"=="3" bash start.sh --setup
    if "%choice%"=="4" bash start.sh --stop
    
    pause
    exit /b 0
)

REM If no bash or make, try npm/pnpm scripts
where pnpm >nul 2>&1
if %errorlevel%==0 (
    echo Using pnpm scripts...
    echo.
    echo Available commands:
    echo   1. Start development (pnpm start)
    echo   2. Setup only        (pnpm setup)
    echo   3. View logs         (pnpm logs)
    echo   4. View status       (pnpm status)
    echo.
    set /p choice="Enter your choice (1-4): "
    
    if "%choice%"=="1" pnpm start
    if "%choice%"=="2" pnpm setup
    if "%choice%"=="3" pnpm logs
    if "%choice%"=="4" pnpm status
    
    pause
    exit /b 0
)

REM Last resort - npm
where npm >nul 2>&1
if %errorlevel%==0 (
    echo Using npm scripts...
    echo Installing pnpm first...
    npm install -g pnpm
    pnpm start
    pause
    exit /b 0
)

echo.
echo ==========================================
echo ERROR: No suitable tools found!
echo.
echo Please install one of the following:
echo   1. Git for Windows (includes Git Bash)
echo   2. Windows Subsystem for Linux (WSL)
echo   3. Node.js and npm
echo.
echo Then try running this script again.
echo ==========================================
echo.
pause
