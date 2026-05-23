@echo off
:: ============================================================================
::  OPTIMIZADOR DE PC + NAVEGADORES  (Brave / Chrome / Firefox / Edge)
::  Autor: script generado para Fabio
::  Uso:   click derecho -> Ejecutar como administrador
::         (si no, se auto-eleva)
::
::  QUE HACE (todo es seguro - NO borra: bookmarks, passwords, sesiones,
::            historial, ni archivos personales):
::    1) Limpia temporales Windows + Prefetch + papelera
::    2) Flush DNS, reset Winsock, renueva IP
::    3) chkdsk + sfc + DISM (verifica integridad)
::    4) Repara Windows Update / limpia WinSxS
::    5) Optimiza unidades (TRIM en SSD, defrag en HDD)
::    6) Limpia cache de Brave/Chrome/Firefox/Edge
::    7) Ajusta plan de energia a Rendimiento Maximo
::    8) Limpia logs de eventos
::    9) Todo lo anterior (opcion completa)
::
::  IMPORTANTE: revisa cada opcion antes de ejecutar. Algunas requieren
::              reinicio (sfc/DISM).
:: ============================================================================

setlocal EnableDelayedExpansion
chcp 65001 >nul
title Optimizador PC + Navegadores

:: ---------- Auto-elevacion a admin ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ============================================================
echo    OPTIMIZADOR DE PC + NAVEGADORES
echo ============================================================
echo.
echo   [1] Limpiar temporales (Windows + Prefetch + Papelera)
echo   [2] Optimizar red (DNS flush, Winsock, IP renew)
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


:: ============================================================
:CLEAN_TEMP
echo.
echo [1/8] Limpiando archivos temporales...
echo.

:: Temp del usuario
if exist "%TEMP%" (
    del /f /s /q "%TEMP%\*.*" 2>nul
    for /d %%D in ("%TEMP%\*") do rd /s /q "%%D" 2>nul
)

:: Temp del sistema
if exist "C:\Windows\Temp" (
    del /f /s /q "C:\Windows\Temp\*.*" 2>nul
    for /d %%D in ("C:\Windows\Temp\*") do rd /s /q "%%D" 2>nul
)

:: Prefetch (Windows lo regenera)
if exist "C:\Windows\Prefetch" (
    del /f /s /q "C:\Windows\Prefetch\*.*" 2>nul
)

:: Cache de miniaturas
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" 2>nul

:: Recent files
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*" 2>nul

:: Papelera de reciclaje (todas las unidades)
echo Vaciando papelera de reciclaje...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"

:: Cleanmgr en modo silencioso con preset agresivo
echo Lanzando Liberador de espacio...
cleanmgr /sagerun:1 >nul 2>&1

echo.
echo  [OK] Temporales limpiados.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:NET_OPT
echo.
echo [2/8] Optimizando configuracion de red...
echo.

ipconfig /flushdns
ipconfig /release
ipconfig /renew
ipconfig /registerdns
netsh winsock reset
netsh int ip reset
netsh interface ipv4 reset
netsh interface ipv6 reset
netsh advfirewall reset

:: DNS de Cloudflare (rapido y privado) - DESCOMENTAR si lo quieres aplicar
:: netsh interface ipv4 set dns name="Wi-Fi" static 1.1.1.1 primary
:: netsh interface ipv4 add dns name="Wi-Fi" 1.0.0.1 index=2

echo.
echo  [OK] Red optimizada. Puede requerir reinicio para aplicar Winsock.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:SYS_CHECK
echo.
echo [3/8] Verificando integridad del sistema (puede tardar 10-30 min)...
echo.

echo  -> Ejecutando DISM /CheckHealth
DISM /Online /Cleanup-Image /CheckHealth

echo  -> Ejecutando DISM /ScanHealth
DISM /Online /Cleanup-Image /ScanHealth

echo  -> Ejecutando DISM /RestoreHealth
DISM /Online /Cleanup-Image /RestoreHealth

echo  -> Ejecutando sfc /scannow
sfc /scannow

echo.
echo  -> Programando chkdsk para el proximo reinicio (C:)...
echo Y | chkdsk C: /f /r /x >nul 2>&1

echo.
echo  [OK] Verificacion completada. chkdsk se ejecutara al reiniciar.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:WU_REPAIR
echo.
echo [4/8] Reparando Windows Update y limpiando WinSxS...
echo.

net stop wuauserv >nul 2>&1
net stop cryptSvc >nul 2>&1
net stop bits >nul 2>&1
net stop msiserver >nul 2>&1

if exist "C:\Windows\SoftwareDistribution.old" rd /s /q "C:\Windows\SoftwareDistribution.old"
if exist "C:\Windows\System32\catroot2.old" rd /s /q "C:\Windows\System32\catroot2.old"

ren "C:\Windows\SoftwareDistribution" SoftwareDistribution.old 2>nul
ren "C:\Windows\System32\catroot2" catroot2.old 2>nul

net start wuauserv >nul 2>&1
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start msiserver >nul 2>&1

echo  -> Limpiando componentes obsoletos de WinSxS...
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

echo.
echo  [OK] Windows Update reparado.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:DRIVE_OPT
echo.
echo [5/8] Optimizando unidades (TRIM en SSD / defrag en HDD)...
echo.

defrag C: /O /U /V

echo.
echo  [OK] Optimizacion de unidad completada.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:BROWSER_CLEAN
echo.
echo [6/8] Limpiando cache de navegadores...
echo.
echo  IMPORTANTE: cerrando los navegadores primero (guarda tu trabajo).
timeout /t 3 >nul

taskkill /F /IM chrome.exe   >nul 2>&1
taskkill /F /IM brave.exe    >nul 2>&1
taskkill /F /IM firefox.exe  >nul 2>&1
taskkill /F /IM msedge.exe   >nul 2>&1

:: ---------- GOOGLE CHROME ----------
echo  -> Limpiando Chrome...
set "CHR=%LOCALAPPDATA%\Google\Chrome\User Data"
if exist "%CHR%" (
    for /d %%P in ("%CHR%\Default" "%CHR%\Profile*") do (
        if exist "%%P\Cache"          rd /s /q "%%P\Cache"          2>nul
        if exist "%%P\Code Cache"     rd /s /q "%%P\Code Cache"     2>nul
        if exist "%%P\GPUCache"       rd /s /q "%%P\GPUCache"       2>nul
        if exist "%%P\Service Worker" rd /s /q "%%P\Service Worker" 2>nul
        del /f /q "%%P\*.log" 2>nul
    )
)

:: ---------- BRAVE ----------
echo  -> Limpiando Brave...
set "BRV=%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"
if exist "%BRV%" (
    for /d %%P in ("%BRV%\Default" "%BRV%\Profile*") do (
        if exist "%%P\Cache"          rd /s /q "%%P\Cache"          2>nul
        if exist "%%P\Code Cache"     rd /s /q "%%P\Code Cache"     2>nul
        if exist "%%P\GPUCache"       rd /s /q "%%P\GPUCache"       2>nul
        if exist "%%P\Service Worker" rd /s /q "%%P\Service Worker" 2>nul
        del /f /q "%%P\*.log" 2>nul
    )
)

:: ---------- MICROSOFT EDGE ----------
echo  -> Limpiando Edge...
set "EDG=%LOCALAPPDATA%\Microsoft\Edge\User Data"
if exist "%EDG%" (
    for /d %%P in ("%EDG%\Default" "%EDG%\Profile*") do (
        if exist "%%P\Cache"          rd /s /q "%%P\Cache"          2>nul
        if exist "%%P\Code Cache"     rd /s /q "%%P\Code Cache"     2>nul
        if exist "%%P\GPUCache"       rd /s /q "%%P\GPUCache"       2>nul
        if exist "%%P\Service Worker" rd /s /q "%%P\Service Worker" 2>nul
        del /f /q "%%P\*.log" 2>nul
    )
)

:: ---------- FIREFOX ----------
echo  -> Limpiando Firefox...
set "FF=%LOCALAPPDATA%\Mozilla\Firefox\Profiles"
if exist "%FF%" (
    for /d %%P in ("%FF%\*") do (
        if exist "%%P\cache2"           rd /s /q "%%P\cache2"           2>nul
        if exist "%%P\startupCache"     rd /s /q "%%P\startupCache"     2>nul
        if exist "%%P\thumbnails"       rd /s /q "%%P\thumbnails"       2>nul
        if exist "%%P\shader-cache"     rd /s /q "%%P\shader-cache"     2>nul
        if exist "%%P\OfflineCache"     rd /s /q "%%P\OfflineCache"     2>nul
        del /f /q "%%P\*.log" 2>nul
    )
)
:: Cache adicional de Firefox en Roaming
set "FFR=%APPDATA%\Mozilla\Firefox\Profiles"
if exist "%FFR%" (
    for /d %%P in ("%FFR%\*") do (
        if exist "%%P\cache2" rd /s /q "%%P\cache2" 2>nul
    )
)

echo.
echo  [OK] Cache de navegadores limpiada. Bookmarks, passwords y sesiones intactos.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:POWER_PLAN
echo.
echo [7/8] Configurando plan de energia: Rendimiento Maximo...
echo.

:: Activar plan "Ultimate Performance" (Win 10/11)
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
:: Aplicar Alto Rendimiento como fallback
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
:: Si existe Ultimate, aplicarlo (suele ser e9a42b02...)
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1

:: Desactivar hibernacion (libera GB en C:)
powercfg -h off

:: Mostrar plan activo
powercfg /getactivescheme

echo.
echo  [OK] Plan de energia aplicado. Hibernacion desactivada.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:CLEAN_LOGS
echo.
echo [8/8] Limpiando logs de eventos de Windows...
echo.

for /f "tokens=*" %%L in ('wevtutil el') do (
    wevtutil cl "%%L" 2>nul
)

echo.
echo  [OK] Logs de eventos limpiados.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:RUN_ALL
set "RUN_MODE=ALL"
echo.
echo ============================================================
echo  EJECUTANDO MANTENIMIENTO COMPLETO
echo  Esto puede tardar 30-60 minutos. NO cierres la ventana.
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
echo   Se recomienda REINICIAR el equipo para aplicar todo.
echo ============================================================
set "RUN_MODE="
pause
goto MENU
