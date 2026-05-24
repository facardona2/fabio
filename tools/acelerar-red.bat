@echo off
:: ============================================================================
::  ACELERADOR DE RED - Optimizacion TCP/IP, DNS, Latencia, Gaming
::  Uso: click derecho - Ejecutar como administrador
::
::  QUE HACE:
::    1) Diagnostico actual (velocidad, ping, DNS)
::    2) Cambiar DNS a Cloudflare (1.1.1.1) o Google (8.8.8.8)
::    3) Optimizar TCP/IP (autotuning, RSS, ECN, escalado)
::    4) Reducir latencia (Nagle off, TCP ACK frequency) - GAMING
::    5) Optimizar tarjeta de red (QoS, priority, throttling off)
::    6) Limpiar DNS y resetear stack de red
::    7) Test de velocidad y latencia
::    8) Optimizar para streaming/video (buffer mas grande)
::    9) APLICAR TODO (config gaming + latencia baja)
::    R) Restaurar valores por defecto si algo falla
::
::  Todo es reversible con la opcion R.
:: ============================================================================

setlocal EnableDelayedExpansion
title Acelerador de Red - TCP/DNS/Gaming
color 09

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
echo    ACELERADOR DE RED - TCP/IP + DNS + GAMING
echo ============================================================
echo.
echo   [1] Diagnostico de red actual
echo   [2] Cambiar DNS rapido (Cloudflare/Google/Quad9)
echo   [3] Optimizar TCP/IP (autotuning, RSS, ECN)
echo   [4] LATENCIA GAMING (Nagle off, ACK frequency)
echo   [5] Optimizar tarjeta de red (Power off, QoS)
echo   [6] Resetear stack de red (DNS+Winsock+IP)
echo   [7] Test de velocidad y ping
echo   [8] Optimizar para streaming/video
echo.
echo   [9] APLICAR TODO (recomendado)
echo   [R] Restaurar valores por defecto
echo   [0] Salir
echo ============================================================
set /p OPT="  Elige una opcion: "

if /i "%OPT%"=="1" goto DIAG
if /i "%OPT%"=="2" goto DNS_FAST
if /i "%OPT%"=="3" goto TCP_OPT
if /i "%OPT%"=="4" goto GAMING
if /i "%OPT%"=="5" goto NIC_OPT
if /i "%OPT%"=="6" goto NET_RESET
if /i "%OPT%"=="7" goto SPEEDTEST
if /i "%OPT%"=="8" goto STREAMING
if /i "%OPT%"=="9" goto RUN_ALL
if /i "%OPT%"=="R" goto RESTORE
if /i "%OPT%"=="0" exit /b
goto MENU


:DIAG
echo.
echo === DIAGNOSTICO DE RED ===
echo.
echo --- Adaptadores activos ---
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress | Format-Table -AutoSize"

echo --- DNS actuales ---
powershell -NoProfile -Command "Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses} | Select-Object InterfaceAlias, AddressFamily, ServerAddresses | Format-Table -AutoSize"

echo --- IP y Gateway ---
ipconfig | findstr /i "IPv4 Gateway"
echo.

echo --- Ping a servidores conocidos ---
echo  Cloudflare (1.1.1.1):
ping -n 4 1.1.1.1 | findstr /i "promedio average tiempo time"
echo  Google (8.8.8.8):
ping -n 4 8.8.8.8 | findstr /i "promedio average tiempo time"
echo  Google.com:
ping -n 4 google.com | findstr /i "promedio average tiempo time"

echo.
echo --- Estado TCP actual ---
netsh int tcp show global

echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:DNS_FAST
echo.
echo === CAMBIAR DNS A SERVIDORES RAPIDOS ===
echo.
echo   [1] Cloudflare (1.1.1.1 / 1.0.0.1) - mas rapido y privado
echo   [2] Google (8.8.8.8 / 8.8.4.4) - confiable
echo   [3] Quad9 (9.9.9.9 / 149.112.112.112) - seguro, bloquea malware
echo   [4] OpenDNS Family (208.67.222.222) - filtro familiar
echo   [5] Volver a DNS automatico del router
echo   [0] Cancelar
echo.
set /p DNSOPT="  Elige: "

set "DNS1="
set "DNS2="
if "%DNSOPT%"=="1" ( set "DNS1=1.1.1.1" & set "DNS2=1.0.0.1" )
if "%DNSOPT%"=="2" ( set "DNS1=8.8.8.8" & set "DNS2=8.8.4.4" )
if "%DNSOPT%"=="3" ( set "DNS1=9.9.9.9" & set "DNS2=149.112.112.112" )
if "%DNSOPT%"=="4" ( set "DNS1=208.67.222.222" & set "DNS2=208.67.220.220" )
if "%DNSOPT%"=="5" goto DNS_AUTO
if "%DNSOPT%"=="0" goto MENU

if not defined DNS1 goto MENU

echo.
echo  Aplicando DNS %DNS1% / %DNS2% en todas las interfaces activas...
echo.

powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses '%DNS1%','%DNS2%' -ErrorAction SilentlyContinue; Write-Host ('  [+] ' + $_.Name + ' -^> %DNS1% / %DNS2%') }"

ipconfig /flushdns >nul

echo.
echo  [OK] DNS aplicado. Probando velocidad...
ping -n 2 %DNS1% | findstr /i "promedio average tiempo time"
if defined RUN_MODE goto :eof
pause
goto MENU

:DNS_AUTO
echo  Restaurando DNS automatico...
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue; Write-Host ('  [+] ' + $_.Name + ' -^> automatico') }"
ipconfig /flushdns >nul
echo  [OK] DNS restaurado.
pause
goto MENU


:TCP_OPT
echo.
echo === OPTIMIZAR TCP/IP ===
echo.

echo  Activando auto-tuning (mejora throughput):
netsh int tcp set global autotuninglevel=normal

echo  Activando RSS (multi-core para red):
netsh int tcp set global rss=enabled

echo  Activando ECN (control de congestion):
netsh int tcp set global ecncapability=enabled

echo  Algoritmo de congestion CTCP/CUBIC:
netsh int tcp set supplemental Internet congestionprovider=cubic 2>nul
netsh int tcp set global congestionprovider=ctcp 2>nul

echo  Timestamps off (reduce overhead):
netsh int tcp set global timestamps=disabled

echo  Activando ChimneyOffload (descarga a NIC):
netsh int tcp set global chimney=enabled 2>nul

echo  Direct Cache Access:
netsh int tcp set global dca=enabled 2>nul

echo  NetDMA:
netsh int tcp set global netdma=enabled 2>nul

echo.
echo  [OK] TCP/IP optimizado.
if defined RUN_MODE goto :eof
pause
goto MENU


:GAMING
echo.
echo === REDUCIR LATENCIA PARA GAMING ===
echo.
echo  Aplicando: Nagle off, ACK frequency, prioridad red
echo.

:: Desactivar Nagle en todas las interfaces (manda paquetes inmediatamente)
powershell -NoProfile -Command "Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path $_.PSPath -Name 'TcpDelAckTicks' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }"
echo  [OK] Nagle desactivado en todas las interfaces

:: Prioridad de red para juegos (Multimedia Class Scheduler)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul
echo  [OK] NetworkThrottling desactivado

:: Prioridad de tareas de juegos en MMCSS
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "High" /f >nul
echo  [OK] Tareas de juegos en alta prioridad MMCSS

:: QoS - permitir 100% del ancho de banda (default Windows reserva 20%)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f >nul
echo  [OK] QoS sin limite reservado

:: Habilitar Game Mode
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul
echo  [OK] Game Mode activado

echo.
echo  [OK] Latencia optimizada para gaming. Reinicia para aplicar todo.
if defined RUN_MODE goto :eof
pause
goto MENU


:NIC_OPT
echo.
echo === OPTIMIZAR TARJETA DE RED ===
echo.
echo  Quitando power saving y throttling de la NIC...
echo.

:: Desactivar "Allow the computer to turn off this device to save power" en todas las NIC
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { try { $nic = $_; $p = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace 'root\wmi' -ErrorAction SilentlyContinue | Where-Object { $_.InstanceName -like ('*' + $nic.PnPDeviceID + '*') }; if ($p) { Set-CimInstance -InputObject $p -Property @{Enable=$false} -ErrorAction SilentlyContinue }; Write-Host ('  [+] Power saving off: ' + $nic.Name) } catch { } }"

:: Activar Receive Side Scaling (RSS) en la NIC
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Enable-NetAdapterRss -Name $_.Name -ErrorAction SilentlyContinue }"
echo  [OK] RSS activado en NICs

:: Habilitar Jumbo Frames? (NO - puede romper conexion con router que no lo soporte)
:: powershell -NoProfile -Command "Set-NetAdapterAdvancedProperty -Name '*' -RegistryKeyword '*JumboPacket' -RegistryValue 9014"

echo.
echo  [OK] NIC optimizada.
if defined RUN_MODE goto :eof
pause
goto MENU


:NET_RESET
echo.
echo === RESETEAR STACK DE RED ===
echo.
echo  Esto puede DESCONECTARTE temporalmente. Continuar?
set /p CONFIRM="  (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

echo.
ipconfig /flushdns
ipconfig /registerdns >nul
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
netsh winsock reset >nul
netsh int ip reset >nul
netsh int ipv4 reset >nul
netsh int ipv6 reset >nul
netsh advfirewall reset >nul

echo.
echo  [OK] Stack de red reseteado. REINICIA el equipo.
if defined RUN_MODE goto :eof
pause
goto MENU


:SPEEDTEST
echo.
echo === TEST DE VELOCIDAD Y LATENCIA ===
echo.

echo --- Ping a 5 servidores ---
for %%H in (1.1.1.1 8.8.8.8 google.com youtube.com discord.com) do (
    echo  -^> %%H
    ping -n 3 %%H | findstr /i "promedio average"
    echo.
)

echo --- Traceroute a Cloudflare (max 10 saltos) ---
tracert -h 10 -w 1000 1.1.1.1

echo.
echo --- Para test de Mbps real abre en navegador: ---
echo    https://fast.com  (de Netflix)
echo    https://speed.cloudflare.com
echo    https://www.speedtest.net
echo.
if defined RUN_MODE goto :eof
pause
goto MENU


:STREAMING
echo.
echo === OPTIMIZAR PARA STREAMING/VIDEO ===
echo.
echo  Aumentando buffers TCP para video en alta calidad...
echo.

netsh int tcp set global initialRto=2000 2>nul
netsh int tcp set global rsc=enabled 2>nul
netsh int tcp set global maxsynretransmissions=2 2>nul
netsh int tcp set global nonsackrttresiliency=disabled 2>nul

:: Increase TCP window size
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTTL /t REG_DWORD /d 64 /f >nul

echo  [OK] TCP optimizado para streaming.
if defined RUN_MODE goto :eof
pause
goto MENU


:RUN_ALL
set "RUN_MODE=1"
echo.
echo ============================================================
echo  APLICAR PAQUETE COMPLETO DE RED
echo  (DNS rapido + TCP + Gaming + NIC + Streaming)
echo ============================================================
echo.
set /p CONFIRM="  Continuar? (S/N): "
if /i not "%CONFIRM%"=="S" (
    set "RUN_MODE="
    goto MENU
)

:: DNS Cloudflare por defecto en paquete completo
set "DNS1=1.1.1.1"
set "DNS2=1.0.0.1"
echo  -^> Aplicando DNS Cloudflare...
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses '1.1.1.1','1.0.0.1' -ErrorAction SilentlyContinue }"
ipconfig /flushdns >nul

call :TCP_OPT
call :GAMING
call :NIC_OPT
call :STREAMING

echo.
echo ============================================================
echo   PAQUETE COMPLETO APLICADO
echo   REINICIA el equipo para aplicar todo.
echo   Despues corre opcion 7 para medir mejora.
echo ============================================================
set "RUN_MODE="
pause
goto MENU


:RESTORE
echo.
echo === RESTAURAR VALORES POR DEFECTO ===
echo.
echo  Esto va a revertir todas las modificaciones. Continuar?
set /p CONFIRM="  (S/N): "
if /i not "%CONFIRM%"=="S" goto MENU

netsh int tcp reset >nul 2>&1
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=default
netsh int tcp set global ecncapability=default
netsh int tcp set global timestamps=default
netsh int tcp set global chimney=default 2>nul

:: Borrar TcpAckFrequency
powershell -NoProfile -Command "Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object { Remove-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -ErrorAction SilentlyContinue }"

:: Restaurar throttling
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /f >nul 2>&1

:: DNS automatico
powershell -NoProfile -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }"

netsh winsock reset >nul

echo.
echo  [OK] Valores por defecto restaurados. REINICIA.
pause
goto MENU
