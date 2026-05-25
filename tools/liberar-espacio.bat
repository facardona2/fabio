@echo off
:: ============================================================================
::  LIBERAR ESPACIO - version minima a prueba de fallos
::  Cada comando en su linea, sin bloques complejos. NO se cierra solo.
::  Uso: click derecho - Ejecutar como administrador
:: ============================================================================

title Liberar Espacio en C:
color 0E

:: Auto-elevacion
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ============================================================
echo    LIBERAR ESPACIO EN C:  (version segura)
echo ============================================================
echo.
echo  Estado actual del disco:
powershell -NoProfile -Command "$d = Get-PSDrive C; Write-Host ('   Libre: ' + [math]::Round($d.Free/1GB,1) + ' GB de ' + [math]::Round(($d.Used+$d.Free)/1GB,1) + ' GB')"
echo.
echo  Voy a borrar caches y temporales (no toca tus archivos).
echo.
pause

echo.
echo [1] Temporales del usuario...
del /f /s /q "%TEMP%\*.*" >nul 2>&1
echo     listo

echo [2] Temporales de Windows...
del /f /s /q "C:\Windows\Temp\*.*" >nul 2>&1
echo     listo

echo [3] Prefetch...
del /f /s /q "C:\Windows\Prefetch\*.*" >nul 2>&1
echo     listo

echo [4] Logs de Windows...
del /f /s /q "C:\Windows\Logs\*.*" >nul 2>&1
del /f /s /q "C:\Windows\Panther\*.log" >nul 2>&1
echo     listo

echo [5] Dumps de memoria y crashes...
del /f /q "C:\Windows\Minidump\*.*" >nul 2>&1
del /f /q "C:\Windows\memory.dmp" >nul 2>&1
del /f /q "%LOCALAPPDATA%\CrashDumps\*.*" >nul 2>&1
echo     listo

echo [6] Reportes de error (WER)...
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*" >nul 2>&1
del /f /s /q "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*" >nul 2>&1
echo     listo

echo [7] Cache de iconos y miniaturas...
del /f /s /q "%LOCALAPPDATA%\IconCache.db" >nul 2>&1
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
echo     listo

echo [8] Shaders DirectX / NVIDIA / AMD...
if exist "%LOCALAPPDATA%\D3DSCache" rd /s /q "%LOCALAPPDATA%\D3DSCache" >nul 2>&1
if exist "%LOCALAPPDATA%\NVIDIA\GLCache" rd /s /q "%LOCALAPPDATA%\NVIDIA\GLCache" >nul 2>&1
if exist "%LOCALAPPDATA%\NVIDIA\DXCache" rd /s /q "%LOCALAPPDATA%\NVIDIA\DXCache" >nul 2>&1
if exist "%LOCALAPPDATA%\AMD\DxCache" rd /s /q "%LOCALAPPDATA%\AMD\DxCache" >nul 2>&1
echo     listo

echo [9] Cache de Windows Update...
net stop wuauserv >nul 2>&1
if exist "C:\Windows\SoftwareDistribution\Download" rd /s /q "C:\Windows\SoftwareDistribution\Download" >nul 2>&1
md "C:\Windows\SoftwareDistribution\Download" >nul 2>&1
net start wuauserv >nul 2>&1
echo     listo

echo [10] Delivery Optimization (updates P2P)...
if exist "C:\Windows\SoftwareDistribution\DeliveryOptimization" del /f /s /q "C:\Windows\SoftwareDistribution\DeliveryOptimization\*" >nul 2>&1
echo     listo

echo [11] Papelera de reciclaje...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo     listo

echo [12] Windows.old (instalacion anterior)...
if exist "C:\Windows.old" takeown /F "C:\Windows.old" /R /D S >nul 2>&1
if exist "C:\Windows.old" icacls "C:\Windows.old" /grant administradores:F /T >nul 2>&1
if exist "C:\Windows.old" icacls "C:\Windows.old" /grant administrators:F /T >nul 2>&1
if exist "C:\Windows.old" rd /s /q "C:\Windows.old" >nul 2>&1
echo     listo

echo.
echo ============================================================
echo  Limpiando componentes viejos de Windows (DISM)...
echo  Esto tarda 5-20 min. NO cierres la ventana, es normal.
echo ============================================================
DISM /Online /Cleanup-Image /StartComponentCleanup

echo.
echo ============================================================
echo   TERMINADO. Estado final del disco:
echo ============================================================
powershell -NoProfile -Command "$d = Get-PSDrive C; Write-Host ('   Libre ahora: ' + [math]::Round($d.Free/1GB,1) + ' GB de ' + [math]::Round(($d.Used+$d.Free)/1GB,1) + ' GB')"
echo.
echo   Si liberaste poco, reinicia y vuelve a correr este script.
echo ============================================================
echo.
pause
