@echo off
:: ============================================================================
::  IRAN VPN SERVER PROBE CLIENT  v4.0
::  Run this on Windows PC INSIDE IRAN to test if your foreign server works
::  Tests: raw TCP, TLS handshake, DNS, traceroute — WITHOUT any VPN/proxy
::  Author: novinresaneh.co | Based on iAghapour research Apr 2026
:: ============================================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ── Colors ──────────────────────────────────────────────────────────────────
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "WHITE=[97m"
set "DIM=[90m"
set "BOLD=[1m"
set "RESET=[0m"

title Iran VPN Server Probe Client v4.0

cls
echo %CYAN%
echo  ============================================================
echo   IRAN VPN SERVER PROBE CLIENT  v4.0
echo   Tests your server from INSIDE Iran - No VPN needed
echo  ============================================================
echo %RESET%
echo  %YELLOW%IMPORTANT: Close all VPN/proxy apps before running!%RESET%
echo  %DIM%This tool needs raw Iranian network to give accurate results%RESET%
echo.

:: ── Check for admin ──────────────────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  %YELLOW%[!] Not running as admin - some tests may be limited%RESET%
    echo  %DIM%    For best results, right-click and "Run as Administrator"%RESET%
    echo.
)

:: ── Check if VPN is active (detect proxy settings) ──────────────────────────
echo  %CYAN%[*] Checking for active VPN/proxy...%RESET%
set "PROXY_ACTIVE=0"

:: Check system proxy
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| find "ProxyEnable"') do (
    if "%%a"=="0x1" set "PROXY_ACTIVE=1"
)

:: Check for common VPN processes
for %%p in (v2rayN.exe v2ray.exe xray.exe clash.exe openvpn.exe wireGuard.exe hiddify.exe) do (
    tasklist /fi "imagename eq %%p" 2>nul | find /i "%%p" >nul
    if not errorlevel 1 (
        echo  %YELLOW%[!] Active VPN process detected: %%p%RESET%
        set "PROXY_ACTIVE=1"
    )
)

if "%PROXY_ACTIVE%"=="1" (
    echo  %RED%[!] WARNING: VPN/Proxy appears to be active!%RESET%
    echo  %RED%    Results will NOT reflect real Iran network conditions%RESET%
    echo  %YELLOW%    Close all VPN apps and press any key to continue, or Ctrl+C to exit%RESET%
    pause >nul
) else (
    echo  %GREEN%[OK] No active VPN/proxy detected - testing with raw Iran network%RESET%
)
echo.

:: ── Get current IP (should be Iran IP) ───────────────────────────────────────
echo  %CYAN%[*] Detecting your current IP address...%RESET%
set "MY_IP="
for /f "delims=" %%a in ('curl -s --max-time 5 https://api.ipify.org 2^>nul') do set "MY_IP=%%a"
if not defined MY_IP (
    for /f "delims=" %%a in ('curl -s --max-time 5 http://checkip.amazonaws.com 2^>nul') do set "MY_IP=%%a"
)
if defined MY_IP (
    echo  %GREEN%[OK] Your IP: %MY_IP%%RESET%
    :: Detect if it's Iranian IP
    for /f "delims=" %%a in ('curl -s --max-time 5 "https://ipinfo.io/%MY_IP%/country" 2^>nul') do set "MY_COUNTRY=%%a"
    if "!MY_COUNTRY!"=="IR" (
        echo  %GREEN%[OK] Confirmed: You are on Iranian network (IR)%RESET%
    ) else (
        echo  %YELLOW%[!] Your IP appears to be outside Iran (!MY_COUNTRY!) - results may not reflect Iran conditions%RESET%
    )
) else (
    echo  %YELLOW%[!] Could not detect IP - proceeding anyway%RESET%
)
echo.

:: ── Get server details ────────────────────────────────────────────────────────
echo  %BOLD%%WHITE%Enter your foreign server details:%RESET%
echo.
set /p "SERVER_IP=  Server IP address: "
if not defined SERVER_IP (
    echo  %RED%[Error] Server IP is required%RESET%
    pause
    exit /b 1
)

set /p "SERVER_PORTS=  Ports to test (e.g. 443 80 53): "
if not defined SERVER_PORTS set "SERVER_PORTS=443 80"

set /p "PROBE_PORT=  Probe port (for reverse probe, press Enter to skip): "

echo.
echo  %CYAN%[*] Starting comprehensive Iran connectivity test for %SERVER_IP%...%RESET%
echo  %DIM%  Tests run WITHOUT proxy to measure real Iran network conditions%RESET%
echo.

:: Initialize results
set "TOTAL_TESTS=0"
set "PASSED_TESTS=0"
set "CRITICAL_PASS=0"

:: ── TEST 1: ICMP Ping ─────────────────────────────────────────────────────────
echo  %YELLOW%━━━ TEST 1: ICMP Ping ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%RESET%
set /a TOTAL_TESTS+=1
ping -n 4 -w 3000 %SERVER_IP% >nul 2>&1
if %errorlevel% equ 0 (
    :: Get actual RTT
    for /f "tokens=*" %%a in ('ping -n 4 -w 3000 %SERVER_IP% 2^>nul ^| findstr "Average"') do set "PING_LINE=%%a"
    echo  %GREEN%[PASS] ICMP Ping: Server is reachable (raw ICMP)%RESET%
    echo  %DIM%        %PING_LINE%%RESET%
    set /a PASSED_TESTS+=1
) else (
    echo  %YELLOW%[WARN] ICMP Ping: Failed - Iran commonly blocks ICMP to foreign IPs%RESET%
    echo  %DIM%        This is normal - VPN still works even when ping fails%RESET%
)
echo.

:: ── TEST 2: TCP Port connectivity ─────────────────────────────────────────────
echo  %YELLOW%━━━ TEST 2: TCP Port Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%RESET%
set "PORT_443_OK=0"
set "PORT_80_OK=0"

for %%p in (%SERVER_PORTS%) do (
    set /a TOTAL_TESTS+=1
    :: PowerShell TCP test
    set "PS_CMD=powershell -NoProfile -NonInteractive -Command "
    set "PS_CMD=!PS_CMD!(New-Object System.Net.Sockets.TcpClient).Connect('%SERVER_IP%',%%p); Write-Output 'CONNECTED'" 
    
    :: Use curl as TCP test (more reliable in Iran)
    curl -s --max-time 8 --connect-timeout 6 "http://%SERVER_IP%:%%p" -o nul 2>nul
    set "TCP_STATUS=%errorlevel%"
    
    :: curl exit code 0=success, 7=refused, 6=cant resolve, 28=timeout, 35=ssl
    if "!TCP_STATUS!"=="0" (
        echo  %GREEN%[PASS] Port %%p: TCP Connected - OPEN from Iran!%RESET%
        set /a PASSED_TESTS+=1
        if "%%p"=="443" set "PORT_443_OK=1"
        if "%%p"=="80" set "PORT_80_OK=1"
        set /a CRITICAL_PASS+=1
    ) else if "!TCP_STATUS!"=="7" (
        echo  %GREEN%[PASS] Port %%p: Connection Refused (port reachable, service not running)%RESET%
        set /a PASSED_TESTS+=1
        if "%%p"=="443" set "PORT_443_OK=1"
        set /a CRITICAL_PASS+=1
    ) else if "!TCP_STATUS!"=="35" (
        echo  %GREEN%[PASS] Port %%p: SSL/TLS handshake reached - REACHABLE from Iran!%RESET%
        set /a PASSED_TESTS+=1
        if "%%p"=="443" set "PORT_443_OK=1"
        set /a CRITICAL_PASS+=1
    ) else if "!TCP_STATUS!"=="28" (
        echo  %RED%[FAIL] Port %%p: TIMEOUT - Likely blocked by Iran DPI%RESET%
    ) else (
        echo  %RED%[FAIL] Port %%p: Blocked or unreachable (code: !TCP_STATUS!)%RESET%
    )
)
echo.

:: ── TEST 3: TLS Handshake (Reality-specific) ─────────────────────────────────
echo  %YELLOW%━━━ TEST 3: TLS/HTTPS Handshake ━━━━━━━━━━━━━━━━━━━━━━━━━━━%RESET%
set /a TOTAL_TESTS+=1
curl -s --max-time 10 -k "https://%SERVER_IP%:443" -o nul -w "%%{http_code}" 2>nul >"%TEMP%\iran_probe_tls.txt"
set /p TLS_CODE=<"%TEMP%\iran_probe_tls.txt"

if "%TLS_CODE%"=="200" (
    echo  %GREEN%[PASS] TLS Handshake: SUCCESSFUL - Port 443 fully accessible!%RESET%
    set /a PASSED_TESTS+=1
    set /a CRITICAL_PASS+=1
) else if not "%TLS_CODE%"=="" (
    echo  %GREEN%[PASS] TLS/HTTPS reached (code: %TLS_CODE%) - Server accessible via HTTPS!%RESET%
    set /a PASSED_TESTS+=1
    set /a CRITICAL_PASS+=1
) else (
    echo  %RED%[FAIL] TLS Handshake: Cannot establish - possible DPI interference%RESET%
    echo  %DIM%        Try enabling Fragment in v2rayN config if using Reality%RESET%
)
echo.

:: ── TEST 4: DNS from this machine ────────────────────────────────────────────
echo  %YELLOW%━━━ TEST 4: DNS Resolver Test (server as DNS) ━━━━━━━━━━━━━━%RESET%
set /a TOTAL_TESTS+=1
nslookup google.com %SERVER_IP% >"%TEMP%\iran_probe_dns.txt" 2>&1
findstr /i "Address" "%TEMP%\iran_probe_dns.txt" | findstr /v "%SERVER_IP%" >nul 2>&1
if not errorlevel 1 (
    echo  %GREEN%[PASS] DNS: Server resolves DNS - MasterDNS tunnel will work!%RESET%
    set /a PASSED_TESTS+=1
    set /a CRITICAL_PASS+=1
) else (
    echo  %YELLOW%[INFO] DNS: Server not yet set as DNS resolver (normal before MasterDNS install)%RESET%
)
echo.

:: ── TEST 5: Traceroute / Path analysis ───────────────────────────────────────
echo  %YELLOW%━━━ TEST 5: Route Analysis (Iran → Server) ━━━━━━━━━━━━━━━━━%RESET%
echo  %DIM%  Running tracert (this takes ~30 seconds)...%RESET%
set "ROUTE_FILE=%TEMP%\iran_probe_route.txt"
tracert -h 15 -w 2000 -d %SERVER_IP% > "%ROUTE_FILE%" 2>&1

:: Count hops and detect routing
set "HOP_COUNT=0"
set "LAST_HOP="
for /f "tokens=1,2,3,4,5" %%a in ('findstr /r "^  [0-9]" "%ROUTE_FILE%"') do (
    set /a HOP_COUNT+=1
    set "LAST_HOP=%%e"
)

type "%ROUTE_FILE%" | findstr /r "^  [0-9]" | head -12 >nul 2>&1

:: Show last 8 hops
echo  %DIM%  Last hops in path:%RESET%
set "SHOW_NEXT=0"
for /f "delims=" %%a in ('type "%ROUTE_FILE%"') do (
    echo  %DIM%  %%a%RESET%
)

if %HOP_COUNT% geq 5 (
    echo  %GREEN%[PASS] Route established: %HOP_COUNT% hops detected%RESET%
    set /a PASSED_TESTS+=1
) else (
    echo  %YELLOW%[INFO] Route analysis limited (common for filtered paths)%RESET%
)
echo.

:: ── TEST 6: Speed/Latency measurement ─────────────────────────────────────────
echo  %YELLOW%━━━ TEST 6: Latency Measurement ━━━━━━━━━━━━━━━━━━━━━━━━━━━%RESET%
set "LATENCY_MS=0"
set "PROBE_START=%TIME%"

:: Measure with curl timing
curl -s --max-time 10 -k -o nul -w "%%{time_connect}|%%{time_total}" "https://%SERVER_IP%:443" 2>nul >"%TEMP%\iran_timing.txt"
set /p TIMING=<"%TEMP%\iran_timing.txt"
if defined TIMING (
    for /f "tokens=1,2 delims=|" %%a in ("%TIMING%") do (
        set "CONNECT_TIME=%%a"
        set "TOTAL_TIME=%%b"
    )
    if defined CONNECT_TIME (
        :: Convert to ms (rough)
        echo  %GREEN%[INFO] Connection time: !CONNECT_TIME!s | Total: !TOTAL_TIME!s%RESET%
        set /a PASSED_TESTS+=1
    )
)
echo.

:: ── TEST 7: Reverse Probe (if probe port specified) ───────────────────────────
if defined PROBE_PORT (
    echo  %YELLOW%━━━ TEST 7: Reverse Probe Connection ━━━━━━━━━━━━━━━━━━━━━%RESET%
    echo  %DIM%  Connecting to probe listener on server port %PROBE_PORT%...%RESET%

    set "ISP_INFO=%MY_COUNTRY%"
    if defined MY_IP set "ISP_INFO=%MY_COUNTRY%|ip=%MY_IP%"

    :: Build probe payload
    set "PROBE_DATA=IRAN_PROBE|v=4|isp=%MY_COUNTRY%|ip=%MY_IP%|lat=%LATENCY_MS%|ts=%DATE% %TIME%"

    :: Send probe data to server
    echo %PROBE_DATA%>"%TEMP%\probe_data.txt"
    curl -s --max-time 10 --data-binary "@%TEMP%\probe_data.txt" "http://%SERVER_IP%:%PROBE_PORT%" >"%TEMP%\probe_response.txt" 2>&1

    set /p PROBE_RESP=<"%TEMP%\probe_response.txt"
    if "!PROBE_RESP!" neq "" (
        echo "!PROBE_RESP!" | findstr "IRAN_VPN_PROBE_OK" >nul 2>&1
        if not errorlevel 1 (
            echo  %GREEN%[PASS] Reverse probe SUCCESSFUL - Server confirmed your connection!%RESET%
            set /a PASSED_TESTS+=1
            set /a CRITICAL_PASS+=1
        ) else (
            echo  %GREEN%[PASS] Response received from server (connection working!)%RESET%
            set /a PASSED_TESTS+=1
        )
    ) else (
        echo  %YELLOW%[INFO] No probe response - server may not be listening on %PROBE_PORT%%RESET%
        echo  %DIM%       Run: bash iran-server-tester-v4.sh --probe-server=%PROBE_PORT% on your server%RESET%
    )
    echo.
)

:: ── Generate final verdict ────────────────────────────────────────────────────
echo  %CYAN%╔════════════════════════════════════════════════════════════╗%RESET%
echo  %CYAN%║                    IRAN CONNECTIVITY VERDICT              ║%RESET%
echo  %CYAN%╚════════════════════════════════════════════════════════════╝%RESET%
echo.
echo  %WHITE%Server: %SERVER_IP%%RESET%
echo  %WHITE%Tests passed: %PASSED_TESTS% / %TOTAL_TESTS%%RESET%
echo.

if %CRITICAL_PASS% geq 2 (
    echo  %GREEN%%BOLD%  ✅ VERDICT: SERVER IS REACHABLE FROM IRAN!%RESET%
    echo  %GREEN%  Port 443 accessible → VLESS/Reality/WS+TLS will work%RESET%
    echo  %GREEN%  Proceed with installing 3X-UI on your server%RESET%
    echo.
    echo  %CYAN%  Recommended install command (run on your server):%RESET%
    echo  %CYAN%  bash ^<(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)%RESET%
) else if %CRITICAL_PASS% equ 1 (
    echo  %YELLOW%%BOLD%  ⚠️ VERDICT: PARTIAL ACCESS — Limited connectivity%RESET%
    echo  %YELLOW%  Some ports work, some blocked by DPI%RESET%
    echo  %YELLOW%  Try: DNS tunnel (MasterDNS) as primary method%RESET%
    echo  %YELLOW%  Or: Change server to Hetzner Finland%RESET%
) else (
    echo  %RED%%BOLD%  ❌ VERDICT: SERVER NOT REACHABLE FROM IRAN%RESET%
    echo  %RED%  All ports blocked — this server will NOT work from Iran%RESET%
    echo  %RED%  Recommended: Change to Hetzner Finland (hetzner.com)%RESET%
)

echo.
echo  %DIM%══════════════════════════════════════════════════════════════%RESET%
echo  %DIM%  Iran VPN Server Probe Client v4.0%RESET%
echo  %DIM%  For best results: disable ALL VPN/proxy before running%RESET%
echo  %DIM%  آزادی اینترنت حق همه مردم ایران است%RESET%
echo  %DIM%══════════════════════════════════════════════════════════════%RESET%
echo.

:: ── Save results to file ──────────────────────────────────────────────────────
set "RESULT_FILE=%USERPROFILE%\Desktop\iran-probe-result-%DATE:/=-%-%TIME::=-%_clean.txt"
set "RESULT_FILE=%RESULT_FILE: =_%"
set "RESULT_FILE=%USERPROFILE%\Desktop\iran-probe-result.txt"

echo Iran VPN Server Probe Results v4.0 > "%RESULT_FILE%"
echo Date: %DATE% %TIME% >> "%RESULT_FILE%"
echo Server: %SERVER_IP% >> "%RESULT_FILE%"
echo Your IP: %MY_IP% (%MY_COUNTRY%) >> "%RESULT_FILE%"
echo Tests Passed: %PASSED_TESTS%/%TOTAL_TESTS% >> "%RESULT_FILE%"
echo Critical Tests Passed: %CRITICAL_PASS% >> "%RESULT_FILE%"
echo. >> "%RESULT_FILE%"
if %CRITICAL_PASS% geq 2 (
    echo VERDICT: SERVER REACHABLE FROM IRAN >> "%RESULT_FILE%"
) else (
    echo VERDICT: SERVER NOT RELIABLY REACHABLE >> "%RESULT_FILE%"
)

echo  %GREEN%[*] Results saved to: %RESULT_FILE%%RESET%
echo.
pause
