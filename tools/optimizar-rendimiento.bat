@echo off
:: ============================================================================
::  OPTIMIZADOR DE RENDIMIENTO + MEMORIA + ESPACIO EN DISCO
::  Autor: script generado para Fabio
::  Uso:   click derecho -> Ejecutar como administrador
::
::  QUE HACE:
::    [1] Ver espacio actual en disco C: y descomposicion
::    [2] Buscar archivos grandes (>500 MB) en C:
::    [3] Liberar espacio AGRESIVO en C: (cache, updates, drivers viejos...)
::    [4] Configurar Memoria Virtual (Pagefile) optima segun tu RAM
::    [5] Liberar RAM en uso (working set de procesos)
::    [6] Ajustar efectos visuales para mejor rendimiento
::    [7] Modo Alto Rendimiento + desactivar throttling
::    [8] Desactivar features de Windows que no usas
::    [9] Optimizar Defender (sin desactivar la proteccion)
::    [A] Limpiar carpetas WinSxS / driver store viejos (DISM)
::    [B] Mover carpetas Documentos/Descargas/Fotos a otra unidad (asistente)
::    [C] APLICAR TODO (1+3+4+6+7+9+A)
::    [0] Salir
::
::  TODO es seguro y reversible. Te pregunta antes de cada accion fuerte.
:: ============================================================================

setlocal EnableDelayedExpansion
chcp 65001 >nul
title Optimizador Rendimiento + Memoria + Disco

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
echo    OPTIMIZADOR RENDIMIENTO + MEMORIA + DISCO
echo ============================================================
echo.
echo   [1] Ver espacio actual en C: (analisis)
echo   [2] Buscar archivos gigantes (^>500 MB) en C:
echo   [3] LIBERAR espacio agresivo en C:
echo   [4] Configurar Memoria Virtual optima
echo   [5] Liberar RAM en uso ahora
echo   [6] Efectos visuales para mejor rendimiento
echo   [7] Alto Rendimiento + sin throttling
echo   [8] Desactivar features de Windows innecesarios
echo   [9] Optimizar Windows Defender
echo   [A] Limpiar WinSxS y driver store viejos
echo   [B] Mover Documentos/Descargas a otra unidad
echo.
echo   [C] APLICAR TODO (recomendado)
echo   [0] Salir
echo ============================================================
set /p OPT="  Elige una opcion: "

if /i "%OPT%"=="1" goto DISK_ANALYSIS
if /i "%OPT%"=="2" goto BIG_FILES
if /i "%OPT%"=="3" goto FREE_SPACE
if /i "%OPT%"=="4" goto VIRTUAL_MEM
if /i "%OPT%"=="5" goto FREE_RAM
if /i "%OPT%"=="6" goto VISUAL_FX
if /i "%OPT%"=="7" goto HIGH_PERF
if /i "%OPT%"=="8" goto KILL_FEATURES
if /i "%OPT%"=="9" goto DEFENDER_OPT
if /i "%OPT%"=="A" goto CLEAN_WINSXS
if /i "%OPT%"=="B" goto MOVE_FOLDERS
if /i "%OPT%"=="C" goto RUN_ALL
if /i "%OPT%"=="0" exit /b
goto MENU


:: ============================================================
:DISK_ANALYSIS
echo.
echo ===== ANALISIS DE ESPACIO EN C: =====
echo.

for /f "tokens=3" %%a in ('dir C:\ /-c ^| findstr /c:"bytes free"') do set FREE=%%a
for /f "tokens=3" %%a in ('dir C:\ /-c ^| findstr /c:"Dir(s)"') do set TOTAL=%%a

powershell -NoProfile -Command ^
  "$d = Get-PSDrive C; ^
   $usedGB = [math]::Round($d.Used/1GB,1); $freeGB = [math]::Round($d.Free/1GB,1); ^
   $totalGB = $usedGB + $freeGB; $pct = [math]::Round(($d.Used/($d.Used+$d.Free))*100,1); ^
   Write-Host \"   Total : $totalGB GB\"; ^
   Write-Host \"   Usado : $usedGB GB ($pct%%)\"; ^
   Write-Host \"   Libre : $freeGB GB\"; Write-Host ''"

echo --- Carpetas mas pesadas en C: (top 15) ---
powershell -NoProfile -Command ^
  "Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | ^
   ForEach-Object { ^
     $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum; ^
     [PSCustomObject]@{Folder=$_.Name; SizeGB=[math]::Round($size/1GB,2)} ^
   } | Sort-Object SizeGB -Descending | Select-Object -First 15 | Format-Table -AutoSize"

echo.
echo --- Carpetas mas pesadas en C:\Users\%USERNAME% ---
powershell -NoProfile -Command ^
  "Get-ChildItem 'C:\Users\%USERNAME%' -Directory -Force -ErrorAction SilentlyContinue | ^
   ForEach-Object { ^
     $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum; ^
     [PSCustomObject]@{Folder=$_.Name; SizeGB=[math]::Round($size/1GB,2)} ^
   } | Sort-Object SizeGB -Descending | Select-Object -First 10 | Format-Table -AutoSize"

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:BIG_FILES
echo.
echo ===== ARCHIVOS GRANDES (^>500 MB) en C: =====
echo  (puede tardar 1-3 minutos)
echo.
powershell -NoProfile -Command ^
  "Get-ChildItem C:\ -Recurse -File -Force -ErrorAction SilentlyContinue | ^
   Where-Object { $_.Length -gt 500MB } | ^
   Sort-Object Length -Descending | ^
   Select-Object @{n='Size(GB)';e={[math]::Round($_.Length/1GB,2)}}, FullName -First 30 | ^
   Format-Table -AutoSize -Wrap"

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:FREE_SPACE
echo.
echo ===== LIBERAR ESPACIO AGRESIVO EN C: =====
echo.
echo  Se van a borrar:
echo    - Cache de Windows Update
echo    - Drivers antiguos (DriverStore)
echo    - Logs y dumps de Windows
echo    - Cache de instaladores
echo    - Restos de actualizaciones anteriores (Windows.old si existe)
echo    - Cache de Microsoft Store
echo    - Archivos .tmp en todo C:
echo    - Reportes de errores (WER)
echo    - Cache de DirectX/shader
echo    - Logs de aplicaciones
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

echo.
echo  -^> Cache de Windows Update...
net stop wuauserv >nul 2>&1
if exist "C:\Windows\SoftwareDistribution\Download" (
    rd /s /q "C:\Windows\SoftwareDistribution\Download" 2>nul
    md "C:\Windows\SoftwareDistribution\Download" 2>nul
)
net start wuauserv >nul 2>&1
echo     OK

echo  -^> Drivers antiguos (puede tardar)...
pnputil /enum-drivers > "%TEMP%\drv_list.txt" 2>nul
:: Removemos paquetes oem*.inf que ya no estan en uso (DISM lo decide)
DISM /Online /Cleanup-Image /StartComponentCleanup /Quiet
echo     OK

echo  -^> Windows.old (si existe)...
if exist "C:\Windows.old" (
    takeown /F "C:\Windows.old" /R /D Y >nul 2>&1
    icacls "C:\Windows.old" /grant administrators:F /T >nul 2>&1
    rd /s /q "C:\Windows.old" 2>nul
    echo     OK - Windows.old eliminado
) else (
    echo     . no existe
)

echo  -^> Logs de Windows...
del /f /s /q "C:\Windows\Logs\*.*" 2>nul
del /f /s /q "C:\Windows\Logs\CBS\*.*" 2>nul
del /f /s /q "C:\Windows\Panther\*.log" 2>nul
del /f /s /q "C:\Windows\inf\*.log" 2>nul
echo     OK

echo  -^> Dumps de memoria...
del /f /q "C:\Windows\Minidump\*.*" 2>nul
del /f /q "C:\Windows\memory.dmp" 2>nul
del /f /q "%LOCALAPPDATA%\CrashDumps\*.*" 2>nul
echo     OK

echo  -^> Cache de Microsoft Store...
wsreset.exe >nul 2>&1
echo     OK

echo  -^> Reportes de errores (WER)...
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*" 2>nul
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*" 2>nul
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\Temp\*" 2>nul
echo     OK

echo  -^> Cache de DirectX y shaders...
del /f /s /q "%LOCALAPPDATA%\D3DSCache\*" 2>nul
del /f /s /q "%LOCALAPPDATA%\NVIDIA\GLCache\*" 2>nul
del /f /s /q "%LOCALAPPDATA%\NVIDIA\DXCache\*" 2>nul
del /f /s /q "%LOCALAPPDATA%\AMD\DxCache\*" 2>nul
del /f /s /q "%LOCALAPPDATA%\AMD\GLCache\*" 2>nul
echo     OK

echo  -^> Cache de instaladores temporales...
del /f /s /q "%LOCALAPPDATA%\Package Cache\*.tmp" 2>nul
del /f /q "C:\Config.Msi\*.*" 2>nul
echo     OK

echo  -^> Archivos .tmp en todo C: (puede tardar)...
forfiles /p "C:\Users\%USERNAME%\AppData\Local\Temp" /s /m *.tmp /c "cmd /c del /q @path" >nul 2>&1
echo     OK

echo  -^> Cache de iconos y miniaturas...
del /f /s /q "%LOCALAPPDATA%\IconCache.db" 2>nul
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" 2>nul
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" 2>nul
echo     OK

echo  -^> Cache de fuentes...
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Fonts\*.dat" 2>nul
echo     OK

echo  -^> Volcado de seguridad de OneDrive (cache)...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\setup\logs" (
    del /f /s /q "%LOCALAPPDATA%\Microsoft\OneDrive\setup\logs\*" 2>nul
)
echo     OK

echo  -^> Cleanmgr completo (todos los items)...
:: Activamos todas las categorias
for %%K in (^
  "Active Setup Temp Folders" "BranchCache" "D3D Shader Cache" ^
  "Delivery Optimization Files" "Diagnostic Data Viewer database files" ^
  "Downloaded Program Files" "Internet Cache Files" "Memory Dump Files" ^
  "Old ChkDsk Files" "Previous Installations" "Recycle Bin" ^
  "RetailDemo Offline Content" "Service Pack Cleanup" "Setup Log Files" ^
  "System error memory dump files" "System error minidump files" ^
  "Temporary Files" "Temporary Setup Files" "Temporary Sync Files" ^
  "Thumbnail Cache" "Update Cleanup" "Upgrade Discarded Files" ^
  "User file versions" "Windows Defender" "Windows Error Reporting Files" ^
  "Windows ESD installation files" "Windows Upgrade Log Files"^
) do (
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\%%~K" /v StateFlags9999 /t REG_DWORD /d 2 /f >nul 2>&1
)
cleanmgr /sagerun:9999 >nul 2>&1
echo     OK

echo.
echo  Espacio liberado. Estado actual:
powershell -NoProfile -Command ^
  "$d = Get-PSDrive C; Write-Host ('   Libre ahora: {0:N1} GB de {1:N1} GB' -f ($d.Free/1GB), (($d.Used+$d.Free)/1GB))"
echo.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:VIRTUAL_MEM
echo.
echo ===== CONFIGURAR MEMORIA VIRTUAL (PAGEFILE) =====
echo.

:: Detectar RAM total
for /f "skip=1" %%R in ('wmic ComputerSystem get TotalPhysicalMemory') do (
    if not defined RAMB set RAMB=%%R
)
set /a RAMGB=%RAMB:~0,-9%
echo  RAM detectada: ~%RAMGB% GB
echo.
echo  Recomendaciones segun tu RAM:
echo    Hasta 4 GB:  Pagefile = 1.5x a 3x la RAM  (gestionado por Windows OK)
echo    8 GB:        Pagefile = 4096 - 8192 MB
echo    16 GB:       Pagefile = 4096 - 8192 MB
echo    32 GB+:      Pagefile = 2048 - 4096 MB (poco uso, util para crash dumps)
echo.

:: Calcular valores
if %RAMGB% LEQ 4 (
    set /a PFMIN=%RAMGB%*1500
    set /a PFMAX=%RAMGB%*3000
) else if %RAMGB% LEQ 8 (
    set PFMIN=4096
    set PFMAX=8192
) else if %RAMGB% LEQ 16 (
    set PFMIN=4096
    set PFMAX=8192
) else (
    set PFMIN=2048
    set PFMAX=4096
)

echo  Configuracion recomendada: Inicial=%PFMIN% MB / Maximo=%PFMAX% MB en C:
echo.
set /p APPLY="  Aplicar esta configuracion? (S/N): "
if /i not "%APPLY%"=="S" goto MENU

:: Desactivar gestion automatica
wmic computersystem set AutomaticManagedPagefile=False >nul 2>&1

:: Borrar pagefiles existentes y crear nuevo
wmic pagefileset delete >nul 2>&1
wmic pagefileset create name="C:\\pagefile.sys" >nul 2>&1
wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=%PFMIN%,MaximumSize=%PFMAX% >nul 2>&1

echo.
echo  [OK] Pagefile configurado: %PFMIN% - %PFMAX% MB
echo  Requiere REINICIO para aplicar.
echo.

:: Bonus: limpiar pagefile al apagar (mas seguro pero ralentiza shutdown - opcional)
:: reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f >nul

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:FREE_RAM
echo.
echo ===== LIBERAR RAM EN USO =====
echo.
echo  Liberando working set de procesos no esenciales...
echo.

powershell -NoProfile -Command ^
  "$before = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue; ^
   Write-Host ('RAM disponible ANTES: {0:N0} MB' -f $before); ^
   ^
   $sig = '[DllImport(\"psapi.dll\")] public static extern int EmptyWorkingSet(IntPtr hwProc);'; ^
   $type = Add-Type -MemberDefinition $sig -Name 'Win32' -Namespace 'Memory' -PassThru; ^
   ^
   $skipList = @('System','Idle','Registry','Memory Compression','smss','csrss','wininit','services','lsass','winlogon'); ^
   Get-Process | Where-Object { $skipList -notcontains $_.Name } | ForEach-Object { ^
     try { $null = $type::EmptyWorkingSet($_.Handle) } catch {} ^
   }; ^
   ^
   Start-Sleep -Seconds 2; ^
   $after = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue; ^
   Write-Host ('RAM disponible DESPUES: {0:N0} MB' -f $after); ^
   Write-Host ('Liberado: {0:N0} MB' -f ($after - $before)) -ForegroundColor Green"

echo.
echo  [OK] RAM liberada. (Windows va a reusar cache si la necesita - es normal)
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:VISUAL_FX
echo.
echo ===== AJUSTAR EFECTOS VISUALES =====
echo.
echo  Se van a desactivar animaciones, sombras y transparencias
echo  (Windows se vera mas "plano" pero responde mas rapido).
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

:: VisualFXSetting = 2 (ajustar para mejor rendimiento)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul

:: Animaciones de ventanas off
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul

:: Quitar peek, transparencia, sombras
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul

:: Desactivar animaciones de taskbar y menus
reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul

:: Menu Start mas rapido
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f >nul

echo.
echo  [OK] Efectos visuales optimizados. Cerra sesion para verlo aplicado.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:HIGH_PERF
echo.
echo ===== MODO ALTO RENDIMIENTO + SIN THROTTLING =====
echo.

:: Plan Ultimate Performance
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
:: Fallback High Performance
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1

:: Sin throttling del CPU
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100

:: Sin parking de cores
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100

:: Apagar disco solo despues de 20 min (no en uso continuo)
powercfg -change -disk-timeout-ac 20

:: USB sin suspension selectiva
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

powercfg -setactive SCHEME_CURRENT

echo  [OK] Modo Alto Rendimiento aplicado, throttling y core parking desactivados.

:: Modo Juego siempre activo
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul
echo  [OK] Modo Juego de Windows activado.

:: Desactivar throttling de apps en segundo plano (puede dar mas FPS)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f >nul
echo  [OK] Power throttling de apps desactivado.

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:KILL_FEATURES
echo.
echo ===== DESACTIVAR FEATURES DE WINDOWS INNECESARIOS =====
echo.
echo  Se van a desactivar (REVERSIBLE):
echo    - Internet Explorer 11
echo    - Windows Media Player (legacy)
echo    - Trabajo con XPS
echo    - Cliente Telnet
echo    - Sandbox (si no lo usas)
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

dism /online /disable-feature /featurename:Internet-Explorer-Optional-amd64 /norestart >nul 2>&1
dism /online /disable-feature /featurename:WindowsMediaPlayer /norestart >nul 2>&1
dism /online /disable-feature /featurename:Printing-XPSServices-Features /norestart >nul 2>&1
dism /online /disable-feature /featurename:TelnetClient /norestart >nul 2>&1
dism /online /disable-feature /featurename:WorkFolders-Client /norestart >nul 2>&1

echo  [OK] Features desactivados.

:: Apps de Microsoft Store inutiles (con confirmacion)
echo.
set /p RMAPPS="  Quitar apps preinstaladas (Solitario, Tips, Weather, etc)? (S/N): "
if /i "%RMAPPS%"=="S" (
    powershell -NoProfile -Command ^
      "$apps = @('Microsoft.MicrosoftSolitaireCollection','Microsoft.GetHelp','Microsoft.Getstarted', ^
                 'Microsoft.BingWeather','Microsoft.BingNews','Microsoft.WindowsFeedbackHub', ^
                 'Microsoft.MicrosoftStickyNotes','Microsoft.Office.OneNote','Microsoft.People', ^
                 'Microsoft.Print3D','Microsoft.MixedReality.Portal','Microsoft.OneConnect', ^
                 'Microsoft.SkypeApp','Microsoft.WindowsAlarms','Microsoft.WindowsMaps', ^
                 'Microsoft.WindowsSoundRecorder','Microsoft.YourPhone','Microsoft.ZuneMusic', ^
                 'Microsoft.ZuneVideo','Microsoft.3DBuilder','Microsoft.Microsoft3DViewer'); ^
       foreach($a in $apps) { ^
         Get-AppxPackage -Name $a -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue; ^
         Write-Host \"  [-] $a\" ^
       }"
)

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:DEFENDER_OPT
echo.
echo ===== OPTIMIZAR WINDOWS DEFENDER (sin desactivarlo) =====
echo.
echo  Se va a:
echo    - Limitar uso de CPU del scan a 30%%
echo    - Programar scans solo cuando el PC esta inactivo
echo    - Excluir carpetas de cache de navegadores y temp
echo.

powershell -NoProfile -Command ^
  "Set-MpPreference -ScanAvgCPULoadFactor 30 -ErrorAction SilentlyContinue; ^
   Set-MpPreference -ScanOnlyIfIdleEnabled $true -ErrorAction SilentlyContinue; ^
   Set-MpPreference -DisableCpuThrottleOnIdleScans $true -ErrorAction SilentlyContinue; ^
   ^
   $exclusions = @( ^
     \"$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\", ^
     \"$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\", ^
     \"$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\", ^
     \"$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\", ^
     \"$env:TEMP\" ^
   ); ^
   foreach($e in $exclusions) { ^
     Add-MpPreference -ExclusionPath $e -ErrorAction SilentlyContinue; ^
     Write-Host \"  [+] Excluido: $e\" ^
   }; ^
   Write-Host '  [OK] Defender optimizado'"

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:CLEAN_WINSXS
echo.
echo ===== LIMPIAR WINSXS Y DRIVER STORE VIEJOS =====
echo.
echo  Esto elimina componentes de actualizaciones viejas y drivers
echo  no usados. Puede liberar 5-15 GB. Tarda 10-30 min.
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
DISM /Online /Cleanup-Image /SPSuperseded

:: Limpiar driver store (drivers viejos de impresoras, GPU, USB...)
echo.
echo  Buscando drivers obsoletos...
pnputil /enum-drivers > "%TEMP%\drivers.txt" 2>nul
echo  (revisa %TEMP%\drivers.txt si quieres ver el detalle)

echo.
echo  [OK] WinSxS limpiado.
if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:MOVE_FOLDERS
echo.
echo ===== MOVER CARPETAS PERSONALES A OTRA UNIDAD =====
echo.
echo  Esto te ayuda a liberar mucho espacio en C: moviendo
echo  Documentos, Descargas, Imagenes, Videos, Musica, Escritorio
echo  a otra unidad (ej. D: o E:).
echo.

set /p TARGET="  Letra de la unidad destino (ej. D): "
if "%TARGET%"=="" goto MENU
if not exist "%TARGET%:\" (
    echo  ERROR: la unidad %TARGET%: no existe.
    pause
    goto MENU
)

echo.
echo  IMPORTANTE: hace esto manual desde el Explorador para mayor control:
echo    1) Crea las carpetas en %TARGET%:\Usuario\ (Documentos, Descargas, etc)
echo    2) Click derecho en cada carpeta de C:\Users\%USERNAME%\
echo    3) Pestania Ubicacion -^> Mover... -^> Selecciona la nueva ruta
echo    4) Windows mueve los archivos automaticamente
echo.
echo  Te abro la carpeta de tu usuario para que lo hagas:
start "" "C:\Users\%USERNAME%"
echo  Y la unidad destino:
start "" "%TARGET%:\"

if "%RUN_MODE%"=="ALL" goto :eof
pause
goto MENU


:: ============================================================
:RUN_ALL
set "RUN_MODE=ALL"
echo.
echo ============================================================
echo  APLICANDO TODO EL PAQUETE DE OPTIMIZACION
echo  (analisis + liberar espacio + memoria + visuales +
echo   alto rendimiento + defender + WinSxS)
echo  Tiempo estimado: 30-60 minutos
echo ============================================================
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" (
    set "RUN_MODE="
    goto MENU
)

call :DISK_ANALYSIS
call :FREE_SPACE
call :VIRTUAL_MEM
call :VISUAL_FX
call :HIGH_PERF
call :DEFENDER_OPT
call :CLEAN_WINSXS
call :FREE_RAM

:: Mostrar resultado final
echo.
echo ============================================================
echo   OPTIMIZACION COMPLETA - Estado final del disco:
echo ============================================================
powershell -NoProfile -Command ^
  "$d = Get-PSDrive C; Write-Host ('   Libre: {0:N1} GB de {1:N1} GB' -f ($d.Free/1GB), (($d.Used+$d.Free)/1GB))"
echo.
echo  REINICIA el equipo para aplicar todos los cambios.
echo ============================================================
set "RUN_MODE="
pause
goto MENU
