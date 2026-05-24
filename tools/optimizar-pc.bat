@echo off
:: ============================================================================
::  OPTIMIZADOR DE PC + NAVEGADORES  (Brave / Chrome / Firefox / Edge)
::  Uso: click derecho - Ejecutar como administrador (auto-eleva si no)
:: ============================================================================

setlocal EnableDelayedExpansion
title Optimizador PC + Navegadores
color 0A

:: ---------- Auto-elevacion ----------
net session >nul 2>&1
if errorlevel 1 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:MENU
cls
echo ============================================================
echo    OPTIMIZADOR DE PC + NAVEGADORES
echo ============================================================
echo.
echo   [1] Limpiar temporales (Windows + Prefetch + Papelera)
echo   [2] Optimizar red basica (DNS flush, Winsock, IP renew)
echo   [3] Verificar integridad del sistema (sfc + DISM)
echo   [4] Reparar Windows Update
echo   [5] Optimizar unidades (SSD/HDD)
echo   [6] Limpiar cache de Navegadores (Brave/Chrome/Firefox/Edge)
echo   [7] Plan de energia: Rendimiento Maximo
echo   [8] Limpiar logs de eventos
echo   [9] EJECUTAR TODO (recomendado mensual)
echo.
echo   [0] Salir
echo ============================================================
set /p OPT="  Elige una opcion: "

if "%OPT%"=="1" goto CLEAN_TEMP
if "%OPT%"=="2" goto NET_OPT
if "%OPT%"=="3" goto SYS_CHECK
if "%OPT%"=="4" goto WU_REPAIR
if "%OPT%"=="5" goto DRIVE_OPT
if "%OPT%"=="6" goto BROWSER_CLEAN
if "%OPT%"=="7" goto POWER_PLAN
if "%OPT%"=="8" goto CLEAN_LOGS
if "%OPT%"=="9" goto RUN_ALL
if "%OPT%"=="0" exit /b
goto MENU


:CLEAN_TEMP
echo.
echo [+] Limpiando archivos temporales...
echo.

if exist "%TEMP%" (
    del /f /s /q "%TEMP%\*.*" >nul 2>&1
    for /d %%D in ("%TEMP%\*") do rd /s /q "%%D" >nul 2>&1
)

if exist "C:\Windows\Temp" (
    del /f /s /q "C:\Windows\Temp\*.*" >nul 2>&1
    for /d %%D in ("C:\Windows\Temp\*") do rd /s /q "%%D" >nul 2>&1
)

if exist "C:\Windows\Prefetch" (
    del /f /s /q "C:\Windows\Prefetch\*.*" >nul 2>&1
)

del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1

echo Vaciando papelera de reciclaje...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo  [OK] Temporales limpiados.
if defined RUN_MODE goto :eof
pause
goto MENU


:NET_OPT
echo.
echo [+] Optimizando red basica...
echo.

ipconfig /flushdns
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /registerdns >nul 2>&1
netsh winsock reset >nul
netsh int ip reset >nul

echo.
echo  [OK] Red reiniciada. Para optimizacion AVANZADA usa acelerar-red.bat
if defined RUN_MODE goto :eof
pause
goto MENU


:SYS_CHECK
echo.
echo [+] Verificando integridad del sistema (10-30 min)...
echo.

DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

echo.
echo  Programando chkdsk para el proximo reinicio (C:)...
echo Y | chkdsk C: /f /r /x >nul 2>&1

echo.
echo  [OK] Verificacion completada.
if defined RUN_MODE goto :eof
pause
goto MENU


:WU_REPAIR
echo.
echo [+] Reparando Windows Update...
echo.

net stop wuauserv >nul 2>&1
net stop cryptSvc >nul 2>&1
net stop bits >nul 2>&1
net stop msiserver >nul 2>&1

if exist "C:\Windows\SoftwareDistribution.old" rd /s /q "C:\Windows\SoftwareDistribution.old" >nul 2>&1
if exist "C:\Windows\System32\catroot2.old" rd /s /q "C:\Windows\System32\catroot2.old" >nul 2>&1

ren "C:\Windows\SoftwareDistribution" SoftwareDistribution.old >nul 2>&1
ren "C:\Windows\System32\catroot2" catroot2.old >nul 2>&1

net start wuauserv >nul 2>&1
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start msiserver >nul 2>&1

DISM /Online /Cleanup-Image /StartComponentCleanup

echo.
echo  [OK] Windows Update reparado.
if defined RUN_MODE goto :eof
pause
goto MENU


:DRIVE_OPT
echo.
echo [+] Optimizando unidades (TRIM en SSD / defrag en HDD)...
echo.
defrag C: /O /U /V
echo.
echo  [OK] Optimizacion completada.
if defined RUN_MODE goto :eof
pause
goto MENU


:BROWSER_CLEAN
echo.
echo [+] Limpiando cache de navegadores...
echo.
echo  Cerrando navegadores (guarda tu trabajo)...
timeout /t 3 >nul

taskkill /F /IM chrome.exe   >nul 2>&1
taskkill /F /IM brave.exe    >nul 2>&1
taskkill /F /IM firefox.exe  >nul 2>&1
taskkill /F /IM msedge.exe   >nul 2>&1

echo  -^> Chrome...
call :CLEAR_CHROMIUM "%LOCALAPPDATA%\Google\Chrome\User Data"

echo  -^> Brave...
call :CLEAR_CHROMIUM "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"

echo  -^> Edge...
call :CLEAR_CHROMIUM "%LOCALAPPDATA%\Microsoft\Edge\User Data"

echo  -^> Firefox...
if exist "%LOCALAPPDATA%\Mozilla\Firefox\Profiles" (
    for /d %%P in ("%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*") do (
        if exist "%%P\cache2"       rd /s /q "%%P\cache2"       >nul 2>&1
        if exist "%%P\startupCache" rd /s /q "%%P\startupCache" >nul 2>&1
        if exist "%%P\thumbnails"   rd /s /q "%%P\thumbnails"   >nul 2>&1
        if exist "%%P\shader-cache" rd /s /q "%%P\shader-cache" >nul 2>&1
        if exist "%%P\OfflineCache" rd /s /q "%%P\OfflineCache" >nul 2>&1
    )
)
if exist "%APPDATA%\Mozilla\Firefox\Profiles" (
    for /d %%P in ("%APPDATA%\Mozilla\Firefox\Profiles\*") do (
        if exist "%%P\cache2" rd /s /q "%%P\cache2" >nul 2>&1
    )
)

echo.
echo  [OK] Cache de navegadores limpiada (bookmarks/passwords intactos).
if defined RUN_MODE goto :eof
pause
goto MENU

:CLEAR_CHROMIUM
:: %~1 = ruta "User Data" del browser
if not exist "%~1" exit /b
for /d %%P in ("%~1\Default" "%~1\Profile*") do (
    if exist "%%P\Cache"          rd /s /q "%%P\Cache"          >nul 2>&1
    if exist "%%P\Code Cache"     rd /s /q "%%P\Code Cache"     >nul 2>&1
    if exist "%%P\GPUCache"       rd /s /q "%%P\GPUCache"       >nul 2>&1
    if exist "%%P\Service Worker" rd /s /q "%%P\Service Worker" >nul 2>&1
)
exit /b


:POWER_PLAN
echo.
echo [+] Configurando plan de energia: Rendimiento Maximo...
echo.

powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -h off >nul 2>&1
powercfg /getactivescheme

echo.
echo  [OK] Plan de energia aplicado. Hibernacion desactivada.
if defined RUN_MODE goto :eof
pause
goto MENU


:CLEAN_LOGS
echo.
echo [+] Limpiando logs de eventos de Windows...
echo.
for /f "tokens=*" %%L in ('wevtutil el 2^>nul') do wevtutil cl "%%L" >nul 2>&1
echo  [OK] Logs limpiados.
if defined RUN_MODE goto :eof
pause
goto MENU


:RUN_ALL
set "RUN_MODE=1"
echo.
echo ============================================================
echo  EJECUTANDO MANTENIMIENTO COMPLETO (30-60 min)
echo ============================================================
echo.
pause

call :CLEAN_TEMP
call :NET_OPT
call :BROWSER_CLEAN
call :POWER_PLAN
call :CLEAN_LOGS
call :DRIVE_OPT
call :WU_REPAIR
call :SYS_CHECK

echo.
echo ============================================================
echo   MANTENIMIENTO COMPLETO FINALIZADO
echo   Se recomienda REINICIAR el equipo.
echo ============================================================
set "RUN_MODE="
pause
goto MENU
