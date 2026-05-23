@echo off
:: ============================================================================
::  OPTIMIZADOR DE ARRANQUE DE WINDOWS  (Boot + Startup)
::  Autor: script generado para Fabio
::  Uso:   click derecho -> Ejecutar como administrador (auto-eleva si no)
::
::  QUE HACE:
::    1) Lista programas que arrancan con Windows (Registro + Carpeta startup)
::    2) Lista servicios que arrancan con Windows
::    3) Desactiva BLOATWARE comun (con confirmacion)
::    4) Optimiza configuracion de boot (bcdedit: timeout, sin gui)
::    5) Activa Fast Startup
::    6) Desactiva servicios innecesarios (con confirmacion)
::    7) Limpia tareas programadas de telemetria
::    8) Muestra tiempos de arranque ultimos 10 boots
::    9) Reporte completo (HTML en el escritorio)
::
::  NO desactiva nada critico ni sin preguntarte. Todo es reversible.
:: ============================================================================

setlocal EnableDelayedExpansion
chcp 65001 >nul
title Optimizador de Arranque Windows

:: ---------- Auto-elevacion ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ============================================================
echo    OPTIMIZADOR DE ARRANQUE DE WINDOWS
echo ============================================================
echo.
echo   [1] Ver programas que arrancan con Windows
echo   [2] Ver servicios que arrancan con Windows
echo   [3] Desactivar BLOATWARE comun (con confirmacion)
echo   [4] Optimizar boot (timeout, sin GUI boot)
echo   [5] Activar Fast Startup
echo   [6] Desactivar servicios innecesarios (con confirmacion)
echo   [7] Desactivar tareas de telemetria
echo   [8] Ver tiempos de arranque recientes
echo   [9] Generar REPORTE HTML completo en el Escritorio
echo.
echo   [A] APLICAR TODO de una (recomendado)
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


:: ============================================================
:LIST_STARTUP
echo.
echo ===== PROGRAMAS QUE ARRANCAN CON WINDOWS =====
echo.
echo --- Registro: HKCU\...\Run ---
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo --- Registro: HKLM\...\Run ---
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo --- Carpeta Startup del usuario ---
dir /b "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo.
echo --- Carpeta Startup global ---
dir /b "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo.
echo --- Tareas programadas en arranque ---
schtasks /query /fo TABLE /v 2>nul | findstr /i "ONLOGON ONSTART BOOT"
echo.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:LIST_SERVICES
echo.
echo ===== SERVICIOS QUE ARRANCAN AUTOMATICAMENTE =====
echo.
sc query type= service state= all | findstr /i "SERVICE_NAME DISPLAY_NAME" > "%TEMP%\svc_all.txt"
powershell -NoProfile -Command ^
  "Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Status,Name,DisplayName | Format-Table -AutoSize"
echo.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:KILL_BLOAT
echo.
echo ===== DESACTIVAR BLOATWARE DEL ARRANQUE =====
echo.
echo  Se van a DESACTIVAR (no desinstalar) estos programas comunes:
echo    - OneDrive (si no lo usas)
echo    - Spotify
echo    - Skype
echo    - Cortana
echo    - Xbox Game Bar
echo    - Microsoft Teams
echo    - Adobe Updater
echo    - iTunes Helper
echo    - QuickTime
echo    - Office ClickToRun (background)
echo    - HP/Dell/Lenovo bloatware comun
echo.
echo  Tus programas importantes (antivirus, drivers, etc) NO se tocan.
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

set "TARGETS=OneDrive Spotify Skype Cortana XboxGameBar Teams AdobeAAMUpdater iTunesHelper QuickTime OfficeClickToRun HPSupportAssistant DellUpdate LenovoVantage Steam EpicGamesLauncher Discord uTorrent BitTorrent"

for %%T in (%TARGETS%) do (
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%T" /f >nul 2>&1
    reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%T" /f >nul 2>&1
    if !errorlevel! equ 0 echo  [-] Removido del arranque: %%T
)

:: Desactivar via PowerShell tambien (entradas Task Manager Startup)
powershell -NoProfile -Command ^
  "$names = @('OneDrive','Spotify','Skype','Cortana','XboxGameBar','MicrosoftTeams','Adobe Updater','iTunesHelper'); ^
   foreach($n in $names) { Get-CimInstance Win32_StartupCommand | Where-Object { $_.Name -like ""*$n*"" } | ForEach-Object { Write-Host \"  [-] Detectado: $($_.Name)\" } }"

echo.
echo  [OK] Bloatware desactivado del arranque.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:OPT_BOOT
echo.
echo ===== OPTIMIZAR CONFIGURACION DE BOOT =====
echo.

:: Timeout del menu de boot: 3 seg (default 30)
bcdedit /timeout 3
echo  [OK] Timeout de boot: 3 segundos

:: Quita el logo animado de boot (arranque mas rapido visualmente)
bcdedit /set quietboot yes >nul 2>&1
echo  [OK] Quiet boot activado

:: Usa todos los nucleos disponibles en el arranque
for /f "tokens=2 delims==" %%C in ('wmic cpu get NumberOfCores /value ^| find "="') do set CORES=%%C
bcdedit /set numproc %CORES% >nul 2>&1
echo  [OK] Usando %CORES% nucleos en arranque

:: Desactiva la pantalla de eleccion de SO si solo hay uno
bcdedit /set bootmenupolicy Standard >nul 2>&1

echo.
echo  [OK] Configuracion de boot optimizada.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:FAST_STARTUP
echo.
echo ===== ACTIVAR FAST STARTUP =====
echo.

:: Hibernacion debe estar ON para Fast Startup
powercfg /hibernate on

:: Activar Fast Startup (HiberbootEnabled=1)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f >nul

echo  [OK] Fast Startup activado.
echo  Nota: si tu equipo tiene problemas de drivers al despertar,
echo        desactivalo desde Panel de Control - Opciones de Energia.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:KILL_SERVICES
echo.
echo ===== DESACTIVAR SERVICIOS INNECESARIOS =====
echo.
echo  Servicios que se van a poner en MANUAL (no se eliminan):
echo    - DiagTrack            (telemetria)
echo    - dmwappushservice     (telemetria WAP push)
echo    - RemoteRegistry       (registro remoto, riesgo de seguridad)
echo    - Fax                  (fax modem, casi nadie usa)
echo    - WSearch              (indexador, solo si tienes SSD y poca RAM)
echo    - SysMain (Superfetch) (a veces ralentiza SSDs)
echo    - WMPNetworkSvc        (compartir Windows Media)
echo    - XblAuthManager       (Xbox Live Auth)
echo    - XblGameSave          (Xbox Live Save)
echo    - XboxNetApiSvc        (Xbox network)
echo    - MapsBroker           (mapas descargados)
echo    - RetailDemo           (modo demo tienda)
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

set "SERVICES=DiagTrack dmwappushservice RemoteRegistry Fax WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc MapsBroker RetailDemo"

for %%S in (%SERVICES%) do (
    sc config "%%S" start= demand >nul 2>&1
    sc stop "%%S" >nul 2>&1
    if !errorlevel! equ 0 (echo  [-] %%S puesto en MANUAL) else (echo  [.] %%S no encontrado o ya inactivo)
)

echo.
echo  Servicios opcionales (preguntamos uno por uno):
echo.

set /p OPT_WSEARCH="  Desactivar Windows Search (WSearch)? Solo si tienes SSD y poca RAM (S/N): "
if /i "%OPT_WSEARCH%"=="S" (
    sc config WSearch start= demand >nul 2>&1
    sc stop WSearch >nul 2>&1
    echo  [-] WSearch puesto en MANUAL
)

set /p OPT_SYSMAIN="  Desactivar SysMain/Superfetch? Recomendado para SSDs (S/N): "
if /i "%OPT_SYSMAIN%"=="S" (
    sc config SysMain start= demand >nul 2>&1
    sc stop SysMain >nul 2>&1
    echo  [-] SysMain puesto en MANUAL
)

echo.
echo  [OK] Servicios optimizados.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:KILL_TELEMETRY
echo.
echo ===== DESACTIVAR TAREAS DE TELEMETRIA =====
echo.

set "TASKS=^
\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser ^
\Microsoft\Windows\Application Experience\ProgramDataUpdater ^
\Microsoft\Windows\Autochk\Proxy ^
\Microsoft\Windows\Customer Experience Improvement Program\Consolidator ^
\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip ^
\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector ^
\Microsoft\Windows\Feedback\Siuf\DmClient ^
\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload ^
\Microsoft\Windows\Windows Error Reporting\QueueReporting ^
\Microsoft\Windows\Maps\MapsUpdateTask"

for %%T in (%TASKS%) do (
    schtasks /change /disable /tn "%%~T" >nul 2>&1
    if !errorlevel! equ 0 echo  [-] Tarea desactivada: %%~T
)

echo.
echo  [OK] Tareas de telemetria desactivadas.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:BOOT_TIMES
echo.
echo ===== TIEMPOS DE ARRANQUE RECIENTES =====
echo.
powershell -NoProfile -Command ^
  "Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; Id=100} -MaxEvents 10 -ErrorAction SilentlyContinue | ^
   Select-Object TimeCreated, @{n='BootTime(seg)';e={[math]::Round($_.Properties[10].Value/1000,1)}}, @{n='MainPath(seg)';e={[math]::Round($_.Properties[5].Value/1000,1)}}, @{n='PostBoot(seg)';e={[math]::Round($_.Properties[7].Value/1000,1)}} | ^
   Format-Table -AutoSize"
echo.
echo  Tiempo objetivo:
echo    SSD NVMe: 5-15 seg
echo    SSD SATA: 10-25 seg
echo    HDD:      30-90 seg
echo.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:REPORT
echo.
echo ===== GENERANDO REPORTE HTML =====
echo.
set "DESK=%USERPROFILE%\Desktop"
set "OUT=%DESK%\reporte-arranque.html"

powershell -NoProfile -Command ^
  "$startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, User, Location; ^
   $svc = Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Name, DisplayName, Status; ^
   $head = '<style>body{font-family:Segoe UI,sans-serif;padding:20px;background:#1e1e1e;color:#ddd}h1,h2{color:#4ec9b0}table{border-collapse:collapse;width:100%%;margin-bottom:30px}th,td{border:1px solid #444;padding:6px 10px;text-align:left}th{background:#2d2d2d}tr:nth-child(even){background:#252525}</style>'; ^
   $body = '<h1>Reporte de Arranque - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</h1><h2>Programas en el arranque</h2>' + ($startup | ConvertTo-Html -Fragment) + '<h2>Servicios en arranque automatico</h2>' + ($svc | ConvertTo-Html -Fragment); ^
   ConvertTo-Html -Head $head -Body $body | Out-File -FilePath '%OUT%' -Encoding UTF8"

echo  [OK] Reporte guardado en: %OUT%
echo.
start "" "%OUT%"
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:RESTORE_BOOT
echo.
echo ===== RESTAURAR VALORES POR DEFECTO DE BOOT =====
echo.
bcdedit /timeout 30
bcdedit /deletevalue quietboot 2>nul
bcdedit /deletevalue numproc 2>nul
echo  [OK] Timeout restaurado a 30s, quietboot quitado, numproc removido.
pause
goto MENU


:: ============================================================
:RUN_ALL
set "RUN_MODE=ALL"
echo.
echo ============================================================
echo  APLICANDO TODA LA OPTIMIZACION DE ARRANQUE
echo ============================================================
echo.
echo  Se va a:
echo   1) Listar programas y servicios (informativo)
echo   2) Desactivar bloatware del arranque
echo   3) Optimizar bcdedit (boot mas rapido)
echo   4) Activar Fast Startup
echo   5) Poner servicios innecesarios en manual
echo   6) Desactivar tareas de telemetria
echo   7) Generar reporte HTML
echo.
set /p CONFIRM="  Continuar? (S/N): "
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
echo ============================================================
echo   OPTIMIZACION DE ARRANQUE COMPLETADA
echo   REINICIA para que se apliquen todos los cambios.
echo ============================================================
set "RUN_MODE="
pause
goto MENU
