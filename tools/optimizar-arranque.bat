@echo off
:: ============================================================================
::  OPTIMIZADOR DE ARRANQUE DE WINDOWS
::  Uso: click derecho - Ejecutar como administrador
:: ============================================================================

setlocal EnableDelayedExpansion
title Optimizador de Arranque Windows
color 0B

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
echo    OPTIMIZADOR DE ARRANQUE DE WINDOWS
echo ============================================================
echo.
echo   [1] Ver programas que arrancan con Windows
echo   [2] Ver servicios automaticos
echo   [3] Desactivar BLOATWARE comun
echo   [4] Optimizar boot (timeout, sin GUI)
echo   [5] Activar Fast Startup
echo   [6] Desactivar servicios innecesarios
echo   [7] Desactivar tareas de telemetria
echo   [8] Ver tiempos de arranque recientes
echo   [9] Generar REPORTE HTML en el Escritorio
echo.
echo   [A] APLICAR TODO
echo   [R] Restaurar valores por defecto de boot
echo   [0] Salir
echo ============================================================
set /p OPT="  Elige una opcion: "

if /i "%OPT%"=="1" goto LIST_STARTUP
if /i "%OPT%"=="2" goto LIST_SERVICES
if /i "%OPT%"=="3" goto KILL_BLOAT
if /i "%OPT%"=="4" goto OPT_BOOT
if /i "%OPT%"=="5" goto FAST_STARTUP
if /i "%OPT%"=="6" goto KILL_SERVICES
if /i "%OPT%"=="7" goto KILL_TELEMETRY
if /i "%OPT%"=="8" goto BOOT_TIMES
if /i "%OPT%"=="9" goto REPORT
if /i "%OPT%"=="A" goto RUN_ALL
if /i "%OPT%"=="R" goto RESTORE_BOOT
if /i "%OPT%"=="0" exit /b
goto MENU


:LIST_STARTUP
echo.
echo === PROGRAMAS QUE ARRANCAN CON WINDOWS ===
echo.
echo --- HKCU Run ---
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo --- HKLM Run ---
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo --- Carpeta Startup del usuario ---
dir /b "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo.
echo --- Carpeta Startup global ---
dir /b "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:LIST_SERVICES
echo.
echo === SERVICIOS AUTOMATICOS ===
echo.
powershell -NoProfile -Command "Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Status,Name,DisplayName | Format-Table -AutoSize"
if defined RUN_MODE goto :eof
pause
goto MENU


:KILL_BLOAT
echo.
echo === DESACTIVAR BLOATWARE DEL ARRANQUE ===
echo.
echo  Se desactivara (NO desinstala):
echo    OneDrive, Spotify, Skype, Cortana, XboxGameBar, Teams,
echo    Adobe Updater, iTunes, QuickTime, Office ClickToRun,
echo    HP/Dell/Lenovo, Steam, Epic, Discord, uTorrent
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

set "TARGETS=OneDrive Spotify Skype Cortana XboxGameBar Teams AdobeAAMUpdater iTunesHelper QuickTime OfficeClickToRun HPSupportAssistant DellUpdate LenovoVantage Steam EpicGamesLauncher Discord uTorrent BitTorrent"

for %%T in (%TARGETS%) do (
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%T" /f >nul 2>&1
    reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%T" /f >nul 2>&1
)

echo  [OK] Bloatware desactivado.
if defined RUN_MODE goto :eof
pause
goto MENU


:OPT_BOOT
echo.
echo === OPTIMIZAR BOOT ===
echo.

bcdedit /timeout 3 >nul 2>&1
echo  [OK] Timeout: 3 segundos

bcdedit /set quietboot yes >nul 2>&1
echo  [OK] Quiet boot activado

:: Detectar nucleos via PowerShell (mas confiable que wmic)
for /f %%C in ('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum"') do set CORES=%%C
if defined CORES (
    bcdedit /set numproc %CORES% >nul 2>&1
    echo  [OK] Usando %CORES% nucleos en arranque
)

bcdedit /set bootmenupolicy Standard >nul 2>&1

echo.
echo  [OK] Boot optimizado.
if defined RUN_MODE goto :eof
pause
goto MENU


:FAST_STARTUP
echo.
echo === ACTIVAR FAST STARTUP ===
echo.
powercfg /hibernate on >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f >nul

echo  [OK] Fast Startup activado.
if defined RUN_MODE goto :eof
pause
goto MENU


:KILL_SERVICES
echo.
echo === DESACTIVAR SERVICIOS INNECESARIOS ===
echo.
echo  Servicios a MANUAL (no se eliminan):
echo    DiagTrack, dmwappushservice, RemoteRegistry, Fax,
echo    WMPNetworkSvc, Xbox*, MapsBroker, RetailDemo
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

set "SERVICES=DiagTrack dmwappushservice RemoteRegistry Fax WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc MapsBroker RetailDemo"

for %%S in (%SERVICES%) do (
    sc config "%%S" start= demand >nul 2>&1
    sc stop "%%S" >nul 2>&1
)

echo  [OK] Servicios principales en manual.
echo.

set /p OPT_WSEARCH="  Desactivar Windows Search? Solo si SSD y poca RAM (S/N): "
if /i "%OPT_WSEARCH%"=="S" (
    sc config WSearch start= demand >nul 2>&1
    sc stop WSearch >nul 2>&1
    echo  [-] WSearch en manual
)

set /p OPT_SYSMAIN="  Desactivar SysMain/Superfetch? Recomendado para SSD (S/N): "
if /i "%OPT_SYSMAIN%"=="S" (
    sc config SysMain start= demand >nul 2>&1
    sc stop SysMain >nul 2>&1
    echo  [-] SysMain en manual
)

echo  [OK] Servicios optimizados.
if defined RUN_MODE goto :eof
pause
goto MENU


:KILL_TELEMETRY
echo.
echo === DESACTIVAR TAREAS DE TELEMETRIA ===
echo.

schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Application Experience\ProgramDataUpdater" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Autochk\Proxy" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Feedback\Siuf\DmClient" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Windows Error Reporting\QueueReporting" >nul 2>&1
schtasks /change /disable /tn "\Microsoft\Windows\Maps\MapsUpdateTask" >nul 2>&1

echo  [OK] Tareas de telemetria desactivadas.
if defined RUN_MODE goto :eof
pause
goto MENU


:BOOT_TIMES
echo.
echo === TIEMPOS DE ARRANQUE RECIENTES ===
echo.
powershell -NoProfile -Command "try { Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; Id=100} -MaxEvents 10 -ErrorAction Stop | Select-Object TimeCreated, @{n='Boot_seg';e={[math]::Round($_.Properties[10].Value/1000,1)}} | Format-Table -AutoSize } catch { Write-Host 'No se pudieron leer los eventos. Es normal si recien instalaste Windows.' }"
echo.
echo  Objetivo:
echo    SSD NVMe: 5-15 seg
echo    SSD SATA: 10-25 seg
echo    HDD:      30-90 seg
echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:REPORT
echo.
echo === GENERANDO REPORTE HTML ===
echo.
set "OUT=%USERPROFILE%\Desktop\reporte-arranque.html"

powershell -NoProfile -Command "$startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, User, Location; $svc = Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Name, DisplayName, Status; $head = '<style>body{font-family:Segoe UI,sans-serif;padding:20px;background:#1e1e1e;color:#ddd}h1,h2{color:#4ec9b0}table{border-collapse:collapse;width:100%%;margin-bottom:30px}th,td{border:1px solid #444;padding:6px 10px;text-align:left}th{background:#2d2d2d}tr:nth-child(even){background:#252525}</style>'; $body = '<h1>Reporte de Arranque - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</h1><h2>Programas en arranque</h2>' + ($startup | ConvertTo-Html -Fragment) + '<h2>Servicios automaticos</h2>' + ($svc | ConvertTo-Html -Fragment); ConvertTo-Html -Head $head -Body $body | Out-File -FilePath '%OUT%' -Encoding UTF8"

echo  [OK] Reporte: %OUT%
start "" "%OUT%"
if defined RUN_MODE goto :eof
pause
goto MENU


:RESTORE_BOOT
echo.
echo === RESTAURAR BOOT POR DEFECTO ===
bcdedit /timeout 30 >nul 2>&1
bcdedit /deletevalue quietboot >nul 2>&1
bcdedit /deletevalue numproc >nul 2>&1
echo  [OK] Restaurado.
pause
goto MENU


:RUN_ALL
set "RUN_MODE=1"
echo.
echo  Aplicando todo... continuar?
set /p CONFIRM="  (S/N): "
if /i not "%CONFIRM%"=="S" (
    set "RUN_MODE="
    goto MENU
)

call :LIST_STARTUP
call :KILL_BLOAT
call :OPT_BOOT
call :FAST_STARTUP
call :KILL_SERVICES
call :KILL_TELEMETRY
call :REPORT
call :BOOT_TIMES

echo.
echo  [OK] Optimizacion de arranque completada.
echo  REINICIA para aplicar los cambios.
set "RUN_MODE="
pause
goto MENU
