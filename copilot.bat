@echo off
chcp 65001 >nul

:: Sprawdz czy px-proxy dziala (port 3128)
netstat -an 2>nul | findstr ":3128.*LISTENING" >nul
if errorlevel 1 (
    echo [!] px-proxy nie dziala!
    echo     Uruchom najpierw px.bat
    echo.
    pause
    exit /b 1
)

:: Ustaw zmienne srodowiskowe dla proxy
set "GH_TOKEN=abc"
set "HTTP_PROXY=http://localhost:3128"
set "HTTPS_PROXY=http://localhost:3128"
set "NODE_TLS_REJECT_UNAUTHORIZED=0"

:: Uruchom copilot.exe z tego samego folderu co ten bat
:: %~dp0 = sciezka do folderu gdzie jest copilot.bat
:: %* = wszystkie argumenty przekazane do tego bata
"%~dp0copilot.exe" %*
