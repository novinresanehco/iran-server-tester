#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#   IRAN VPN SERVER READINESS TESTER  v3.0
#   Based on real-world Iran wartime censorship data (March-April 2026)
#   Sources: iAghapour Digital Freedom channel + net4people/bbs research
#   Run ON your new foreign server right after purchase
# ═══════════════════════════════════════════════════════════════════════════
# Usage: bash iran-server-tester-v3.sh
# ═══════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

SCORE=0
declare -a ISSUES
declare -a ACTIONS
declare -a INSTALL_CMDS
BEST_SNI=""
declare -a GOOD_SNIS

# ── Logging ────────────────────────────────────────────────────────────────
ok()     { echo -e "  ${GREEN}[✔]${NC} $1"; }
fail()   { echo -e "  ${RED}[✖]${NC} $1"; ISSUES+=("$1"); }
warn()   { echo -e "  ${YELLOW}[⚠]${NC} $1"; }
info()   { echo -e "  ${BLUE}[ℹ]${NC} $1"; }
action() { ACTIONS+=("$1"); }
cmd()    { INSTALL_CMDS+=("$1"); }
add()    { SCORE=$((SCORE+$1)); }
sub()    { SCORE=$((SCORE-$1)); [[ $SCORE -lt 0 ]] && SCORE=0; }

section() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC}  ${BOLD}%-52s${NC}  ${CYAN}║${NC}\n" "$1"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
  ██╗██████╗  █████╗ ███╗   ██╗    ██╗   ██╗██████╗ ███╗   ██╗    ██╗   ██╗██████╗ 
  ██║██╔══██╗██╔══██╗████╗  ██║    ██║   ██║██╔══██╗████╗  ██║    ██║   ██║╚════██╗
  ██║██████╔╝███████║██╔██╗ ██║    ██║   ██║██████╔╝██╔██╗ ██║    ██║   ██║ █████╔╝
  ██║██╔══██╗██╔══██║██║╚██╗██║    ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ╚██╗ ██╔╝ ╚═══██╗
  ██║██║  ██║██║  ██║██║ ╚████║     ╚████╔╝ ██║     ██║ ╚████║     ╚████╔╝ ██████╔╝
  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝      ╚═══╝  ╚═╝     ╚═╝  ╚═══╝      ╚═══╝  ╚═════╝ 
EOF
    echo -e "${NC}"
    echo -e "  ${BOLD}${CYAN}Iran VPN Server Intelligence Tester  v3.0${NC}"
    echo -e "  ${DIM}Data: iAghapour channel + net4people/bbs + wartime Iran research Apr 2026${NC}"
    echo -e "  ${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Analyzing: ASN • IP reputation • Protocol fit • DNS tunnel • Install readiness${NC}"
    echo ""
}

install_deps() {
    local pkg_list="curl jq mtr netcat-openbsd iputils-ping dnsutils openssl"
    local missing=0
    for cmd in curl jq nc ping dig openssl; do
        command -v $cmd &>/dev/null || missing=1
    done
    if [[ $missing -eq 1 ]]; then
        echo -e "  ${YELLOW}[→] Installing required tools...${NC}"
        apt-get update -qq 2>/dev/null && apt-get install -yqq $pkg_list 2>/dev/null || \
        yum install -yq curl jq nc bind-utils openssl 2>/dev/null || true
        echo -e "  ${GREEN}[✔] Tools ready${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — SERVER IDENTITY
# ═══════════════════════════════════════════════════════════════════════════
phase1_identity() {
    section "PHASE 1  SERVER IDENTITY & DATACENTER ANALYSIS"

    MY_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || \
            curl -s --max-time 5 http://ifconfig.me 2>/dev/null || \
            curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null)

    [[ -z "$MY_IP" ]] && { fail "Cannot detect server IP — no internet?"; return 1; }
    info "Server IP: ${BOLD}$MY_IP${NC}"

    # ipinfo lookup
    IPINFO=$(curl -s --max-time 8 "https://ipinfo.io/${MY_IP}/json" 2>/dev/null)
    ASN=$(echo "$IPINFO"     | grep -o '"org":"[^"]*"'      | sed 's/"org":"//;s/"//')
    CITY=$(echo "$IPINFO"    | grep -o '"city":"[^"]*"'     | sed 's/"city":"//;s/"//')
    COUNTRY=$(echo "$IPINFO" | grep -o '"country":"[^"]*"'  | sed 's/"country":"//;s/"//')
    AS_NUM=$(echo "$ASN"     | grep -oP 'AS\d+')
    DC_NAME=$(echo "$ASN"    | sed 's/AS[0-9]* //')

    info "Location  : ${BOLD}$CITY, $COUNTRY${NC}"
    info "ASN       : ${BOLD}$AS_NUM — $DC_NAME${NC}"

    # ── Verified ASN database for Iran (April 2026) ──────────────────────
    # Tier 1 — Best success rate for Iran bypass
    TIER1=("AS24940:Hetzner" "AS51167:Contabo" "AS34549:Neterra" "AS9009:M247" "AS47583:Hostinger" "AS40676:Psychz")
    # Tier 2 — Usually works, occasional blocks
    TIER2=("AS14061:DigitalOcean" "AS20473:Vultr" "AS63949:Linode" "AS16125:Kamatera" "AS199599:NGSAS")
    # Tier 3 — Unpredictable
    TIER3=("AS15169:Google" "AS16509:Amazon" "AS8075:Microsoft" "AS20940:Akamai")
    # Known BAD for Iran
    BAD=("AS16276:OVH-FR" "AS3215:OVH-Paris" "AS12322:OVH-EU" "AS5577:Root" "AS209017:Quasinetworks")
    # BAD location zones
    BAD_COUNTRIES=("RU" "CN" "IR")
    WARN_COUNTRIES=("AZ" "TR" "GE" "AM")  # CIS/Caucasus: sometimes works, unpredictable

    TIER=0
    for entry in "${TIER1[@]}"; do
        [[ "$AS_NUM" == "${entry%%:*}" ]] && TIER=1 && TIER_NAME="${entry##*:}" && break
    done
    for entry in "${TIER2[@]}"; do
        [[ "$AS_NUM" == "${entry%%:*}" ]] && TIER=2 && TIER_NAME="${entry##*:}" && break
    done
    for entry in "${TIER3[@]}"; do
        [[ "$AS_NUM" == "${entry%%:*}" ]] && TIER=3 && TIER_NAME="${entry##*:}" && break
    done
    IS_BAD=0
    for entry in "${BAD[@]}"; do
        [[ "$AS_NUM" == "${entry%%:*}" ]] && IS_BAD=1 && BAD_NAME="${entry##*:}" && break
    done

    if [[ $IS_BAD -eq 1 ]]; then
        fail "ASN ${AS_NUM} (${BAD_NAME}) is in KNOWN-BLOCKED list for Iran — very high failure risk"
        sub 35
        action "CRITICAL: Change datacenter immediately. Recommended: Hetzner Finland (hetzner.com)"
    elif [[ $TIER -eq 1 ]]; then
        ok "ASN ${AS_NUM} (${TIER_NAME}) — Tier 1: verified high success rate for Iran"
        add 30
    elif [[ $TIER -eq 2 ]]; then
        ok "ASN ${AS_NUM} (${TIER_NAME}) — Tier 2: usually works with proper config"
        add 18
    elif [[ $TIER -eq 3 ]]; then
        warn "ASN ${AS_NUM} (${TIER_NAME}) — Tier 3: cloud giant, actively monitored by Iran DPI"
        add 8
    else
        warn "ASN ${AS_NUM} — Unknown datacenter: untested for Iran, moderate confidence"
        add 10
    fi

    # ── Country/Location scoring ──────────────────────────────────────────
    GOOD_COUNTRIES=("DE" "FI" "SE" "NL" "CH" "AT" "CZ" "PL" "HU" "SK")
    IS_GOOD_COUNTRY=0
    IS_BAD_COUNTRY=0
    IS_WARN_COUNTRY=0
    for c in "${GOOD_COUNTRIES[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_GOOD_COUNTRY=1; done
    for c in "${BAD_COUNTRIES[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_BAD_COUNTRY=1; done
    for c in "${WARN_COUNTRIES[@]}"; do [[ "$COUNTRY" == "$c" ]] && IS_WARN_COUNTRY=1; done

    if [[ $IS_GOOD_COUNTRY -eq 1 ]]; then
        ok "Location ${COUNTRY} — Optimal for Iran (Central/Northern Europe)"
        add 15
    elif [[ $IS_WARN_COUNTRY -eq 1 ]]; then
        warn "Location ${COUNTRY} — CIS/Caucasus region: inconsistent results for Iran"
        add 5
    elif [[ "$COUNTRY" == "FR" ]]; then
        warn "France: OVH-dominated routing, historically unreliable for Iran since 2025"
        sub 8
    elif [[ $IS_BAD_COUNTRY -eq 1 ]]; then
        fail "Location ${COUNTRY} — High-risk country for Iran bypass"
        sub 20
    else
        warn "Location ${COUNTRY}: unknown reliability for Iran"
        add 8
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2 — GITHUB & INSTALLATION REACHABILITY (CRITICAL)
# ═══════════════════════════════════════════════════════════════════════════
phase2_install() {
    section "PHASE 2  INSTALLATION REACHABILITY (CRITICAL)"
    info "Testing GitHub and package sources needed for installation..."

    # Test raw.githubusercontent.com (most critical — 3X-UI install script)
    RAW_STATUS=$(curl -s --max-time 8 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/README.md" 2>/dev/null)

    if [[ "$RAW_STATUS" == "200" ]]; then
        ok "raw.githubusercontent.com — REACHABLE (3X-UI install will work)"
        add 15
    else
        fail "raw.githubusercontent.com BLOCKED — 3X-UI install script will FAIL"
        sub 20

        # Try bypass: access via IP instead of domain
        GITHUB_IP=$(dig +short raw.githubusercontent.com 2>/dev/null | head -1)
        if [[ -n "$GITHUB_IP" ]]; then
            ALT=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" \
                -H "Host: raw.githubusercontent.com" "https://$GITHUB_IP/" 2>/dev/null)
            if [[ "$ALT" == "200" || "$ALT" == "301" ]]; then
                warn "raw.githubusercontent.com accessible via IP ($GITHUB_IP) — DNS issue only"
                action "Fix DNS: echo 'nameserver 8.8.8.8' > /etc/resolv.conf && echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
                add 10
            fi
        fi
        action "Alternative install: download 3X-UI .deb from GitHub releases page and upload manually"
    fi

    # Test GitHub main
    GH_STATUS=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" "https://github.com" 2>/dev/null)
    [[ "$GH_STATUS" == "200" ]] && ok "github.com reachable" && add 5 || \
        warn "github.com slow/unreachable — may affect installs"

    # Test MasterDNS install URL
    MDNS=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh" 2>/dev/null)
    [[ "$MDNS" == "200" ]] && ok "MasterDnsVPN install script — REACHABLE" || \
        warn "MasterDnsVPN install script — unreachable (may need manual download)"

    # APT/package manager
    APT_OK=$(apt-get check 2>/dev/null | grep -c "Reading" || echo "0")
    [[ $APT_OK -gt 0 ]] && ok "APT package manager working" || warn "APT issues detected"

    # DNS resolution quality
    DNS_TEST=$(dig +short +time=3 google.com 2>/dev/null | head -1)
    if [[ -n "$DNS_TEST" ]]; then
        ok "DNS resolution working (google.com → $DNS_TEST)"
    else
        fail "DNS resolution broken — cannot resolve hostnames"
        sub 15
        action "Fix DNS: echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3 — PORTS & SERVICES
# ═══════════════════════════════════════════════════════════════════════════
phase3_ports() {
    section "PHASE 3  PORT & SERVICE READINESS"
    info "Auditing ports and services..."

    LISTENING=$(ss -tlnp 2>/dev/null)

    # 443 — critical
    if echo "$LISTENING" | grep -q ":443 "; then
        SVC=$(echo "$LISTENING" | grep ":443 " | awk '{print $NF}' | head -1)
        ok "Port 443 OPEN — service: $SVC"
        add 8
    else
        info "Port 443 available (nothing listening — ready for 3X-UI)"
        add 5
    fi

    # 80 — for WS+CDN
    echo "$LISTENING" | grep -q ":80 " && ok "Port 80 OPEN" || info "Port 80 available (good for WS+CDN)"

    # 53 UDP — for DNS tunnel (MasterDNS, VayDNS)
    UDP_53=$(ss -ulnp 2>/dev/null | grep ":53 ")
    if [[ -n "$UDP_53" ]]; then
        warn "Port 53 UDP already in use — may conflict with MasterDNS/VayDNS"
        SVC53=$(echo "$UDP_53" | awk '{print $NF}' | head -1)
        info "Current service on 53: $SVC53"
        action "If using MasterDNS/VayDNS: stop systemd-resolved first: systemctl stop systemd-resolved"
    else
        ok "Port 53 UDP available — DNS tunnel protocols (MasterDNS, VayDNS) can use it"
        add 8
    fi

    # systemd-resolved conflict check
    RESOLVED=$(systemctl is-active systemd-resolved 2>/dev/null)
    if [[ "$RESOLVED" == "active" ]]; then
        warn "systemd-resolved active — will conflict with MasterDNS/VayDNS on port 53"
        action "Before installing MasterDNS: systemctl stop systemd-resolved && systemctl disable systemd-resolved"
    fi

    # Check existing installations
    X_UI_INSTALLED=0
    MASTERDNS_INSTALLED=0
    if command -v x-ui &>/dev/null || systemctl list-units 2>/dev/null | grep -q "x-ui"; then
        ok "3X-UI panel already installed"
        X_UI_INSTALLED=1
        add 8
        XSTATUS=$(systemctl is-active x-ui 2>/dev/null)
        [[ "$XSTATUS" == "active" ]] && ok "3X-UI running" || warn "3X-UI installed but not running"

        # Xray version check
        XRAY_VER=$(/usr/local/x-ui/bin/xray-linux-amd64 version 2>/dev/null | head -1)
        if [[ -n "$XRAY_VER" ]]; then
            info "Xray version: $XRAY_VER"
            # Check if version supports XHTTP (needs 1.8.0+)
            XRAY_MINOR=$(echo "$XRAY_VER" | grep -oP '1\.(\d+)' | cut -d. -f2)
            [[ ${XRAY_MINOR:-0} -ge 8 ]] && \
                ok "Xray 1.8+ detected — XHTTP (SplitHTTP) supported" && add 5 || \
                warn "Old Xray version — upgrade for XHTTP support: x-ui → option 2"
        fi
    fi

    if [[ -f "/etc/masterdns/config" ]] || systemctl list-units 2>/dev/null | grep -q "masterdns"; then
        ok "MasterDnsVPN already installed"
        MASTERDNS_INSTALLED=1
    fi

    # BBR check
    BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [[ "$BBR" == "bbr" ]]; then
        ok "BBR congestion control ACTIVE — important for Iran throttling bypass"
        add 8
    else
        warn "BBR not active (current: ${BBR:-unknown}) — reduces speed through Iran throttling"
        sub 5
        action "Enable BBR: after installing x-ui, run 'x-ui' → option 24"
    fi

    # UFW check
    UFW=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW" | grep -q "active"; then
        info "UFW firewall active"
        PORTS_ALLOWED=$(ufw status 2>/dev/null | grep -E "^443|^80|^53" | head -5)
        if echo "$UFW" | grep -q "443"; then
            ok "Port 443 allowed in UFW"
        else
            warn "Port 443 may be blocked by UFW"
            action "Open ports: ufw allow 443 && ufw allow 80 && ufw allow 53/udp && ufw reload"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4 — NETWORK QUALITY & IRAN ROUTE
# ═══════════════════════════════════════════════════════════════════════════
phase4_network() {
    section "PHASE 4  NETWORK QUALITY & IRAN ROUTING"
    info "Testing routes and latency relevant to Iran connectivity..."

    # Key Iranian network endpoints
    declare -A IRAN_NETS=(
        ["185.51.201.1"]="MCI/Hamrah-Aval (AS44244)"
        ["5.200.200.200"]="IranCell (AS44278)"
        ["217.218.127.127"]="TIC International Gateway (AS12880)"
        ["91.99.96.1"]="Shatel (AS48159)"
        ["78.39.193.1"]="Rightel (AS49100)"
    )

    IRAN_REACHABLE=0
    declare -A IRAN_RTT

    for IP in "${!IRAN_NETS[@]}"; do
        LABEL="${IRAN_NETS[$IP]}"
        RESULT=$(ping -c 3 -W 2 "$IP" 2>/dev/null)
        if echo "$RESULT" | grep -q "bytes from"; then
            RTT=$(echo "$RESULT" | grep "avg" | awk -F'/' '{printf "%.0f", $5}')
            ok "$LABEL — RTT: ${RTT}ms"
            IRAN_RTT[$IP]=$RTT
            IRAN_REACHABLE=$((IRAN_REACHABLE+1))
            add 5
        else
            info "$LABEL — not directly reachable (asymmetric routing normal)"
        fi
    done

    # MTR to TIC gateway (most important — international gateway)
    info "Running MTR trace to TIC gateway (217.218.127.127)..."
    MTR_RESULT=$(mtr -r -c 3 -T -P 80 217.218.127.127 2>/dev/null | tail -8)
    if [[ -n "$MTR_RESULT" ]]; then
        echo "$MTR_RESULT" | while read line; do
            echo -e "  ${DIM}$line${NC}"
        done
        # Count hops with 100% loss before reaching destination
        LOSSY=$(echo "$MTR_RESULT" | grep "100.0%" | wc -l)
        [[ $LOSSY -gt 3 ]] && warn "Multiple hops dropping — possible routing issue toward Iran"
    fi

    # Cloudflare proximity (for CDN-based configs)
    CF_RTT=$(ping -c 3 -W 3 1.1.1.1 2>/dev/null | grep "avg" | awk -F'/' '{printf "%.0f", $5}')
    if [[ -n "$CF_RTT" ]]; then
        info "Cloudflare (1.1.1.1) latency: ${CF_RTT}ms"
        [[ $CF_RTT -lt 30 ]] && ok "Excellent Cloudflare proximity (<30ms) — CDN configs will be fast" && add 8
        [[ $CF_RTT -ge 30 && $CF_RTT -lt 80 ]] && ok "Good Cloudflare proximity (${CF_RTT}ms)" && add 5
        [[ $CF_RTT -ge 80 ]] && warn "High Cloudflare latency (${CF_RTT}ms) — CDN configs may be slow"
    fi

    # Outbound port tests (important for TLS camouflage)
    info "Testing critical outbound ports..."
    for port in 443 80 8080 8443; do
        if nc -w 3 -z 1.1.1.1 $port 2>/dev/null; then
            ok "Outbound port ${port} — OPEN"
        else
            warn "Outbound port ${port} — blocked (may affect some configs)"
        fi
    done

    # MTU test
    MTU_OK=$(ping -c 2 -M do -s 1400 8.8.8.8 2>/dev/null | grep -c "bytes from" || echo 0)
    if [[ $MTU_OK -gt 0 ]]; then
        ok "MTU 1400 — no fragmentation issues"
        add 3
    else
        warn "MTU issues detected — add Fragment setting in xray config"
        action "In xray outbound, add: 'fragment': {'packets': 'tlshello', 'length': '10-30', 'interval': '10-20'}"
    fi

    # IPv6 check
    IPV6=$(ip -6 addr show 2>/dev/null | grep "inet6" | grep -v "::1" | grep -v "fe80" | head -1)
    if [[ -n "$IPV6" ]]; then
        ok "IPv6 available — can use VLESS over IPv6 (some Iranian ISPs bypass via IPv6)"
        add 3
    else
        info "No public IPv6 — IPv4 only"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5 — SNI & TLS CAMOUFLAGE
# ═══════════════════════════════════════════════════════════════════════════
phase5_sni() {
    section "PHASE 5  SNI & TLS CAMOUFLAGE TESTING"
    info "Testing SNI domains for Reality config (Iran DPI whitelist check)..."
    echo ""

    # SNI list with priority — based on Iran whitelist research April 2026
    # Format: "domain:priority:note"
    SNI_LIST=(
        "www.microsoft.com:HIGH:Iran whitelist — consistently works"
        "www.bing.com:HIGH:Iran whitelist — consistent"
        "www.apple.com:HIGH:Apple CDN — usually whitelisted"
        "addons.mozilla.org:MED:Mozilla — often works"
        "www.speedtest.net:LOW:Popular but now monitored by Iran DPI"
        "www.google.com:MED:Google — sometimes allowed"
        "ajax.googleapis.com:MED:Google CDN — sometimes works"
        "www.samsung.com:MED:Samsung — underused, less monitored"
        "www.amazon.com:MED:Amazon — moderate reliability"
        "update.microsoft.com:HIGH:Microsoft update — usually whitelisted"
    )

    echo -e "  ${BOLD}SNI  DOMAIN                       STATUS        PRIORITY${NC}"
    echo -e "  ────────────────────────────────────────────────────────────"

    for entry in "${SNI_LIST[@]}"; do
        DOMAIN="${entry%%:*}"
        rest="${entry#*:}"
        PRIO="${rest%%:*}"
        NOTE="${rest##*:}"

        # Quick TLS test
        TLS=$(echo "Q" | timeout 4 openssl s_client \
            -connect "${DOMAIN}:443" -servername "$DOMAIN" \
            -verify_return_error 2>/dev/null | head -5)

        if echo "$TLS" | grep -q "CONNECTED"; then
            GOOD_SNIS+=("$DOMAIN")
            [[ -z "$BEST_SNI" && "$PRIO" == "HIGH" ]] && BEST_SNI="$DOMAIN"
            printf "  ${GREEN}[✔]${NC}  %-32s %-14s ${GREEN}%s${NC}\n" \
                "$DOMAIN" "REACHABLE" "$PRIO"
        else
            # Fallback: curl test
            HC=$(curl -s --max-time 4 -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null)
            if [[ "$HC" =~ ^(200|301|302|307|308)$ ]]; then
                GOOD_SNIS+=("$DOMAIN")
                [[ -z "$BEST_SNI" && "$PRIO" == "HIGH" ]] && BEST_SNI="$DOMAIN"
                printf "  ${GREEN}[✔]${NC}  %-32s %-14s ${GREEN}%s${NC}\n" \
                    "$DOMAIN" "REACHABLE" "$PRIO"
            else
                printf "  ${RED}[✖]${NC}  %-32s %-14s ${DIM}%s${NC}\n" \
                    "$DOMAIN" "UNREACHABLE" "$PRIO"
            fi
        fi
    done

    echo ""
    SNI_COUNT=${#GOOD_SNIS[@]}
    if [[ $SNI_COUNT -ge 5 ]]; then
        ok "${SNI_COUNT} SNI candidates available — excellent Reality camouflage options"
        add 12
    elif [[ $SNI_COUNT -ge 2 ]]; then
        ok "${SNI_COUNT} SNI candidates available — adequate"
        add 6
    else
        fail "Too few SNI domains reachable — server may have egress restrictions"
        sub 10
    fi

    [[ -z "$BEST_SNI" && ${#GOOD_SNIS[@]} -gt 0 ]] && BEST_SNI="${GOOD_SNIS[0]}"
    [[ -z "$BEST_SNI" ]] && BEST_SNI="www.microsoft.com"

    echo -e "\n  ${BOLD}Recommended SNI for your Reality inbound:${NC}"
    for sni in "${GOOD_SNIS[@]:0:3}"; do
        echo -e "  ${GREEN}  → sni=${sni}${NC}"
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6 — DNS TUNNEL COMPATIBILITY (NEW — MasterDNS/VayDNS specific)
# ═══════════════════════════════════════════════════════════════════════════
phase6_dns_tunnel() {
    section "PHASE 6  DNS TUNNEL COMPATIBILITY (MasterDNS & VayDNS)"
    info "Testing DNS capabilities needed for wartime Iran (April 2026 conditions)..."
    echo ""
    # Context: In wartime Iran, only DNS-based tunnels reliably work
    # Source: iAghapour channel + developer notes April 2026

    DNS_SCORE=0

    # 1. Can act as authoritative DNS server?
    DNS_UDP_OPEN=$(nc -w 2 -zu 8.8.8.8 53 2>/dev/null && echo "ok" || echo "fail")
    if [[ "$DNS_UDP_OPEN" == "ok" ]]; then
        ok "UDP port 53 outbound works — DNS resolution functional"
        DNS_SCORE=$((DNS_SCORE+1))
    else
        warn "UDP port 53 outbound issues — may affect MasterDNS client resolution"
    fi

    # 2. Test DNS over TCP (fallback for Iran's blocked UDP)
    DNS_TCP=$(nc -w 3 -z 8.8.8.8 53 2>/dev/null && echo "ok" || echo "fail")
    if [[ "$DNS_TCP" == "ok" ]]; then
        ok "DNS over TCP (port 53) works — important fallback for Iran"
        DNS_SCORE=$((DNS_SCORE+1))
        add 5
    else
        warn "DNS TCP port 53 blocked — may reduce MasterDNS stability"
    fi

    # 3. Test DNS query length handling (Iran drops long DNS queries)
    # Iran's DPI drops queries > ~110 chars; recommended max-qname-len = 101
    info "Testing DNS query length tolerance (Iran DPI blocks >110 chars)..."
    SHORT_DNS=$(dig +short +timeout=3 "test.google.com" @8.8.8.8 2>/dev/null)
    if [[ -n "$SHORT_DNS" ]]; then
        ok "Short DNS queries work — MasterDNS max-qname-len=101 will function"
        DNS_SCORE=$((DNS_SCORE+1))
        add 5
    fi

    # 4. Check DoH (DNS over HTTPS) availability
    DOH=$(curl -s --max-time 4 "https://cloudflare-dns.com/dns-query?name=google.com&type=A" \
        -H "accept: application/dns-json" 2>/dev/null | grep -c "Answer")
    if [[ $DOH -gt 0 ]]; then
        ok "DNS over HTTPS (DoH) works — can be used as DNS resolver for MasterDNS"
        add 3
    fi

    # 5. MasterDNS install readiness
    echo ""
    info "Checking MasterDnsVPN installation requirements..."
    MDNS_URL="https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh"
    MDNS_REACH=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" "$MDNS_URL" 2>/dev/null)
    if [[ "$MDNS_REACH" == "200" ]]; then
        ok "MasterDnsVPN install script reachable"
        add 5
        cmd "MasterDnsVPN: bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)"
    else
        warn "MasterDnsVPN install URL unreachable — needs DNS fix first"
        action "Fix DNS first, then install MasterDnsVPN"
    fi

    # 6. VayDNS check
    VAYDNS_URL="https://raw.githubusercontent.com/net2share/vaydns/main/install.sh"
    VAYDNS_REACH=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" "$VAYDNS_URL" 2>/dev/null)
    if [[ "$VAYDNS_REACH" == "200" ]]; then
        ok "VayDNS install script reachable"
        cmd "VayDNS: bash <(curl -Ls https://raw.githubusercontent.com/net2share/vaydns/main/install.sh)"
    else
        warn "VayDNS install URL unreachable"
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}DNS Tunnel Configuration Notes (April 2026):${NC}"
    echo -e "  ${YELLOW}  • Use max-qname-len=101 (NOT 253) — Iran DPI blocks longer queries${NC}"
    echo -e "  ${YELLOW}  • Use short domain names (e.g. t.ab.com not long.subdomain.example.com)${NC}"
    echo -e "  ${YELLOW}  • VayDNS + MasterDNS work even on weak DNS resolvers${NC}"
    echo -e "  ${YELLOW}  • DNS tunnel is the MOST STABLE in wartime/extreme censorship Iran${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7 — PROTOCOL & PANEL RECOMMENDATION ENGINE
# ═══════════════════════════════════════════════════════════════════════════
phase7_protocols() {
    section "PHASE 7  PROTOCOL & PANEL RECOMMENDATION ENGINE"
    echo ""
    echo -e "  ${BOLD}Based on Iran DPI behavior April 2026 + your server profile:${NC}"
    echo ""

    # Protocol matrix with realistic ratings for wartime Iran
    printf "  ${BOLD}%-3s %-38s %-12s %s${NC}\n" "★" "PROTOCOL STACK" "STABILITY" "NOTES"
    echo -e "  ────────────────────────────────────────────────────────────────────"

    # Rating based on score
    SHOW_REALITY=1
    [[ $SCORE -lt 50 ]] && SHOW_REALITY=0

    echo -e ""
    echo -e "  ${BOLD}${GREEN}=== TIER 1: MOST RELIABLE IN WARTIME IRAN ===${NC}"

    # DNS Tunnel — most reliable in wartime
    echo -e "  ${GREEN}[★★★★★]${NC} VLESS + WS/TCP + MasterDnsVPN DNS tunnel"
    echo -e "         ${DIM}DNS-based obfuscation — most stable in wartime Iran${NC}"
    echo -e "         ${CYAN}Config: DNS tunnel + any VLESS config behind it${NC}"
    echo ""

    # WS + TLS + Cloudflare CDN
    echo -e "  ${GREEN}[★★★★☆]${NC} VLESS + WebSocket + TLS via Cloudflare CDN"
    echo -e "         ${DIM}Hides real IP behind CF. Best for long-term stability.${NC}"
    echo -e "         ${CYAN}Config: network=ws, security=tls, CDN proxy=ON, domain needed${NC}"
    echo ""

    echo -e "  ${BOLD}${YELLOW}=== TIER 2: WORKS WITH FRESH/CLEAN IP ===${NC}"

    # XHTTP (SplitHTTP) — new, better than WS
    echo -e "  ${YELLOW}[★★★★☆]${NC} VLESS + XHTTP (SplitHTTP) + Cloudflare CDN"
    echo -e "         ${DIM}New in Xray 1.8+ — beats WS fingerprinting, best CDN option${NC}"
    echo -e "         ${CYAN}Config: network=splithttp/xhttp, security=tls, CDN proxy=ON${NC}"
    echo ""

    if [[ $SHOW_REALITY -eq 1 ]]; then
        echo -e "  ${YELLOW}[★★★☆☆]${NC} VLESS + Reality + xtls-rprx-vision + uTLS=chrome"
        echo -e "         ${DIM}Works on clean IPs — gets blocked fast on popular DCs${NC}"
        echo -e "         ${CYAN}Config: security=reality, flow=xtls-rprx-vision, fp=chrome, sni=$BEST_SNI${NC}"
    else
        echo -e "  ${RED}[★★☆☆☆]${NC} VLESS + Reality — RISKY for this server"
        echo -e "         ${DIM}Low-confidence ASN/location makes Reality blocks likely${NC}"
    fi
    echo ""

    echo -e "  ${BOLD}${RED}=== BLOCKED — DO NOT USE ===${NC}"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} WireGuard / OpenVPN — Blocked in <1 second by Iran DPI"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} VLESS plain TCP (no TLS) — Immediately detectable"
    echo -e "  ${RED}[✖✖✖✖✖]${NC} VLESS Reality on blocked/gray-listed IP — waste of time"
    echo ""

    # Panel recommendation
    echo -e "  ${BOLD}=== PANEL RECOMMENDATION ===${NC}"
    echo ""
    printf "  ${BOLD}%-3s %-25s %-12s %s${NC}\n" "★" "PANEL" "SUITABILITY" "NOTES"
    echo -e "  ──────────────────────────────────────────────────────────"
    echo -e "  ${GREEN}[★★★★★]${NC} ${BOLD}3X-UI (mhsanaei)${NC}          Excellent  Full-featured, actively maintained, best for Iran"
    echo -e "              ${DIM}github.com/MHSanaei/3x-ui — supports XHTTP, Reality, WS, all protocols${NC}"
    echo ""
    echo -e "  ${GREEN}[★★★★☆]${NC} ${BOLD}MasterDnsVPN${NC}              Excellent  Best for wartime — DNS tunnel specialist"
    echo -e "              ${DIM}github.com/masterking32/MasterDnsVPN — works when everything else fails${NC}"
    echo ""
    echo -e "  ${GREEN}[★★★★☆]${NC} ${BOLD}VayDNS${NC}                    Excellent  DNS tunnel alternative, very stable"
    echo -e "              ${DIM}github.com/net2share/vaydns — good with weak DNS resolvers${NC}"
    echo ""
    echo -e "  ${YELLOW}[★★★☆☆]${NC} ${BOLD}Hiddify Panel${NC}             Good       User-friendly, good for distribution"
    echo -e "              ${DIM}github.com/hiddify/hiddify-manager — easier but less control${NC}"
    echo ""
    echo -e "  ${YELLOW}[★★★☆☆]${NC} ${BOLD}Marzban${NC}                   Good       Multi-server, good for scaling"
    echo -e "              ${DIM}github.com/Gozargah/Marzban${NC}"
    echo ""
    echo -e "  ${RED}[★★☆☆☆]${NC} ${BOLD}x-ui (alireza0)${NC}           Outdated   No longer actively maintained"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 8 — SYSTEM RESOURCES
# ═══════════════════════════════════════════════════════════════════════════
phase8_system() {
    section "PHASE 8  SYSTEM RESOURCES"

    OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
    info "OS: $OS"
    echo "$OS" | grep -qiE "ubuntu 22|ubuntu 24|debian 11|debian 12" && \
        ok "OS fully supported — all scripts will install cleanly" && add 5 || \
        warn "Non-standard OS — some scripts may have compatibility issues"

    RAM=$(free -m | grep Mem | awk '{print $2}')
    RAM_FREE=$(free -m | grep Mem | awk '{print $4}')
    if [[ $RAM -ge 2048 ]]; then
        ok "RAM: ${RAM}MB total, ${RAM_FREE}MB free — excellent"
        add 5
    elif [[ $RAM -ge 1024 ]]; then
        ok "RAM: ${RAM}MB — sufficient for 3X-UI + MasterDNS"
        add 3
    elif [[ $RAM -ge 512 ]]; then
        warn "RAM: ${RAM}MB — minimum; run only 3X-UI OR MasterDNS, not both"
    else
        fail "RAM: ${RAM}MB — too low; unstable operation expected"
        sub 10
    fi

    DISK=$(df -h / | tail -1 | awk '{print $4}')
    info "Free disk: $DISK"

    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    info "CPU: ${CPU_CORES} core(s)"
    [[ ${CPU_CORES:-1} -lt 1 ]] && warn "Single core — avoid running multiple heavy services"

    # Kernel version (BBR needs 4.9+)
    KERNEL=$(uname -r)
    KERNEL_MAJ=$(echo $KERNEL | cut -d. -f1)
    KERNEL_MIN=$(echo $KERNEL | cut -d. -f2)
    info "Kernel: $KERNEL"
    if [[ $KERNEL_MAJ -ge 5 ]] || [[ $KERNEL_MAJ -eq 4 && $KERNEL_MIN -ge 9 ]]; then
        ok "Kernel 4.9+ — BBR can be enabled"
    else
        warn "Old kernel — BBR may not be available"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# FINAL VERDICT
# ═══════════════════════════════════════════════════════════════════════════
final_verdict() {
    section "FINAL VERDICT"

    [[ $SCORE -gt 100 ]] && SCORE=100
    [[ $SCORE -lt 0 ]] && SCORE=0

    echo ""
    BAR=""
    FILLED=$((SCORE / 5))
    for ((i=0; i<20; i++)); do
        [[ $i -lt $FILLED ]] && BAR+="█" || BAR+="░"
    done

    if [[ $SCORE -ge 78 ]]; then
        COLOR=$GREEN; GRADE="A"
        VERDICT="EXCELLENT — Deploy immediately"
        ADVICE="High probability of working in Iran. Install 3X-UI + enable BBR. Use Reality as primary."
    elif [[ $SCORE -ge 58 ]]; then
        COLOR=$YELLOW; GRADE="B"
        VERDICT="GOOD — Deploy with CDN config"
        ADVICE="Moderate-high probability. Use WS+TLS+Cloudflare as primary, Reality as backup."
    elif [[ $SCORE -ge 40 ]]; then
        COLOR=$YELLOW; GRADE="C"
        VERDICT="ACCEPTABLE — DNS tunnel primary"
        ADVICE="Use MasterDNS or VayDNS as primary tunnel. Don't rely on Reality directly."
    elif [[ $SCORE -ge 25 ]]; then
        COLOR=$RED; GRADE="D"
        VERDICT="RISKY — Consider alternatives"
        ADVICE="Low success probability. Try Hetzner Finland before investing more time."
    else
        COLOR=$RED; GRADE="F"
        VERDICT="AVOID — Change server immediately"
        ADVICE="Very high failure probability. This server will not reliably work from Iran."
    fi

    echo -e "  ${BOLD}Grade: ${COLOR}${GRADE}${NC}  ${DIM}|${NC}  Score: ${COLOR}${BOLD}${SCORE}/100${NC}"
    echo -e "  ${COLOR}[${BAR}] ${SCORE}%${NC}"
    echo ""
    echo -e "  ${COLOR}${BOLD}$VERDICT${NC}"
    echo -e "  ${DIM}$ADVICE${NC}"

    if [[ ${#ISSUES[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}${RED}Issues requiring attention:${NC}"
        for i in "${!ISSUES[@]}"; do
            echo -e "  ${RED}  $((i+1)). ${ISSUES[$i]}${NC}"
        done
    fi

    if [[ ${#ACTIONS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}${CYAN}Recommended actions (in priority order):${NC}"
        for i in "${!ACTIONS[@]}"; do
            echo -e "  ${CYAN}  $((i+1)). ${ACTIONS[$i]}${NC}"
        done
    fi

    # ── Installation Guide ────────────────────────────────────────────────
    section "INSTALLATION GUIDE FOR THIS SERVER"
    echo ""
    echo -e "  ${BOLD}Step 1 — Fix DNS (if issues found):${NC}"
    echo -e "  ${CYAN}  echo 'nameserver 8.8.8.8' > /etc/resolv.conf${NC}"
    echo -e "  ${CYAN}  echo 'nameserver 1.1.1.1' >> /etc/resolv.conf${NC}"
    echo ""
    echo -e "  ${BOLD}Step 2 — Install 3X-UI (primary panel):${NC}"
    echo -e "  ${CYAN}  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}Step 3 — Post-install configuration:${NC}"
    echo -e "  ${CYAN}  x-ui  →  24 (Enable BBR)${NC}"
    echo -e "  ${CYAN}  ufw allow 443 && ufw allow 80 && ufw allow 53/udp${NC}"
    echo ""
    echo -e "  ${BOLD}Step 4 — Create VLESS inbound (optimal settings):${NC}"
    echo -e "  ${CYAN}  Protocol: VLESS | Port: 443 | Security: Reality${NC}"
    echo -e "  ${CYAN}  Network: tcp | Flow: xtls-rprx-vision | uTLS: chrome${NC}"
    echo -e "  ${CYAN}  SNI: ${BEST_SNI:-www.microsoft.com}${NC}"
    echo -e "  ${CYAN}  Short ID: $(openssl rand -hex 4 2>/dev/null || echo 'a1b2c3d4')${NC}"
    echo ""
    echo -e "  ${BOLD}Step 5 — Install MasterDnsVPN (DNS tunnel fallback):${NC}"
    echo -e "  ${CYAN}  systemctl stop systemd-resolved${NC}"
    echo -e "  ${CYAN}  bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}Step 6 — MasterDnsVPN client settings (Windows):${NC}"
    echo -e "  ${CYAN}  Use -max-qname-len 101 (not 253 — Iran drops longer queries)${NC}"
    echo -e "  ${CYAN}  Keep domain/subdomain names SHORT (e.g. t.ab.com)${NC}"
    echo ""

    if [[ ${#INSTALL_CMDS[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Additional available install commands:${NC}"
        for c in "${INSTALL_CMDS[@]}"; do
            echo -e "  ${CYAN}  → $c${NC}"
        done
    fi

    echo ""
    echo -e "${CYAN}  ══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Test complete — آزادی اینترنت حق همه مردم ایران است${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════
main() {
    banner
    install_deps
    phase1_identity  || { echo -e "${RED}Fatal: Cannot continue without internet.${NC}"; exit 1; }
    phase2_install
    phase3_ports
    phase4_network
    phase5_sni
    phase6_dns_tunnel
    phase7_protocols
    phase8_system
    final_verdict
}

main
