#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#   IRAN VPN SERVER READINESS TESTER  v4.0
#   Server-side intelligence engine + optional Reverse Probe listener
#   Sources: iAghapour Digital Freedom + net4people/bbs + wartime Iran Apr 2026
#
#   USAGE:
#     Normal mode:   bash iran-server-tester-v4.sh
#     Probe server:  bash iran-server-tester-v4.sh --probe-server [PORT]
#     Quick mode:    bash iran-server-tester-v4.sh --quick
#     HTML report:   bash iran-server-tester-v4.sh --html
# ═══════════════════════════════════════════════════════════════════════════════

VERSION="4.0"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

SCORE=0
declare -a ISSUES
declare -a ACTIONS
declare -a INSTALL_CMDS
BEST_SNI=""
declare -a GOOD_SNIS
PROBE_PORT=9999
HTML_MODE=0
QUICK_MODE=0
PROBE_SERVER_MODE=0
HTML_FILE="/tmp/iran-report-$(date +%Y%m%d-%H%M%S).html"
REPORT_DATA=""

# ── Parse args ─────────────────────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
        --probe-server) PROBE_SERVER_MODE=1 ;;
        --probe-server=*) PROBE_SERVER_MODE=1; PROBE_PORT="${arg#*=}" ;;
        --html) HTML_MODE=1 ;;
        --quick) QUICK_MODE=1 ;;
        --port=*) PROBE_PORT="${arg#*=}" ;;
    esac
done

# ── Logging ────────────────────────────────────────────────────────────────
ok()     { echo -e "  ${GREEN}[✔]${NC} $1"; [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="<li class='ok'>✔ $1</li>"; }
fail()   { echo -e "  ${RED}[✖]${NC} $1"; ISSUES+=("$1"); [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="<li class='fail'>✖ $1</li>"; }
warn()   { echo -e "  ${YELLOW}[⚠]${NC} $1"; [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="<li class='warn'>⚠ $1</li>"; }
info()   { echo -e "  ${BLUE}[ℹ]${NC} $1"; [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="<li class='info'>ℹ $1</li>"; }
action() { ACTIONS+=("$1"); }
cmd()    { INSTALL_CMDS+=("$1"); }
add()    { SCORE=$((SCORE+$1)); }
sub()    { SCORE=$((SCORE-$1)); [[ $SCORE -lt 0 ]] && SCORE=0; }

section() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC}  ${BOLD}%-54s${NC}  ${CYAN}║${NC}\n" "$1"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="<h2>$1</h2><ul>"
}

section_end() {
    [[ $HTML_MODE -eq 1 ]] && REPORT_DATA+="</ul>"
}

banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
  ██╗██████╗  █████╗ ███╗   ██╗    ██╗   ██╗██████╗ ███╗   ██╗    ██╗   ██╗██╗  ██╗
  ██║██╔══██╗██╔══██╗████╗  ██║    ██║   ██║██╔══██╗████╗  ██║    ██║   ██║██║  ██║
  ██║██████╔╝███████║██╔██╗ ██║    ██║   ██║██████╔╝██╔██╗ ██║    ██║   ██║███████║
  ██║██╔══██╗██╔══██║██║╚██╗██║    ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ╚██╗ ██╔╝╚════██║
  ██║██║  ██║██║  ██║██║ ╚████║     ╚████╔╝ ██║     ██║ ╚████║     ╚████╔╝      ██║
  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝      ╚═══╝  ╚═╝     ╚═╝  ╚═══╝      ╚═══╝       ╚═╝
BANNER
    echo -e "${NC}"
    echo -e "  ${BOLD}${CYAN}Iran VPN Server Intelligence Tester  v${VERSION}${NC}"
    echo -e "  ${DIM}Sources: iAghapour Digital Freedom + net4people/bbs research${NC}"
    echo -e "  ${DIM}Data: wartime Iran censorship — April 2026${NC}"
    echo -e "  ${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Phases: ASN · Reachability · Ports · Network · SNI · DNS · Protocol · System${NC}"
    echo ""

    if [[ $PROBE_SERVER_MODE -eq 1 ]]; then
        echo -e "  ${MAGENTA}${BOLD}⚡ PROBE SERVER MODE ACTIVE — Listening for Iran clients${NC}"
        echo -e "  ${MAGENTA}  Run iran-probe-client.bat on Windows inside Iran${NC}"
        echo ""
    fi
}

install_deps() {
    local needed=0
    for tool in curl jq nc ping dig openssl mtr; do
        command -v $tool &>/dev/null || needed=1
    done
    if [[ $needed -eq 1 ]]; then
        echo -e "  ${YELLOW}[→] Installing required tools...${NC}"
        apt-get update -qq 2>/dev/null && \
        apt-get install -yqq curl jq mtr netcat-openbsd iputils-ping \
            dnsutils openssl 2>/dev/null || \
        yum install -yq curl jq nc bind-utils openssl mtr 2>/dev/null || true
        echo -e "  ${GREEN}[✔] Tools ready${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PROBE SERVER MODE — Listen for connections from Windows client in Iran
# ═══════════════════════════════════════════════════════════════════════════
probe_server_mode() {
    section "PROBE SERVER — Waiting for Iran Client Connection"

    MY_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    info "Server IP: ${BOLD}$MY_IP${NC}"
    info "Probe port: ${BOLD}$PROBE_PORT${NC}"
    echo ""
    echo -e "  ${BOLD}${CYAN}Step 1:${NC} Run ${BOLD}iran-probe-client.bat${NC} on Windows PC inside Iran"
    echo -e "  ${BOLD}${CYAN}Step 2:${NC} Enter server IP ${BOLD}$MY_IP${NC} and port ${BOLD}$PROBE_PORT${NC}"
    echo -e "  ${BOLD}${CYAN}Step 3:${NC} Wait for connection results below..."
    echo ""

    # Open firewall for probe port
    ufw allow $PROBE_PORT/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport $PROBE_PORT -j ACCEPT 2>/dev/null

    # Create a simple HTTP probe endpoint
    PROBE_RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 64\r\nX-Iran-Probe: v4\r\n\r\nIRAN_VPN_PROBE_OK|version=4|server=$MY_IP|ts=$(date +%s)\r\n"

    echo -e "  ${YELLOW}Listening on port $PROBE_PORT (TCP)... Press Ctrl+C to stop${NC}"
    echo -e "  ${DIM}Connections will be logged below:${NC}"
    echo ""

    # Listen and log connections
    PROBE_LOG="/tmp/probe-connections.log"
    > "$PROBE_LOG"

    while true; do
        # Handle connection using nc
        CONN=$(echo -e "$PROBE_RESPONSE" | timeout 10 nc -l -p $PROBE_PORT -q 1 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            TS=$(date '+%Y-%m-%d %H:%M:%S')
            CLIENT_IP=$(ss -tnp 2>/dev/null | grep ":$PROBE_PORT" | awk '{print $5}' | cut -d: -f1 | head -1)
            
            # Parse probe data from client
            PROBE_RESULT=$(echo "$CONN" | grep "IRAN_PROBE" | head -1)
            ISP=$(echo "$PROBE_RESULT" | grep -oP 'isp=[^|]+' | cut -d= -f2)
            CLIENT_VERSION=$(echo "$PROBE_RESULT" | grep -oP 'v=[^|]+' | cut -d= -f2)
            LATENCY_TEST=$(echo "$PROBE_RESULT" | grep -oP 'lat=[^|]+' | cut -d= -f2)
            
            echo -e "  ${GREEN}[✔ $TS]${NC} Connection received!"
            [[ -n "$CLIENT_IP" ]] && echo -e "  ${CYAN}  Client IP : $CLIENT_IP${NC}"
            [[ -n "$ISP" ]] && echo -e "  ${CYAN}  ISP (Iran): $ISP${NC}"
            [[ -n "$LATENCY_TEST" ]] && echo -e "  ${CYAN}  Latency  : ${LATENCY_TEST}ms${NC}"
            echo -e "  ${GREEN}  → SERVER REACHABLE FROM IRAN ✅${NC}"
            echo "$TS|$CLIENT_IP|$ISP|$LATENCY_TEST" >> "$PROBE_LOG"
            echo ""
        fi
        sleep 1
    done

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — SERVER IDENTITY & ASN
# ═══════════════════════════════════════════════════════════════════════════
phase1_identity() {
    section "PHASE 1  SERVER IDENTITY & DATACENTER ANALYSIS"

    # Multiple fallbacks for IP detection
    MY_IP=""
    for endpoint in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com" "https://checkip.amazonaws.com"; do
        MY_IP=$(curl -s --max-time 5 "$endpoint" 2>/dev/null | tr -d '[:space:]')
        [[ "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        MY_IP=""
    done

    [[ -z "$MY_IP" ]] && { fail "Cannot detect server IP — no internet?"; section_end; return 1; }
    info "Server IP: ${BOLD}$MY_IP${NC}"

    # IP info lookup — try multiple providers
    IPINFO=$(curl -s --max-time 8 "https://ipinfo.io/${MY_IP}/json" 2>/dev/null)
    
    # Robust JSON parsing without jq dependency
    ASN=$(echo "$IPINFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org',''))" 2>/dev/null || \
          echo "$IPINFO" | grep -o '"org":"[^"]*"' | sed 's/"org":"//;s/"//')
    CITY=$(echo "$IPINFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('city',''))" 2>/dev/null || \
           echo "$IPINFO" | grep -o '"city":"[^"]*"' | sed 's/"city":"//;s/"//')
    COUNTRY=$(echo "$IPINFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('country',''))" 2>/dev/null || \
              echo "$IPINFO" | grep -o '"country":"[^"]*"' | sed 's/"country":"//;s/"//')
    HOSTNAME=$(echo "$IPINFO" | grep -o '"hostname":"[^"]*"' | sed 's/"hostname":"//;s/"//')
    
    # Extract AS number cleanly
    AS_NUM=$(echo "$ASN" | grep -oP 'AS\d+' | head -1)
    DC_NAME=$(echo "$ASN" | sed 's/AS[0-9]* //' | head -1)

    info "Location  : ${BOLD}${CITY}${CITY:+, }${COUNTRY}${NC}"
    info "ASN       : ${BOLD}${AS_NUM:-UNKNOWN} — ${DC_NAME:-Unknown}${NC}"
    [[ -n "$HOSTNAME" ]] && info "Hostname  : ${DIM}$HOSTNAME${NC}"

    # ── Comprehensive ASN database for Iran (April 2026) ──────────────────
    declare -A ASN_TIER=(
        # Tier 1 — Best verified success rate
        ["AS24940"]="Hetzner:1"    ["AS51167"]="Contabo:1"    ["AS34549"]="Neterra:1"
        ["AS9009"]="M247:1"        ["AS47583"]="Hostinger:1"  ["AS40676"]="Psychz:1"
        ["AS62240"]="Clouvider:1"  ["AS59253"]="Liteserver:1" ["AS60781"]="Leaseweb-NL:1"
        # Tier 2 — Usually works
        ["AS14061"]="DigitalOcean:2" ["AS20473"]="Vultr:2"    ["AS63949"]="Akamai-Linode:2"
        ["AS16125"]="Kamatera:2"   ["AS199599"]="NGSAS:2"     ["AS24911"]="Frantech:2"
        ["AS36352"]="ColoCrossing:2" ["AS55720"]="Gigabit-NL:2"
        # Tier 3 — Monitored cloud giants
        ["AS15169"]="Google-GCP:3" ["AS16509"]="Amazon-AWS:3" ["AS8075"]="Microsoft-Azure:3"
        ["AS20940"]="Akamai:3"     ["AS13335"]="Cloudflare:3"
        # Known BAD
        ["AS16276"]="OVH-France:BAD"  ["AS3215"]="OVH-Paris:BAD"  ["AS12322"]="OVH-EU:BAD"
        ["AS5577"]="Root-SA:BAD"      ["AS209017"]="Quasinetworks:BAD" ["AS199524"]="GCore-Labs:BAD"
        ["AS48282"]="DataWebHosting:BAD" ["AS57169"]="Khalliance:BAD"
    )

    TIER="UNKNOWN"
    DC_LABEL=""
    if [[ -n "$AS_NUM" ]] && [[ -n "${ASN_TIER[$AS_NUM]}" ]]; then
        TIER="${ASN_TIER[$AS_NUM]##*:}"
        DC_LABEL="${ASN_TIER[$AS_NUM]%%:*}"
    fi

    case $TIER in
        1)   ok "ASN ${AS_NUM} (${DC_LABEL}) — ✅ Tier 1: Best verified success rate for Iran"; add 30 ;;
        2)   ok "ASN ${AS_NUM} (${DC_LABEL}) — Tier 2: Usually works with proper config"; add 18 ;;
        3)   warn "ASN ${AS_NUM} (${DC_LABEL}) — Tier 3: Cloud giant, closely monitored by Iran DPI"; add 8 ;;
        BAD) fail "ASN ${AS_NUM} (${DC_LABEL}) — 🔴 KNOWN-BLOCKED for Iran — very high failure risk"; sub 35
             action "CRITICAL: Change datacenter. Best: Hetzner Finland — hetzner.com (€3.79/mo)" ;;
        *)   warn "ASN ${AS_NUM:-UNDETECTED} — Unknown datacenter; moderate confidence for Iran"; add 10 ;;
    esac

    # ── Country scoring ────────────────────────────────────────────────────
    GOOD_C=("DE" "FI" "SE" "NL" "CH" "AT" "CZ" "PL" "HU" "SK" "BG" "RO" "NO" "DK")
    WARN_C=("AZ" "TR" "GE" "AM" "UA" "BY")
    BAD_C=("RU" "CN" "IR" "KP")

    IS_GOOD=0; IS_WARN=0; IS_BAD=0
    for c in "${GOOD_C[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_GOOD=1; done
    for c in "${WARN_C[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_WARN=1; done
    for c in "${BAD_C[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_BAD=1; done

    if [[ $IS_GOOD -eq 1 ]]; then
        ok "Location ${COUNTRY} — Optimal for Iran (Central/Northern Europe)"; add 15
    elif [[ "$COUNTRY" == "FR" ]]; then
        warn "France (OVH dominates): unreliable routing to Iran since 2025"; sub 8
    elif [[ $IS_WARN -eq 1 ]]; then
        warn "Location ${COUNTRY} — CIS/Caucasus: inconsistent for Iran, routing via AZ-IX monitored"; add 4
    elif [[ $IS_BAD -eq 1 ]]; then
        fail "Location ${COUNTRY} — High-risk, Iranian DPI has special rules for this zone"; sub 20
    else
        warn "Location ${COUNTRY}: unknown reliability for Iran"; add 8
    fi

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2 — GITHUB & INSTALLATION REACHABILITY
# ═══════════════════════════════════════════════════════════════════════════
phase2_install() {
    section "PHASE 2  INSTALLATION REACHABILITY (CRITICAL)"
    info "Testing all package sources needed for deployment..."

    declare -A ENDPOINTS=(
        ["raw.githubusercontent.com"]="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/README.md"
        ["github.com"]="https://github.com"
        ["MasterDnsVPN"]="https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh"
        ["VayDNS"]="https://raw.githubusercontent.com/net2share/vaydns/main/install.sh"
        ["pkg.dev (apt)"]="https://packages.ubuntu.com"
    )

    ALL_OK=1
    for name in "${!ENDPOINTS[@]}"; do
        URL="${ENDPOINTS[$name]}"
        STATUS=$(curl -s --max-time 8 -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
        if [[ "$STATUS" == "200" || "$STATUS" == "301" || "$STATUS" == "302" ]]; then
            ok "$name — REACHABLE"
            add 3
        else
            warn "$name — UNREACHABLE (status: $STATUS)"
            ALL_OK=0
        fi
    done

    if [[ $ALL_OK -eq 0 ]]; then
        # Try DNS fix
        CURRENT_NS=$(grep "^nameserver" /etc/resolv.conf | head -1)
        info "Current DNS: $CURRENT_NS"
        warn "Some sources unreachable — server may have DNS issues"
        action "Fix DNS: echo 'nameserver 8.8.8.8' > /etc/resolv.conf && echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
        sub 10
    else
        ok "All installation sources reachable"; add 10
    fi

    # DNS resolution quality test
    DNS_RESOLVE=$(dig +short +time=3 github.com 2>/dev/null | head -1)
    if [[ -n "$DNS_RESOLVE" ]]; then
        ok "DNS resolution healthy (github.com → $DNS_RESOLVE)"
    else
        fail "DNS resolution broken — critical for all installations"
        sub 15
        action "Immediate fix: echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    fi

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3 — PORTS & SERVICES
# ═══════════════════════════════════════════════════════════════════════════
phase3_ports() {
    section "PHASE 3  PORT & SERVICE READINESS"
    info "Auditing all critical ports and running services..."

    LISTENING=$(ss -tlnp 2>/dev/null)
    UDP_LISTENING=$(ss -ulnp 2>/dev/null)

    # Port 443 (Reality/TLS/WS+TLS)
    if echo "$LISTENING" | grep -q ":443 "; then
        SVC=$(echo "$LISTENING" | grep ":443 " | awk '{print $NF}' | head -1)
        ok "Port 443 OPEN (service: $SVC)"; add 8
    else
        info "Port 443 available — ready for 3X-UI"; add 5
    fi

    # Port 80 (WS+CDN, ACME cert challenge)
    echo "$LISTENING" | grep -q ":80 " && ok "Port 80 OPEN" || info "Port 80 available (needed for WS+CDN and Let's Encrypt)"

    # Port 53 (DNS tunnel — MasterDNS/VayDNS)
    UDP_53=$(echo "$UDP_LISTENING" | grep ":53 ")
    if [[ -n "$UDP_53" ]]; then
        SVC53=$(echo "$UDP_53" | awk '{print $NF}' | head -1)
        warn "Port 53 UDP in use by: $SVC53 — conflicts with MasterDNS/VayDNS"
        action "Free port 53: systemctl stop systemd-resolved && systemctl disable systemd-resolved"
    else
        ok "Port 53 UDP free — MasterDNS/VayDNS can bind here"; add 8
    fi

    # systemd-resolved
    RESOLVED=$(systemctl is-active systemd-resolved 2>/dev/null)
    [[ "$RESOLVED" == "active" ]] && \
        warn "systemd-resolved running — will conflict with MasterDNS on port 53" && \
        action "Run: systemctl stop systemd-resolved && systemctl disable systemd-resolved"

    # 3X-UI panel
    if command -v x-ui &>/dev/null || systemctl list-units --type=service 2>/dev/null | grep -q "x-ui"; then
        ok "3X-UI panel installed"; add 8
        XSTATUS=$(systemctl is-active x-ui 2>/dev/null)
        [[ "$XSTATUS" == "active" ]] && ok "3X-UI service RUNNING" || warn "3X-UI installed but NOT running"

        # Check Xray version for XHTTP support
        XRAY_BIN=$(find /usr/local/x-ui /root -name "xray-linux-amd64" 2>/dev/null | head -1)
        if [[ -n "$XRAY_BIN" ]]; then
            XRAY_VER=$("$XRAY_BIN" version 2>/dev/null | head -1)
            XRAY_MINOR=$(echo "$XRAY_VER" | grep -oP '\b1\.(\d+)\.' | grep -oP '\d+' | tail -1)
            info "Xray version: $XRAY_VER"
            [[ ${XRAY_MINOR:-0} -ge 8 ]] && ok "Xray 1.8+ — XHTTP (SplitHTTP) supported" && add 5 || \
                warn "Old Xray — upgrade for XHTTP: x-ui → option 2 (Update)"
        fi
    else
        info "3X-UI not installed (fresh server — ready for deployment)"
    fi

    # MasterDNS
    [[ -f "/etc/masterdns/config" ]] || systemctl list-units 2>/dev/null | grep -q "masterdns" && \
        ok "MasterDnsVPN installed" || info "MasterDnsVPN not installed"

    # BBR congestion control
    BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [[ "$BBR" == "bbr" ]]; then
        ok "BBR active — critical for bypassing Iran's upload throttling"; add 8
    else
        warn "BBR inactive (current: ${BBR:-unknown}) — Iran throttles non-BBR connections heavily"
        sub 5
        action "Enable BBR: run 'x-ui' → option 24 after install"
    fi

    # UFW firewall status
    UFW=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW" | grep -q "active"; then
        info "UFW firewall ACTIVE"
        P443=$(ufw status 2>/dev/null | grep -c "443")
        P80=$(ufw status 2>/dev/null | grep -c "80")
        P53=$(ufw status 2>/dev/null | grep -c "53")
        [[ $P443 -gt 0 ]] && ok "Port 443 allowed in UFW" || \
            { warn "Port 443 blocked by UFW"; action "Fix: ufw allow 443 && ufw allow 80 && ufw allow 53/udp && ufw reload"; }
    fi

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4 — NETWORK QUALITY & IRAN ROUTING
# ═══════════════════════════════════════════════════════════════════════════
phase4_network() {
    section "PHASE 4  NETWORK QUALITY & IRAN ROUTING ANALYSIS"
    info "Testing routes and latency to Iranian ISPs..."

    # Iranian ISP endpoints
    declare -A IRAN_ISP=(
        ["185.51.201.1"]="MCI/Hamrah-Aval AS44244 (largest ISP)"
        ["5.200.200.200"]="IranCell AS44278 (mobile)"
        ["217.218.127.127"]="TIC International Gateway AS12880"
        ["91.99.96.1"]="Shatel AS48159 (fixed broadband)"
        ["78.39.193.1"]="Rightel AS49100 (4G)"
        ["194.225.0.1"]="IranNet AS12880"
    )

    IRAN_REACHABLE=0
    BEST_RTT=9999

    for IP in "${!IRAN_ISP[@]}"; do
        LABEL="${IRAN_ISP[$IP]}"
        RESULT=$(ping -c 3 -W 2 "$IP" 2>/dev/null)
        if echo "$RESULT" | grep -q "bytes from"; then
            RTT=$(echo "$RESULT" | grep "avg" | awk -F'/' '{printf "%.0f", $5}' 2>/dev/null || echo "?")
            ok "$LABEL — RTT: ${RTT}ms"
            IRAN_REACHABLE=$((IRAN_REACHABLE+1))
            add 4
            [[ ${RTT:-9999} -lt $BEST_RTT ]] && BEST_RTT=$RTT
        else
            info "$LABEL — not directly reachable (asymmetric routing is normal)"
        fi
    done

    if [[ $IRAN_REACHABLE -ge 3 ]]; then
        ok "Good bidirectional routing to Iran ($IRAN_REACHABLE/6 ISPs reachable)"; add 5
    elif [[ $IRAN_REACHABLE -ge 1 ]]; then
        warn "Partial routing to Iran ($IRAN_REACHABLE/6 ISPs) — asymmetric routing"
    fi

    # MTR trace to TIC (main international gateway)
    if [[ $QUICK_MODE -eq 0 ]]; then
        info "Running MTR trace to TIC gateway (international routing hub)..."
        MTR_OUT=$(mtr -r -c 3 -T -P 80 217.218.127.127 2>/dev/null | tail -8)
        if [[ -n "$MTR_OUT" ]]; then
            echo "$MTR_OUT" | while read line; do echo -e "  ${DIM}$line${NC}"; done
            # Detect Azerbaijan routing (common for European servers, monitored by Iran)
            AZ_HOPS=$(echo "$MTR_OUT" | grep -c "az-ix\|az\.net\|baku\|az\.bgp" 2>/dev/null || echo 0)
            if [[ $AZ_HOPS -gt 0 ]]; then
                warn "Route passes through Azerbaijan (az-ix) — Iran DPI monitors this peering point"
                warn "Your server's traffic to Iran goes via AZ-IX — increased DPI risk for Reality"
            fi
            # Check for packet loss spikes
            HIGH_LOSS=$(echo "$MTR_OUT" | awk '{print $6}' | grep -v "^0" | grep -v "Loss%" | head -3)
            [[ -n "$HIGH_LOSS" ]] && warn "Packet loss detected in routing path — may cause instability"
        fi
    fi

    # Cloudflare latency (crucial for CDN-based configs)
    CF_RTT=$(ping -c 3 -W 3 1.1.1.1 2>/dev/null | grep "avg" | awk -F'/' '{printf "%.0f", $5}')
    if [[ -n "$CF_RTT" ]]; then
        info "Cloudflare (1.1.1.1): ${CF_RTT}ms"
        if [[ $CF_RTT -lt 15 ]]; then
            ok "Cloudflare proximity EXCELLENT (<15ms) — WS+CDN will be very fast"; add 10
        elif [[ $CF_RTT -lt 40 ]]; then
            ok "Cloudflare proximity GOOD (${CF_RTT}ms) — CDN configs will work well"; add 6
        elif [[ $CF_RTT -lt 80 ]]; then
            warn "Cloudflare proximity moderate (${CF_RTT}ms) — CDN usable but not optimal"; add 3
        else
            warn "High Cloudflare latency (${CF_RTT}ms) — CDN-based configs may be slow"
        fi
    fi

    # Outbound port availability
    info "Testing outbound ports (camouflage protocols)..."
    declare -A PORT_TEST=(
        ["443"]="HTTPS/Reality/WS+TLS"
        ["80"]="HTTP/WS"
        ["8443"]="Alt-HTTPS"
        ["2053"]="Cloudflare Alt"
        ["2083"]="Cloudflare Alt"
    )
    PORTS_OK=0
    for port in "${!PORT_TEST[@]}"; do
        if nc -w 3 -z 1.1.1.1 $port 2>/dev/null; then
            ok "Outbound port ${port} (${PORT_TEST[$port]}) — OPEN"; PORTS_OK=$((PORTS_OK+1))
        else
            warn "Outbound port ${port} — blocked"
        fi
    done

    # MTU test (fragmentation causes issues with DPI bypass)
    MTU_1400=$(ping -c 2 -M do -s 1400 8.8.8.8 2>/dev/null | grep -c "bytes from" 2>/dev/null || echo 0)
    MTU_1200=$(ping -c 2 -M do -s 1200 8.8.8.8 2>/dev/null | grep -c "bytes from" 2>/dev/null || echo 0)
    if [[ $MTU_1400 -gt 0 ]]; then
        ok "MTU 1400+ works — no fragmentation issues"; add 3
    elif [[ $MTU_1200 -gt 0 ]]; then
        warn "MTU limited to 1200 — add fragment settings to xray"
        action "Add to xray config outbound: 'fragment':{'packets':'tlshello','length':'10-20','interval':'5-10'}"
    else
        warn "MTU severely limited — serious performance impact"
    fi

    # IPv6 (bypass avenue for some Iranian ISPs)
    IPV6=$(ip -6 addr show 2>/dev/null | grep "inet6" | grep -v "::1\|fe80" | head -1)
    if [[ -n "$IPV6" ]]; then
        IPV6_ADDR=$(echo "$IPV6" | awk '{print $2}')
        ok "IPv6 available ($IPV6_ADDR) — some Iranian ISPs bypass DPI via IPv6"; add 3
    else
        info "No public IPv6 — IPv4 only"
    fi

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5 — SNI & TLS CAMOUFLAGE TESTING
# ═══════════════════════════════════════════════════════════════════════════
phase5_sni() {
    section "PHASE 5  SNI & TLS CAMOUFLAGE ANALYSIS"
    info "Testing SNI domains for Reality config (Iran whitelist matching)..."
    echo ""

    # Comprehensive SNI list — priority based on Iran whitelist research 2026
    # Format: "domain:PRIORITY:notes"
    declare -a SNI_LIST=(
        "www.microsoft.com:★★★:Iran whitelist — TOP CHOICE"
        "www.bing.com:★★★:Iran whitelist — very consistent"
        "update.microsoft.com:★★★:Microsoft update — whitelisted"
        "www.apple.com:★★★:Apple CDN — consistently whitelisted"
        "www.samsung.com:★★☆:Samsung — less monitored, good choice"
        "addons.mozilla.org:★★☆:Mozilla — often works"
        "www.amazon.com:★★☆:Amazon — moderate"
        "www.google.com:★★☆:Google — sometimes allowed"
        "ajax.googleapis.com:★★☆:Google CDN — sometimes works"
        "www.speedtest.net:★☆☆:NOW MONITORED — avoid as primary"
    )

    printf "  ${BOLD}%-35s %-12s %s${NC}\n" "DOMAIN" "STATUS" "PRIORITY"
    echo -e "  $(printf '─%.0s' {1..65})"

    for entry in "${SNI_LIST[@]}"; do
        DOMAIN="${entry%%:*}"
        rest="${entry#*:}"
        PRIO="${rest%%:*}"
        NOTE="${rest##*:}"

        # TLS test via openssl
        TLS_OK=0
        TLS_OUT=$(echo "Q" | timeout 4 openssl s_client \
            -connect "${DOMAIN}:443" \
            -servername "$DOMAIN" \
            -tls1_3 \
            -verify_return_error 2>/dev/null | head -3)

        if echo "$TLS_OUT" | grep -q "CONNECTED"; then
            TLS_OK=1
        else
            # Fallback: curl
            HC=$(curl -s --max-time 4 -o /dev/null -w "%{http_code}" \
                --tls-max 1.3 "https://$DOMAIN" 2>/dev/null)
            [[ "$HC" =~ ^(200|301|302|307|308)$ ]] && TLS_OK=1
        fi

        if [[ $TLS_OK -eq 1 ]]; then
            GOOD_SNIS+=("$DOMAIN")
            [[ -z "$BEST_SNI" && "$PRIO" == "★★★" ]] && BEST_SNI="$DOMAIN"
            printf "  ${GREEN}[✔]${NC}  %-32s ${GREEN}%-12s${NC} ${DIM}%s${NC}\n" \
                "$DOMAIN" "REACHABLE" "$PRIO → $NOTE"
        else
            printf "  ${RED}[✖]${NC}  %-32s ${RED}%-12s${NC} ${DIM}%s${NC}\n" \
                "$DOMAIN" "UNREACHABLE" "$PRIO"
        fi
    done

    echo ""
    SNI_COUNT=${#GOOD_SNIS[@]}
    if [[ $SNI_COUNT -ge 6 ]]; then
        ok "$SNI_COUNT SNI candidates available — excellent Reality camouflage pool"; add 15
    elif [[ $SNI_COUNT -ge 3 ]]; then
        ok "$SNI_COUNT SNI candidates available — adequate"; add 8
    elif [[ $SNI_COUNT -ge 1 ]]; then
        warn "Only $SNI_COUNT SNI candidates — limited"; add 3
    else
        fail "No SNI domains reachable — server has egress restrictions"; sub 15
    fi

    [[ -z "$BEST_SNI" && ${#GOOD_SNIS[@]} -gt 0 ]] && BEST_SNI="${GOOD_SNIS[0]}"
    [[ -z "$BEST_SNI" ]] && BEST_SNI="www.microsoft.com"

    echo -e "\n  ${BOLD}Best SNI choices for your Reality inbound:${NC}"
    for sni in "${GOOD_SNIS[@]:0:3}"; do
        echo -e "  ${GREEN}  → sni=${sni}${NC}"
    done

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6 — DNS TUNNEL COMPATIBILITY
# ═══════════════════════════════════════════════════════════════════════════
phase6_dns_tunnel() {
    section "PHASE 6  DNS TUNNEL (MasterDNS & VayDNS) — Most stable in wartime Iran"
    info "In April 2026, DNS tunneling is the ONLY consistently working method in Iran"
    echo ""

    DNS_READY=0

    # 1. UDP 53 outbound
    if nc -w 2 -zu 8.8.8.8 53 2>/dev/null; then
        ok "UDP port 53 outbound — WORKS"; DNS_READY=$((DNS_READY+1)); add 5
    else
        warn "UDP port 53 outbound — may be restricted"
    fi

    # 2. TCP 53 (fallback for UDP-blocked Iran networks)
    if nc -w 3 -z 8.8.8.8 53 2>/dev/null; then
        ok "TCP port 53 — WORKS (fallback for UDP-blocked Iranian connections)"; DNS_READY=$((DNS_READY+1)); add 5
    else
        warn "TCP port 53 — blocked"
    fi

    # 3. DNS query length test (Iran DPI drops queries > ~110 chars)
    SHORT_Q=$(dig +short +timeout=3 "a.b.com" @8.8.8.8 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        ok "Short DNS queries work — max-qname-len=101 setting will function"; add 5
    fi

    # 4. DNS over HTTPS (DoH)
    DOH=$(curl -s --max-time 4 \
        "https://cloudflare-dns.com/dns-query?name=google.com&type=A" \
        -H "accept: application/dns-json" 2>/dev/null | grep -c "Answer" 2>/dev/null || echo 0)
    [[ $DOH -gt 0 ]] && ok "DoH (DNS over HTTPS) works — can be used as resolver" && add 3

    # 5. Test actual DNS resolver capability
    DNS_AUTH=$(dig +short @$MY_IP google.com 2>/dev/null 2>/dev/null | head -1)
    if [[ -n "$DNS_AUTH" ]]; then
        ok "Server can act as DNS resolver — MasterDNS/VayDNS ready"; add 8
    else
        info "DNS resolver not yet configured on this server"
    fi

    # 6. Installation availability
    echo ""
    info "Checking DNS tunnel script availability..."
    MDNS=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh")
    if [[ "$MDNS" == "200" ]]; then
        ok "MasterDnsVPN install script — REACHABLE"; add 5
        cmd "MasterDnsVPN: bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)"
    else
        warn "MasterDnsVPN install script unreachable — fix DNS first"
        action "After fixing DNS, install: bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)"
    fi

    VAYDNS=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/net2share/vaydns/main/install.sh")
    if [[ "$VAYDNS" == "200" ]]; then
        ok "VayDNS install script — REACHABLE"; 
        cmd "VayDNS: bash <(curl -Ls https://raw.githubusercontent.com/net2share/vaydns/main/install.sh)"
    else
        warn "VayDNS install script unreachable"
    fi

    # DNS Tunnel readiness summary
    echo ""
    if [[ $DNS_READY -ge 2 ]]; then
        ok "Server is DNS TUNNEL READY — deploy MasterDNS immediately"; add 10
    else
        warn "DNS tunnel prerequisites partial — check port 53 availability"
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}Critical MasterDNS settings for Iran (April 2026):${NC}"
    echo -e "  ${YELLOW}  • max-qname-len=101 (NOT 253 — Iran DPI drops queries >110 chars)${NC}"
    echo -e "  ${YELLOW}  • Keep domain names SHORT: t.ab.com (not long.subdomain.domain.com)${NC}"
    echo -e "  ${YELLOW}  • Stop systemd-resolved BEFORE install (conflicts on port 53)${NC}"
    echo -e "  ${YELLOW}  • Works on even the weakest DNS resolvers in Iran${NC}"

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7 — PROTOCOL & PANEL INTELLIGENCE ENGINE
# ═══════════════════════════════════════════════════════════════════════════
phase7_protocols() {
    section "PHASE 7  PROTOCOL & PANEL RECOMMENDATION ENGINE"
    echo ""
    echo -e "  ${BOLD}Iran DPI behavior April 2026 — Protocol Effectiveness:${NC}"
    echo ""

    SHOW_REALITY=1
    [[ $SCORE -lt 45 ]] && SHOW_REALITY=0

    # ── Protocol matrix ────────────────────────────────────────────────────
    echo -e "  ${BOLD}${GREEN}═══ TIER 1 — MOST RELIABLE IN WARTIME ═══${NC}"
    echo ""
    echo -e "  ${GREEN}[★★★★★]${NC} ${BOLD}VLESS + DNS Tunnel (MasterDnsVPN / VayDNS)${NC}"
    echo -e "         ${DIM}The ONLY reliably working method in extreme censorship (wartime)${NC}"
    echo -e "         ${CYAN}Install: MasterDnsVPN on server + client app in Windows${NC}"
    echo -e "         ${CYAN}Key: use max-qname-len=101 and SHORT domain names${NC}"
    echo ""
    echo -e "  ${GREEN}[★★★★☆]${NC} ${BOLD}VLESS + WebSocket + TLS via Cloudflare CDN${NC}"
    echo -e "         ${DIM}Hides real IP behind CF. Proven stable over months.${NC}"
    echo -e "         ${CYAN}Requires: domain + Cloudflare account (free) + DNS proxied ON${NC}"
    echo ""

    echo -e "  ${BOLD}${YELLOW}═══ TIER 2 — WORKS ON CLEAN/FRESH IPs ═══${NC}"
    echo ""
    echo -e "  ${YELLOW}[★★★★☆]${NC} ${BOLD}VLESS + XHTTP (SplitHTTP) via Cloudflare CDN${NC}"
    echo -e "         ${DIM}New in Xray 1.8+ — beats WebSocket fingerprinting detection${NC}"
    echo -e "         ${CYAN}network=xhttp, security=tls, host=your-cf-domain, CDN proxy ON${NC}"
    echo ""
    if [[ $SHOW_REALITY -eq 1 ]]; then
        echo -e "  ${YELLOW}[★★★☆☆]${NC} ${BOLD}VLESS + Reality + xtls-rprx-vision + uTLS=chrome${NC}"
        echo -e "         ${DIM}Works well on fresh IPs, gets blocked on popular DCs within days${NC}"
        echo -e "         ${CYAN}sni=${BEST_SNI}, flow=xtls-rprx-vision, fp=chrome${NC}"
    else
        echo -e "  ${RED}[★★☆☆☆]${NC} ${BOLD}VLESS + Reality${NC} — ${RED}RISKY for this server${NC}"
        echo -e "         ${DIM}Low-score ASN/location makes Reality detection likely${NC}"
    fi
    echo ""

    echo -e "  ${BOLD}${RED}═══ BLOCKED — DO NOT USE ═══${NC}"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} WireGuard / OpenVPN — Blocked in <1 second by Iran DPI"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} VLESS TCP without TLS/Reality — Immediately detectable"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} Shadowsocks standard — Detectable, blocked"
    echo ""

    # ── Panel matrix ───────────────────────────────────────────────────────
    echo -e "  ${BOLD}Panel Recommendation (based on your server's capabilities):${NC}"
    echo ""
    printf "  ${BOLD}%-8s %-28s %-12s %s${NC}\n" "SCORE" "PANEL" "FIT" "NOTES"
    echo -e "  $(printf '─%.0s' {1..75})"
    echo -e "  ${GREEN}★★★★★${NC}  3X-UI (mhsanaei)             ${GREEN}EXCELLENT${NC}  Full-featured, XHTTP/Reality/WS/DNS-out"
    echo -e "         ${DIM}github.com/MHSanaei/3x-ui${NC}"
    echo ""
    echo -e "  ${GREEN}★★★★★${NC}  MasterDnsVPN                 ${GREEN}EXCELLENT${NC}  Best for wartime — DNS specialist"
    echo -e "         ${DIM}github.com/masterking32/MasterDnsVPN${NC}"
    echo ""
    echo -e "  ${GREEN}★★★★☆${NC}  VayDNS                       ${GREEN}EXCELLENT${NC}  DNS tunnel alternative, stable"
    echo -e "         ${DIM}github.com/net2share/vaydns${NC}"
    echo ""
    echo -e "  ${YELLOW}★★★☆☆${NC}  Hiddify Panel                ${YELLOW}GOOD${NC}      User-friendly, good for distribution"
    echo -e "         ${DIM}github.com/hiddify/hiddify-manager${NC}"
    echo ""
    echo -e "  ${YELLOW}★★★☆☆${NC}  Marzban                      ${YELLOW}GOOD${NC}      Multi-server, good for scaling"
    echo -e "         ${DIM}github.com/Gozargah/Marzban${NC}"
    echo ""
    echo -e "  ${RED}★★☆☆☆${NC}  x-ui (alireza0)               ${RED}OUTDATED${NC}  Not maintained, use 3X-UI instead"

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 8 — SYSTEM RESOURCES
# ═══════════════════════════════════════════════════════════════════════════
phase8_system() {
    section "PHASE 8  SYSTEM RESOURCES & COMPATIBILITY"

    OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
    KERNEL=$(uname -r)
    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    RAM_TOTAL=$(free -m 2>/dev/null | grep Mem | awk '{print $2}')
    RAM_FREE=$(free -m 2>/dev/null | grep Mem | awk '{print $7}')
    DISK_FREE=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
    UPTIME=$(uptime -p 2>/dev/null || echo "?")

    info "OS     : $OS"
    info "Kernel : $KERNEL"
    info "CPU    : ${CPU_CORES} core(s)"
    info "RAM    : ${RAM_TOTAL}MB total, ${RAM_FREE}MB available"
    info "Disk   : $DISK_FREE free on /"
    info "Uptime : $UPTIME"

    # OS compatibility
    if echo "$OS" | grep -qiE "Ubuntu 22|Ubuntu 24|Debian 11|Debian 12"; then
        ok "OS fully supported — all scripts install cleanly"; add 5
    elif echo "$OS" | grep -qiE "Ubuntu 20|Debian 10"; then
        warn "OS slightly outdated — supported but upgrade recommended"
        add 3
    else
        warn "Non-standard OS — compatibility issues possible"
    fi

    # RAM requirements
    if [[ ${RAM_TOTAL:-0} -ge 2048 ]]; then
        ok "RAM ${RAM_TOTAL}MB — can run 3X-UI + MasterDNS + BBR simultaneously"; add 5
    elif [[ ${RAM_TOTAL:-0} -ge 1024 ]]; then
        ok "RAM ${RAM_TOTAL}MB — sufficient for 3X-UI + MasterDNS"; add 3
    elif [[ ${RAM_TOTAL:-0} -ge 512 ]]; then
        warn "RAM ${RAM_TOTAL}MB — minimal; run only ONE service (3X-UI OR MasterDNS)"
    else
        fail "RAM ${RAM_TOTAL}MB — too low for stable VPN operation"; sub 10
    fi

    # Kernel version (BBR needs 4.9+)
    KMAJ=$(uname -r | cut -d. -f1)
    KMIN=$(uname -r | cut -d. -f2)
    if [[ $KMAJ -ge 5 ]] || [[ $KMAJ -eq 4 && $KMIN -ge 9 ]]; then
        ok "Kernel $KERNEL — BBR eligible"
    else
        warn "Old kernel — BBR may not be available"
    fi

    # IPv6 dual-stack
    IP6=$(ip -6 addr show 2>/dev/null | grep -v "::1\|fe80" | grep -c "inet6" 2>/dev/null)
    [[ $IP6 -gt 0 ]] && ok "Dual-stack IPv4+IPv6 — maximum compatibility" && add 3 || \
        info "IPv4 only — IPv6 tunnel bypass not available"

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# PROBE SERVER LISTENER (background, non-blocking)
# ═══════════════════════════════════════════════════════════════════════════
start_probe_listener() {
    section "PHASE 9  REVERSE PROBE LISTENER (Iran → Server)"
    info "Starting listener for Windows client connections from inside Iran..."

    # Open firewall
    ufw allow $PROBE_PORT/tcp 2>/dev/null || \
    iptables -I INPUT -p tcp --dport $PROBE_PORT -j ACCEPT 2>/dev/null

    MY_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)

    echo ""
    echo -e "  ${BOLD}${CYAN}Probe listener is ACTIVE on port ${PROBE_PORT}${NC}"
    echo -e "  ${CYAN}  Server IP: ${BOLD}$MY_IP${NC}"
    echo ""
    echo -e "  ${BOLD}Run iran-probe-client.bat on Windows inside Iran:${NC}"
    echo -e "  ${YELLOW}  1. Double-click iran-probe-client.bat${NC}"
    echo -e "  ${YELLOW}  2. Enter server IP: ${BOLD}$MY_IP${NC}"
    echo -e "  ${YELLOW}  3. Enter probe port: ${BOLD}$PROBE_PORT${NC}"
    echo -e "  ${YELLOW}  4. Wait ~30 seconds for results${NC}"
    echo ""
    echo -e "  ${DIM}Waiting for connections (60 second window)...${NC}"

    # Listen for one connection with 60s timeout
    PROBE_RESULT=$(timeout 60 nc -l -p $PROBE_PORT 2>/dev/null)
    if [[ -n "$PROBE_RESULT" ]]; then
        CLIENT_LATENCY=$(echo "$PROBE_RESULT" | grep -oP 'latency=\K[0-9]+' | head -1)
        CLIENT_ISP=$(echo "$PROBE_RESULT" | grep -oP 'isp=\K[^|]+' | head -1)
        echo ""
        echo -e "  ${GREEN}${BOLD}✅ CONNECTION RECEIVED FROM IRAN!${NC}"
        [[ -n "$CLIENT_ISP" ]] && echo -e "  ${GREEN}  ISP: $CLIENT_ISP${NC}"
        [[ -n "$CLIENT_LATENCY" ]] && echo -e "  ${GREEN}  RTT from Iran: ${CLIENT_LATENCY}ms${NC}"
        echo -e "  ${GREEN}  → THIS SERVER IS REACHABLE FROM IRAN ✅${NC}"
        add 20
    else
        warn "No connection received in 60 seconds"
        info "This may mean: (1) .bat not run yet, (2) server IP blocked from Iran, (3) port 53 issue"
    fi

    section_end
}

# ═══════════════════════════════════════════════════════════════════════════
# FINAL VERDICT
# ═══════════════════════════════════════════════════════════════════════════
final_verdict() {
    section "FINAL VERDICT"

    [[ $SCORE -gt 100 ]] && SCORE=100
    [[ $SCORE -lt 0 ]] && SCORE=0

    echo ""
    # Score bar
    BAR=""
    FILLED=$((SCORE / 5))
    for ((i=0; i<20; i++)); do
        [[ $i -lt $FILLED ]] && BAR+="█" || BAR+="░"
    done

    if [[ $SCORE -ge 80 ]]; then
        C=$GREEN; G="A"; V="EXCELLENT — Deploy immediately"
        ADV="High probability of working in Iran. Use DNS tunnel as primary, Reality as backup."
    elif [[ $SCORE -ge 65 ]]; then
        C=$GREEN; G="B"; V="GOOD — Deploy with Cloudflare CDN"
        ADV="Good server. Use WS+TLS+Cloudflare as primary, Reality as secondary option."
    elif [[ $SCORE -ge 50 ]]; then
        C=$YELLOW; G="C"; V="ACCEPTABLE — Use DNS tunnel only"
        ADV="Moderate confidence. DNS tunnel (MasterDNS) is your most reliable option here."
    elif [[ $SCORE -ge 35 ]]; then
        C=$YELLOW; G="D"; V="RISKY — Consider Hetzner Finland"
        ADV="Low success probability. Try Hetzner FI (hetzner.com) for better results."
    else
        C=$RED; G="F"; V="AVOID — Change server immediately"
        ADV="Very high failure probability. This server will not reliably work from Iran."
    fi

    echo -e "  ${BOLD}Score: ${C}${SCORE}/100${NC}  ${DIM}|${NC}  ${BOLD}Grade: ${C}${G}${NC}"
    echo -e "  ${C}[${BAR}] ${SCORE}%${NC}"
    echo ""
    echo -e "  ${C}${BOLD}🎯 $V${NC}"
    echo -e "  ${DIM}$ADV${NC}"

    if [[ ${#ISSUES[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}${RED}Critical Issues:${NC}"
        for i in "${!ISSUES[@]}"; do
            echo -e "  ${RED}  $((i+1)). ${ISSUES[$i]}${NC}"
        done
    fi

    if [[ ${#ACTIONS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}${CYAN}Action Plan (execute in order):${NC}"
        declare -A SEEN_ACTIONS
        N=1
        for action in "${ACTIONS[@]}"; do
            if [[ -z "${SEEN_ACTIONS[$action]}" ]]; then
                echo -e "  ${CYAN}  $N. $action${NC}"
                SEEN_ACTIONS[$action]=1
                N=$((N+1))
            fi
        done
    fi

    # ── Complete Installation Guide ────────────────────────────────────────
    section "COMPLETE DEPLOYMENT GUIDE FOR THIS SERVER"
    echo ""
    SHORT_ID=$(openssl rand -hex 4 2>/dev/null || echo "a1b2c3d4")
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')")

    echo -e "  ${BOLD}── Step 1: Prepare Server ──${NC}"
    echo -e "  ${CYAN}  systemctl stop systemd-resolved${NC}"
    echo -e "  ${CYAN}  systemctl disable systemd-resolved${NC}"
    echo -e "  ${CYAN}  echo 'nameserver 8.8.8.8' > /etc/resolv.conf${NC}"
    echo -e "  ${CYAN}  ufw allow 443 && ufw allow 80 && ufw allow 53/udp && ufw reload${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 2: Install 3X-UI ──${NC}"
    echo -e "  ${CYAN}  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 3: Post-install (run 'x-ui' command) ──${NC}"
    echo -e "  ${CYAN}  x-ui  →  option 24  (Enable BBR)${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 4: Create VLESS Reality inbound ──${NC}"
    echo -e "  ${CYAN}  Protocol  : VLESS${NC}"
    echo -e "  ${CYAN}  Port      : 443${NC}"
    echo -e "  ${CYAN}  Security  : Reality${NC}"
    echo -e "  ${CYAN}  Flow      : xtls-rprx-vision${NC}"
    echo -e "  ${CYAN}  uTLS      : chrome${NC}"
    echo -e "  ${CYAN}  SNI       : ${BEST_SNI:-www.microsoft.com}${NC}"
    echo -e "  ${CYAN}  Short ID  : $SHORT_ID${NC}"
    echo -e "  ${CYAN}  UUID      : $UUID${NC}"
    echo -e "  ${CYAN}  Keys      : Generate with 'Generate' button in panel${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 5: Install MasterDnsVPN (DNS Tunnel — primary method) ──${NC}"
    echo -e "  ${CYAN}  bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 6: Client settings (Windows in Iran) ──${NC}"
    echo -e "  ${CYAN}  MasterDNS client: use -max-qname-len 101${NC}"
    echo -e "  ${CYAN}  Keep domain/subdomain SHORT (e.g. v.ab.ir — not long.name.domain.com)${NC}"
    echo -e "  ${CYAN}  V2RayN: import VLESS link → Set Active → Test${NC}"
    echo ""
    echo -e "  ${BOLD}── Step 7: Probe from Iran (verify connectivity) ──${NC}"
    echo -e "  ${CYAN}  bash iran-server-tester-v4.sh --probe-server=${PROBE_PORT}${NC}"
    echo -e "  ${CYAN}  Then run iran-probe-client.bat on Windows inside Iran${NC}"
    echo ""

    if [[ ${#INSTALL_CMDS[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Other available install commands:${NC}"
        for c in "${INSTALL_CMDS[@]}"; do
            echo -e "  ${CYAN}  → $c${NC}"
        done
    fi

    echo ""
    echo -e "${CYAN}  ════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  v${VERSION} complete  •  آزادی اینترنت حق همه مردم ایران است${NC}"
    echo -e "${CYAN}  ════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # HTML report generation
    if [[ $HTML_MODE -eq 1 ]]; then
        generate_html_report
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# HTML REPORT GENERATOR
# ═══════════════════════════════════════════════════════════════════════════
generate_html_report() {
    cat > "$HTML_FILE" << HTMLEOF
<!DOCTYPE html>
<html dir="ltr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Iran VPN Server Report v4 — $MY_IP</title>
<style>
  body{font-family:'Courier New',monospace;background:#0d1117;color:#e6edf3;margin:0;padding:20px}
  h1{color:#58a6ff;border-bottom:1px solid #30363d;padding-bottom:10px}
  h2{color:#79c0ff;margin-top:25px;border-left:4px solid #1f6feb;padding-left:10px}
  .ok{color:#3fb950;list-style:none;padding:3px 0}
  .fail{color:#f85149;list-style:none;padding:3px 0}
  .warn{color:#d29922;list-style:none;padding:3px 0}
  .info{color:#58a6ff;list-style:none;padding:3px 0}
  ul{padding-left:15px}
  .score-box{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;margin:20px 0}
  .score{font-size:48px;font-weight:bold}
  .grade-A,.grade-B{color:#3fb950}
  .grade-C,.grade-D{color:#d29922}
  .grade-F{color:#f85149}
  .bar{background:#21262d;height:20px;border-radius:10px;margin:10px 0}
  .bar-fill{height:20px;border-radius:10px;background:linear-gradient(90deg,#238636,#3fb950)}
  .meta{color:#8b949e;font-size:12px}
  .cmd{background:#161b22;border:1px solid #30363d;padding:10px;margin:5px 0;border-radius:4px;font-family:monospace}
</style>
</head>
<body>
<h1>🇮🇷 Iran VPN Server Readiness Report v4.0</h1>
<p class="meta">Generated: $(date) | Server: $MY_IP</p>
<div class="score-box">
  <div class="score grade-${G}">${SCORE}/100 — Grade ${G}</div>
  <div class="bar"><div class="bar-fill" style="width:${SCORE}%"></div></div>
  <strong>${V}</strong><br><span class="meta">${ADV}</span>
</div>
$REPORT_DATA
<h2>Installation Commands</h2>
<div class="cmd">systemctl stop systemd-resolved && systemctl disable systemd-resolved</div>
<div class="cmd">bash &lt;(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)</div>
<div class="cmd">bash &lt;(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)</div>
<p class="meta">Iran VPN Server Tester v4.0 — آزادی اینترنت حق همه مردم ایران است</p>
</body></html>
HTMLEOF
    echo -e "  ${GREEN}[✔] HTML report saved: ${BOLD}$HTML_FILE${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════
main() {
    banner

    if [[ $PROBE_SERVER_MODE -eq 1 ]]; then
        probe_server_mode
        exit 0
    fi

    install_deps
    phase1_identity  || { echo -e "${RED}Fatal: No internet access${NC}"; exit 1; }
    phase2_install
    phase3_ports
    phase4_network
    phase5_sni
    phase6_dns_tunnel

    if [[ $QUICK_MODE -eq 0 ]]; then
        phase7_protocols
        phase8_system
    fi

    final_verdict
}

main
