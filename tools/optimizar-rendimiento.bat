@echo off
:: ============================================================================
::  OPTIMIZADOR RENDIMIENTO + MEMORIA + ESPACIO EN DISCO
::  Uso: click derecho - Ejecutar como administrador
:: ============================================================================

setlocal EnableDelayedExpansion
title Optimizador Rendimiento + Memoria + Disco
color 0E

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
echo    RENDIMIENTO + MEMORIA + DISCO
echo ============================================================
echo.
echo   [1] Ver espacio en C: (analisis)
echo   [2] Buscar archivos gigantes (^>500 MB)
echo   [3] LIBERAR espacio agresivo en C:
echo   [4] Configurar Memoria Virtual optima
echo   [5] Liberar RAM en uso ahora
echo   [6] Efectos visuales optimizados
echo   [7] Alto Rendimiento + sin throttling
echo   [8] Desactivar features de Windows innecesarios
echo   [9] Optimizar Windows Defender
echo   [A] Limpiar WinSxS (DISM cleanup)
echo   [B] Asistente mover Documentos/Descargas
echo.
echo   [C] APLICAR TODO
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


:DISK_ANALYSIS
echo.
echo === ANALISIS DE ESPACIO EN C: ===
echo.
powershell -NoProfile -Command "$d = Get-PSDrive C; $u = [math]::Round($d.Used/1GB,1); $f = [math]::Round($d.Free/1GB,1); $t = $u + $f; $p = [math]::Round(($d.Used/($d.Used+$d.Free))*100,1); Write-Host ('  Total: ' + $t + ' GB'); Write-Host ('  Usado: ' + $u + ' GB (' + $p + '%%)'); Write-Host ('  Libre: ' + $f + ' GB')"

echo.
echo --- Carpetas mas pesadas en C: (top 15) ---
echo  Calculando (puede tardar 1-2 min, omite OneDrive nube y enlaces)...
powershell -NoProfile -Command "Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object { $s = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::Offline) } | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum; if ($s -eq $null) { $s = 0 }; [PSCustomObject]@{Folder=$_.Name; SizeGB=[math]::Round($s/1GB,2)} } | Sort-Object SizeGB -Descending | Select-Object -First 15 | Format-Table -AutoSize"

echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:BIG_FILES
echo.
echo === ARCHIVOS GRANDES (^>500 MB) ===
echo  Escaneando solo carpetas relevantes (omite OneDrive nube,
echo  enlaces y archivos de sistema). Puede tardar 1-3 min...
echo.
echo  Presiona Ctrl+C en cualquier momento para cancelar (no borra nada).
echo.
powershell -NoProfile -Command "$roots = @(\"$env:USERPROFILE\", 'C:\Program Files', 'C:\Program Files (x86)', 'C:\ProgramData', 'C:\Windows\Temp', 'C:\Windows\Installer'); $results = foreach ($r in $roots) { if (Test-Path $r) { Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Length -gt 500MB) -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and -not ($_.Attributes -band [IO.FileAttributes]::Offline) } } }; $results | Sort-Object Length -Descending | Select-Object @{n='SizeGB';e={[math]::Round($_.Length/1GB,2)}}, FullName -First 30 | Format-Table -AutoSize -Wrap"
echo.
echo  [OK] Busqueda terminada.
if defined RUN_MODE goto :eof
pause
goto MENU


:FREE_SPACE
echo.
echo === LIBERAR ESPACIO AGRESIVO ===
echo.
echo  Se borrara:
echo    - Cache Windows Update
echo    - Drivers antiguos (DISM)
echo    - Windows.old si existe
echo    - Logs y dumps
echo    - Cache Store, WER, DirectX, NVIDIA/AMD
echo    - Archivos .tmp
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

echo  -^> Cache Windows Update...
net stop wuauserv >nul 2>&1
if exist "C:\Windows\SoftwareDistribution\Download" (
    rd /s /q "C:\Windows\SoftwareDistribution\Download" >nul 2>&1
    md "C:\Windows\SoftwareDistribution\Download" >nul 2>&1
)
net start wuauserv >nul 2>&1
echo     OK

echo  -^> Component cleanup (DISM, puede tardar varios min)...
DISM /Online /Cleanup-Image /StartComponentCleanup
echo     OK

echo  -^> Windows.old...
if exist "C:\Windows.old" takeown /F "C:\Windows.old" /R /D S >nul 2>&1
if exist "C:\Windows.old" icacls "C:\Windows.old" /grant administradores:F /T >nul 2>&1
if exist "C:\Windows.old" icacls "C:\Windows.old" /grant administrators:F /T >nul 2>&1
if exist "C:\Windows.old" rd /s /q "C:\Windows.old" >nul 2>&1
if exist "C:\Windows.old" (echo     parcial - quedan restos protegidos) else (echo     OK)

echo  -^> Logs de Windows...
del /f /s /q "C:\Windows\Logs\*.*" >nul 2>&1
del /f /s /q "C:\Windows\Panther\*.log" >nul 2>&1
del /f /s /q "C:\Windows\inf\*.log" >nul 2>&1
echo     OK

echo  -^> Dumps de memoria...
del /f /q "C:\Windows\Minidump\*.*" >nul 2>&1
del /f /q "C:\Windows\memory.dmp" >nul 2>&1
del /f /q "%LOCALAPPDATA%\CrashDumps\*.*" >nul 2>&1
echo     OK

echo  -^> Microsoft Store cache...
if exist "%LOCALAPPDATA%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache" (
    del /f /s /q "%LOCALAPPDATA%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache\*" >nul 2>&1
)
echo     OK

echo  -^> Reportes WER...
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*" >nul 2>&1
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*" >nul 2>&1
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\Temp\*" >nul 2>&1
echo     OK

echo  -^> Shaders DirectX/NVIDIA/AMD...
if exist "%LOCALAPPDATA%\D3DSCache"   rd /s /q "%LOCALAPPDATA%\D3DSCache"   >nul 2>&1
if exist "%LOCALAPPDATA%\NVIDIA\GLCache" rd /s /q "%LOCALAPPDATA%\NVIDIA\GLCache" >nul 2>&1
if exist "%LOCALAPPDATA%\NVIDIA\DXCache" rd /s /q "%LOCALAPPDATA%\NVIDIA\DXCache" >nul 2>&1
if exist "%LOCALAPPDATA%\AMD\DxCache" rd /s /q "%LOCALAPPDATA%\AMD\DxCache" >nul 2>&1
if exist "%LOCALAPPDATA%\AMD\GLCache" rd /s /q "%LOCALAPPDATA%\AMD\GLCache" >nul 2>&1
echo     OK

echo  -^> Cache de iconos y miniaturas...
del /f /s /q "%LOCALAPPDATA%\IconCache.db" >nul 2>&1
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
echo     OK

echo  -^> Delivery Optimization (archivos de updates P2P)...
if exist "C:\Windows\SoftwareDistribution\DeliveryOptimization" (
    del /f /s /q "C:\Windows\SoftwareDistribution\DeliveryOptimization\*" >nul 2>&1
)
echo     OK

echo  -^> Temporales adicionales...
del /f /s /q "%TEMP%\*.*" >nul 2>&1
del /f /s /q "C:\Windows\Temp\*.*" >nul 2>&1
echo     OK

echo.
powershell -NoProfile -Command "$d = Get-PSDrive C; Write-Host ('  Libre ahora: ' + [math]::Round($d.Free/1GB,1) + ' GB de ' + [math]::Round(($d.Used+$d.Free)/1GB,1) + ' GB')"
if defined RUN_MODE goto :eof
pause
goto MENU


:VIRTUAL_MEM
echo.
echo === CONFIGURAR MEMORIA VIRTUAL (PAGEFILE) ===
echo.

:: Detectar RAM en GB via PowerShell (mas confiable)
for /f %%R in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)"') do set RAMGB=%%R

if not defined RAMGB (
    echo  ERROR: no se pudo detectar la RAM.
    pause
    goto MENU
)

echo  RAM detectada: %RAMGB% GB
echo.

:: Calcular pagefile
set PFMIN=4096
set PFMAX=8192
if %RAMGB% LEQ 4 (
    set PFMIN=4096
    set PFMAX=8192
)
if %RAMGB% GEQ 16 (
    set PFMIN=4096
    set PFMAX=8192
)
if %RAMGB% GEQ 32 (
    set PFMIN=2048
    set PFMAX=4096
)

echo  Configuracion recomendada: %PFMIN% MB inicial / %PFMAX% MB maximo
echo.
set /p APPLY="  Aplicar? (S/N): "
if /i not "%APPLY%"=="S" goto MENU

:: Usar PowerShell para configurar pagefile (mas confiable que wmic)
powershell -NoProfile -Command "$cs = Get-CimInstance Win32_ComputerSystem; if ($cs.AutomaticManagedPagefile) { Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile=$false} }; $pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue; if ($pf) { $pf | Remove-CimInstance }; New-CimInstance -ClassName Win32_PageFileSetting -Property @{Name='C:\pagefile.sys'; InitialSize=%PFMIN%; MaximumSize=%PFMAX%} | Out-Null; Write-Host '  [OK] Pagefile configurado'"

echo.
echo  Requiere REINICIO para aplicar.
if defined RUN_MODE goto :eof
pause
goto MENU


:FREE_RAM
echo.
echo === LIBERAR RAM EN USO ===
echo.

powershell -NoProfile -Command "$before = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024; Write-Host ('  RAM disponible ANTES:   ' + [int]$before + ' MB'); $sig = '[DllImport(\"psapi.dll\")] public static extern int EmptyWorkingSet(IntPtr hwProc);'; $type = Add-Type -MemberDefinition $sig -Name Win32 -Namespace Mem -PassThru; $skip = @('System','Idle','Registry','Memory Compression','smss','csrss','wininit','services','lsass','winlogon'); Get-Process | Where-Object { $skip -notcontains $_.Name } | ForEach-Object { try { $null = $type::EmptyWorkingSet($_.Handle) } catch {} }; Start-Sleep -Seconds 2; $after = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024; Write-Host ('  RAM disponible DESPUES: ' + [int]$after + ' MB'); Write-Host ('  Liberado: ' + [int]($after - $before) + ' MB')"

echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:VISUAL_FX
echo.
echo === EFECTOS VISUALES PARA RENDIMIENTO ===
echo.
echo  Desactiva animaciones, sombras, transparencias.
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f >nul

echo  [OK] Aplicado. Cierra sesion para verlo.
if defined RUN_MODE goto :eof
pause
goto MENU


:HIGH_PERF
echo.
echo === ALTO RENDIMIENTO + SIN THROTTLING ===
echo.

powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1

powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 >nul 2>&1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 >nul 2>&1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 >nul 2>&1
powercfg -change -disk-timeout-ac 20 >nul 2>&1
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 >nul 2>&1
powercfg -setactive SCHEME_CURRENT >nul 2>&1

reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f >nul

echo  [OK] Alto Rendimiento + Modo Juego activos.
if defined RUN_MODE goto :eof
pause
goto MENU


:KILL_FEATURES
echo.
echo === DESACTIVAR FEATURES INNECESARIOS ===
echo.
set /p CONFIRM="  Desactivar IE11, WMP legacy, XPS, Telnet? (S/N): "
if /i "%CONFIRM%"=="S" (
    dism /online /disable-feature /featurename:Internet-Explorer-Optional-amd64 /norestart >nul 2>&1
    dism /online /disable-feature /featurename:WindowsMediaPlayer /norestart >nul 2>&1
    dism /online /disable-feature /featurename:Printing-XPSServices-Features /norestart >nul 2>&1
    dism /online /disable-feature /featurename:TelnetClient /norestart >nul 2>&1
    echo  [OK] Features desactivados.
)

echo.
set /p RMAPPS="  Quitar apps preinstaladas (Solitario, Tips, Weather, Xbox)? (S/N): "
if /i "%RMAPPS%"=="S" (
    powershell -NoProfile -Command "$apps = @('Microsoft.MicrosoftSolitaireCollection','Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.BingWeather','Microsoft.BingNews','Microsoft.WindowsFeedbackHub','Microsoft.MicrosoftStickyNotes','Microsoft.People','Microsoft.MixedReality.Portal','Microsoft.SkypeApp','Microsoft.WindowsAlarms','Microsoft.WindowsMaps','Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.3DBuilder','Microsoft.Microsoft3DViewer'); foreach($a in $apps) { Get-AppxPackage -Name $a -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }"
    echo  [OK] Apps quitadas.
)
if defined RUN_MODE goto :eof
pause
goto MENU


:DEFENDER_OPT
echo.
echo === OPTIMIZAR DEFENDER (sin desactivarlo) ===
echo.
powershell -NoProfile -Command "try { Set-MpPreference -ScanAvgCPULoadFactor 30 -ErrorAction Stop; Set-MpPreference -ScanOnlyIfIdleEnabled $true; Set-MpPreference -DisableCpuThrottleOnIdleScans $true; Add-MpPreference -ExclusionPath \"$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\" -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath \"$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\" -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath \"$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\" -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath \"$env:TEMP\" -ErrorAction SilentlyContinue; Write-Host '  [OK] Defender optimizado' } catch { Write-Host '  Defender no disponible o controlado por otro AV' }"
if defined RUN_MODE goto :eof
pause
goto MENU


:CLEAN_WINSXS
echo.
echo === LIMPIAR WINSXS (10-30 min) ===
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

echo  [OK] WinSxS limpio.
if defined RUN_MODE goto :eof
pause
goto MENU


:MOVE_FOLDERS
echo.
echo === MOVER CARPETAS PERSONALES ===
echo.
set /p TARGET="  Letra de unidad destino (ej. D): "
if "%TARGET%"=="" goto MENU
if not exist "%TARGET%:\" (
    echo  ERROR: la unidad %TARGET%: no existe.
    pause
    goto MENU
)

echo.
echo  Para hacerlo seguro, Windows tiene una opcion nativa:
echo    1) Te abro tu carpeta de usuario y la unidad destino
echo    2) Click derecho en Documentos/Descargas/etc
echo    3) Propiedades -^> pestania Ubicacion -^> Mover
echo.
start "" "C:\Users\%USERNAME%"
start "" "%TARGET%:\"
if defined RUN_MODE goto :eof
pause
goto MENU


:RUN_ALL
set "RUN_MODE=1"
echo.
echo  Paquete completo (30-60 min). Continuar?
set /p CONFIRM="  (S/N): "
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

echo.
powershell -NoProfile -Command "$d = Get-PSDrive C; Write-Host ('  Libre final: ' + [math]::Round($d.Free/1GB,1) + ' GB')"
echo.
echo  REINICIA para aplicar todos los cambios.
set "RUN_MODE="
pause
goto MENU
