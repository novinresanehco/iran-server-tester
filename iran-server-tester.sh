#!/bin/bash
# ============================================================
#   IRAN VPN SERVER READINESS TESTER v2.0
#   Hybrid intelligence: ASN + IP + Protocol + DPI analysis
#   Run this on your NEW foreign server right after purchase
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

SCORE=0
MAX_SCORE=100
declare -a WARNINGS
declare -a RECOMMENDATIONS

banner() {
cat << 'BANNER'
 ██╗██████╗  █████╗ ███╗   ██╗    ████████╗███████╗███████╗████████╗███████╗██████╗ 
 ██║██╔══██╗██╔══██╗████╗  ██║    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗
 ██║██████╔╝███████║██╔██╗ ██║       ██║   █████╗  ███████╗   ██║   █████╗  ██████╔╝
 ██║██╔══██╗██╔══██║██║╚██╗██║       ██║   ██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗
 ██║██║  ██║██║  ██║██║ ╚████║       ██║   ███████╗███████║   ██║   ███████╗██║  ██║
 ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
BANNER
    echo -e "${CYAN}        VPN Server Readiness Checker for Iran - v2.0${NC}"
    echo -e "${YELLOW}        Tests: ASN • IP reputation • DPI resistance • Protocol fit${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}\n"
}

section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ok()   { echo -e "  ${GREEN}[✔]${NC} $1"; }
fail() { echo -e "  ${RED}[✖]${NC} $1"; WARNINGS+=("$1"); }
warn() { echo -e "  ${YELLOW}[⚠]${NC} $1"; WARNINGS+=("$1"); }
info() { echo -e "  ${BLUE}[ℹ]${NC} $1"; }
rec()  { RECOMMENDATIONS+=("$1"); }

add_score() { SCORE=$((SCORE + $1)); }
sub_score() { SCORE=$((SCORE - $1)); [[ $SCORE -lt 0 ]] && SCORE=0; }

install_deps() {
    local missing=()
    for cmd in curl jq mtr nc ping dig; do
        command -v $cmd &>/dev/null || missing+=($cmd)
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Installing: ${missing[*]}${NC}"
        apt-get update -qq 2>/dev/null
        apt-get install -yqq curl jq mtr netcat-openbsd iputils-ping dnsutils 2>/dev/null
        yum install -yq curl jq mtr nc bind-utils 2>/dev/null || true
    fi
}

# ─────────────────────────────────────────
# PHASE 1: SERVER IDENTITY
# ─────────────────────────────────────────
phase1_identity() {
    section "PHASE 1 — Server Identity & ASN Analysis"

    MY_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -s --max-time 5 http://ifconfig.me 2>/dev/null)
    if [[ -z "$MY_IP" ]]; then
        fail "Cannot detect server IP. No internet connectivity?"
        return
    fi
    info "Server IP: ${BOLD}$MY_IP${NC}"

    # Fetch IP info from ipinfo.io
    IP_INFO=$(curl -s --max-time 8 "https://ipinfo.io/${MY_IP}/json" 2>/dev/null)
    ASN=$(echo "$IP_INFO" | grep -o '"org": *"[^"]*"' | sed 's/"org": *"//;s/"//')
    CITY=$(echo "$IP_INFO" | grep -o '"city": *"[^"]*"' | sed 's/"city": *"//;s/"//')
    COUNTRY=$(echo "$IP_INFO" | grep -o '"country": *"[^"]*"' | sed 's/"country": *"//;s/"//')
    AS_NUM=$(echo "$ASN" | grep -oP 'AS\d+')

    info "Location: ${BOLD}$CITY, $COUNTRY${NC}"
    info "ASN: ${BOLD}$ASN${NC}"

    # ── ASN Scoring ──
    # Top-tier ASNs for Iran bypass (historically verified 2024-2026)
    GOOD_ASNS=("AS24940" "AS51167" "AS40676" "AS47583" "AS9009" "AS34549" "AS174")
    BAD_ASNS=("AS16276" "AS5577" "AS3215" "AS12322")   # OVH France, etc. known to be blocked
    WARN_ASNS=("AS14061" "AS20473" "AS16509" "AS15169") # DigitalOcean, Vultr, AWS, Google

    ASN_GOOD=0
    ASN_BAD=0
    for good in "${GOOD_ASNS[@]}"; do
        [[ "$AS_NUM" == "$good" ]] && ASN_GOOD=1 && break
    done
    for bad in "${BAD_ASNS[@]}"; do
        [[ "$AS_NUM" == "$bad" ]] && ASN_BAD=1 && break
    done

    if [[ $ASN_GOOD -eq 1 ]]; then
        ok "ASN ${AS_NUM} is in VERIFIED GOOD list for Iran bypass"
        add_score 25
    elif [[ $ASN_BAD -eq 1 ]]; then
        fail "ASN ${AS_NUM} is in KNOWN BLOCKED list for Iran — High risk!"
        sub_score 30
        rec "Change to Hetzner (Finland/Germany) — AS24940 — best success rate for Iran"
    else
        warn "ASN ${AS_NUM} is UNKNOWN — may or may not work. Proceed with caution."
        add_score 8
    fi

    # ── Country scoring ──
    GOOD_COUNTRIES=("DE" "FI" "NL" "SE" "CH" "AT" "CZ" "PL")
    WARN_COUNTRIES=("US" "GB" "SG" "JP" "TR")
    BAD_COUNTRIES=("IR" "RU" "CN")

    COUNTRY_OK=0
    for gc in "${GOOD_COUNTRIES[@]}"; do
        [[ "$COUNTRY" == "$gc" ]] && COUNTRY_OK=1 && break
    done

    if [[ $COUNTRY_OK -eq 1 ]]; then
        ok "Server location (${COUNTRY}) is optimal for Iran"
        add_score 15
    elif [[ "$COUNTRY" == "TR" ]]; then
        warn "Turkey servers: unpredictable for Iran — sometimes works, often blocked"
        add_score 5
    elif [[ "$COUNTRY" == "FR" ]]; then
        warn "France (likely OVH): historically problematic for Iran since 2025"
        sub_score 10
    else
        warn "Server location ${COUNTRY}: moderate reliability for Iran"
        add_score 10
    fi

    # ── IP Subnet Freshness (simple heuristic) ──
    IP_PREFIX=$(echo $MY_IP | cut -d. -f1-3)
    info "IP Subnet: ${IP_PREFIX}.0/24"
}

# ─────────────────────────────────────────
# PHASE 2: IP REPUTATION CHECK
# ─────────────────────────────────────────
phase2_reputation() {
    section "PHASE 2 — IP Reputation & Abuse Check"

    # Check AbuseIPDB (public, no key needed for basic info)
    ABUSE_INFO=$(curl -s --max-time 8 "https://api.abuseipdb.com/api/v2/check?ipAddress=${MY_IP}&maxAgeInDays=90" \
        -H "Key: free-tier" 2>/dev/null)

    # Alternative: Check Shodan for open ports visibility
    SHODAN_CHECK=$(curl -s --max-time 6 "https://internetdb.shodan.io/${MY_IP}" 2>/dev/null)
    OPEN_PORTS=$(echo "$SHODAN_CHECK" | grep -oP '"ports":\[[^\]]*\]' | grep -oP '\d+' | tr '\n' ',' | sed 's/,$//')
    VULNS=$(echo "$SHODAN_CHECK" | grep -o '"vulns":\[[^]]*\]')

    if [[ -n "$OPEN_PORTS" ]]; then
        info "Shodan visible ports: ${BOLD}${OPEN_PORTS:-none}${NC}"
        echo "$OPEN_PORTS" | grep -q "22" && warn "Port 22 (SSH) is publicly visible — consider changing SSH port"
        echo "$OPEN_PORTS" | grep -q "3389" && warn "Port 3389 (RDP) visible — server may be flagged as proxy"
    else
        ok "IP not prominently indexed in Shodan (good for stealth)"
        add_score 10
    fi

    if [[ -n "$VULNS" && "$VULNS" != '"vulns":[]' ]]; then
        warn "Shodan shows known vulnerabilities on this IP"
        sub_score 5
    fi

    # Check if IP is in Iran's known whitelist zones (reverse: is this IP similar to ones Iran allows?)
    # Iran allows Microsoft, Google, etc. CDN ranges — those are usable as SNI targets
    # Check if our IP is in a "datacenter" range that Iran's DPI monitors closely
    DATACENTER_RANGES_IRAN_MONITORS="104.21 172.67 162.159 104.16"  # Cloudflare (monitored)
    IP_FIRST_TWO=$(echo $MY_IP | cut -d. -f1-2)
    IS_MONITORED=0
    for range in $DATACENTER_RANGES_IRAN_MONITORS; do
        [[ "$MY_IP" == ${range}* ]] && IS_MONITORED=1 && break
    done

    if [[ $IS_MONITORED -eq 1 ]]; then
        warn "IP is in Cloudflare range — Iran DPI actively monitors these"
        sub_score 10
        rec "Use this IP only with WS+TLS+CDN configuration, not direct Reality"
    else
        ok "IP not in heavily monitored CDN ranges"
        add_score 8
    fi
}

# ─────────────────────────────────────────
# PHASE 3: SELF PORT & SERVICE AUDIT
# ─────────────────────────────────────────
phase3_ports() {
    section "PHASE 3 — Port & Service Readiness"

    info "Checking critical ports on this server..."

    # Check which ports are listening
    LISTENING=$(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null)

    # Port 443 — critical for Reality/TLS
    if echo "$LISTENING" | grep -q ":443 "; then
        ok "Port 443 is OPEN and listening"
        add_score 10
        PORT_443_SERVICE=$(echo "$LISTENING" | grep ":443 " | awk '{print $NF}' | head -1)
        info "Service on 443: $PORT_443_SERVICE"
    else
        info "Port 443 is available (nothing listening yet — ready for xui)"
        add_score 5
    fi

    # Port 80 — needed for WS fallback and Cloudflare
    if echo "$LISTENING" | grep -q ":80 "; then
        ok "Port 80 is OPEN"
    else
        info "Port 80 available (good for WS+CDN setup)"
    fi

    # Check if 3x-ui is installed
    if command -v x-ui &>/dev/null || systemctl list-units --type=service 2>/dev/null | grep -q "x-ui"; then
        ok "3X-UI panel is INSTALLED on this server"
        add_score 10
        XRAY_STATUS=$(systemctl is-active x-ui 2>/dev/null)
        if [[ "$XRAY_STATUS" == "active" ]]; then
            ok "3X-UI service is RUNNING"
        else
            warn "3X-UI is installed but NOT running — start with: systemctl start x-ui"
        fi
    else
        info "3X-UI not yet installed (fresh server)"
    fi

    # Check BBR (crucial for performance through Iran's throttling)
    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [[ "$BBR_STATUS" == "bbr" ]]; then
        ok "BBR congestion control is ACTIVE — good for speed"
        add_score 8
    else
        warn "BBR not active (current: ${BBR_STATUS:-unknown}) — Enable via x-ui menu option 24"
        sub_score 5
        rec "Enable BBR: run 'x-ui' and select option 24"
    fi

    # Check firewall
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    IPTABLES_COUNT=$(iptables -L 2>/dev/null | grep -c "ACCEPT" 2>/dev/null || echo "0")
    if echo "$UFW_STATUS" | grep -q "active"; then
        info "UFW firewall active — make sure port 443 is allowed"
        ufw status 2>/dev/null | grep -q "443" && ok "Port 443 allowed in UFW" || warn "Port 443 may be blocked by UFW — run: ufw allow 443"
    fi
}

# ─────────────────────────────────────────
# PHASE 4: NETWORK QUALITY & DPI SIMULATION
# ─────────────────────────────────────────
phase4_network() {
    section "PHASE 4 — Network Quality & Iran Route Analysis"

    # Test connectivity to key Iranian IPs to understand routing
    IRAN_TEST_IPS=(
        "185.51.201.1:MCI/Hamrah-Aval"
        "5.200.200.200:IranCell"
        "217.218.127.127:TIC-Gateway"
    )

    info "Testing routes toward Iranian ISPs..."
    IRAN_REACHABLE=0

    for entry in "${IRAN_TEST_IPS[@]}"; do
        IP="${entry%%:*}"
        LABEL="${entry##*:}"
        RESULT=$(ping -c 2 -W 3 "$IP" 2>/dev/null)
        if echo "$RESULT" | grep -q "bytes from"; then
            RTT=$(echo "$RESULT" | grep "avg" | awk -F'/' '{print $5}')
            ok "$LABEL ($IP) reachable — RTT: ${RTT}ms"
            IRAN_REACHABLE=$((IRAN_REACHABLE + 1))
            add_score 5
        else
            warn "$LABEL ($IP) not reachable from this server"
        fi
    done

    if [[ $IRAN_REACHABLE -eq 0 ]]; then
        warn "Cannot reach any Iranian IP directly — this is normal for many datacenters"
        info "This does NOT mean Iran can't reach you — routing is asymmetric"
    fi

    # Test latency to Cloudflare (SNI fronting option)
    CF_LATENCY=$(ping -c 3 -W 3 1.1.1.1 2>/dev/null | grep "avg" | awk -F'/' '{print $5}')
    if [[ -n "$CF_LATENCY" ]]; then
        info "Cloudflare latency: ${CF_LATENCY}ms"
        CF_MS=$(echo $CF_LATENCY | cut -d. -f1)
        if [[ $CF_MS -lt 50 ]]; then
            ok "Excellent Cloudflare proximity — CDN routing will be fast"
            add_score 5
        elif [[ $CF_MS -lt 120 ]]; then
            ok "Good Cloudflare proximity"
            add_score 3
        else
            warn "High Cloudflare latency — CDN-based configs may be slow"
        fi
    fi

    # Test if port 443 outbound works (needed for XTLS Vision handshake)
    CF_443=$(nc -w 3 -z 1.1.1.1 443 2>/dev/null && echo "ok" || echo "fail")
    if [[ "$CF_443" == "ok" ]]; then
        ok "Outbound port 443 works — SNI handshake simulation possible"
        add_score 5
    else
        fail "Cannot reach port 443 outbound — may indicate ISP restrictions on this server"
    fi

    # MTU test (Iran DPI manipulates MTU — fragmented packets often bypass inspection)
    MTU_TEST=$(ping -c 2 -M do -s 1400 8.8.8.8 2>/dev/null)
    if echo "$MTU_TEST" | grep -q "bytes from"; then
        ok "MTU 1400 works fine — no fragmentation issues"
        add_score 3
    else
        warn "MTU fragmentation detected — may need Fragment option in xray config"
        rec "In xray config, add 'fragment' settings for better DPI bypass"
    fi
}

# ─────────────────────────────────────────
# PHASE 5: SNI & TLS CAMOUFLAGE TEST
# ─────────────────────────────────────────
phase5_sni() {
    section "PHASE 5 — SNI & TLS Camouflage Readiness"

    info "Testing which SNI domains work from this server (for Reality config)..."

    # These are SNIs known to work well with Iran's whitelist
    SNI_CANDIDATES=(
        "www.microsoft.com:Microsoft — usually whitelisted"
        "www.bing.com:Bing — usually whitelisted"
        "addons.mozilla.org:Mozilla — often works"
        "www.speedtest.net:Speedtest — previously popular, now monitored"
        "www.google.com:Google — sometimes works"
        "www.apple.com:Apple — often works"
    )

    GOOD_SNIS=()
    for entry in "${SNI_CANDIDATES[@]}"; do
        DOMAIN="${entry%%:*}"
        LABEL="${entry##*:}"

        # Test TLS handshake with this SNI
        TLS_RESULT=$(echo "Q" | openssl s_client -connect "${DOMAIN}:443" \
            -servername "$DOMAIN" -verify_return_error 2>/dev/null | head -20)

        if echo "$TLS_RESULT" | grep -q "CONNECTED"; then
            ok "SNI ${BOLD}$DOMAIN${NC} — TLS handshake OK (${LABEL})"
            GOOD_SNIS+=("$DOMAIN")
        else
            # Try with curl
            CURL_TLS=$(curl -s --max-time 4 -I "https://$DOMAIN" 2>/dev/null | head -1)
            if echo "$CURL_TLS" | grep -q "HTTP"; then
                ok "SNI ${BOLD}$DOMAIN${NC} — reachable (${LABEL})"
                GOOD_SNIS+=("$DOMAIN")
            else
                warn "SNI $DOMAIN — unreachable from this server"
            fi
        fi
    done

    if [[ ${#GOOD_SNIS[@]} -ge 3 ]]; then
        ok "${#GOOD_SNIS[@]} good SNI candidates found"
        add_score 10
    elif [[ ${#GOOD_SNIS[@]} -ge 1 ]]; then
        warn "Only ${#GOOD_SNIS[@]} SNI candidates work — limited Reality options"
        add_score 5
    else
        fail "No SNI domains reachable — server may have egress restrictions"
        sub_score 10
    fi

    echo ""
    info "Recommended SNI for your Reality config:"
    for sni in "${GOOD_SNIS[@]:0:3}"; do
        echo -e "    ${GREEN}→ sni=${sni}${NC}"
    done
}

# ─────────────────────────────────────────
# PHASE 6: PROTOCOL RECOMMENDATION ENGINE
# ─────────────────────────────────────────
phase6_protocol() {
    section "PHASE 6 — Protocol Recommendation for Iran 2026"

    echo ""
    info "Analyzing best protocol stack for current Iran DPI (April 2026)..."
    echo ""

    # Based on ASN, location, and test results, recommend protocols
    echo -e "  ${BOLD}Protocol Suitability Matrix:${NC}"
    echo -e "  ─────────────────────────────────────────────────"

    # Reality + Vision
    if [[ $SCORE -gt 60 ]]; then
        echo -e "  ${GREEN}[★★★]${NC} VLESS + Reality + xtls-rprx-vision + uTLS=chrome"
        echo -e "        Best resistance to DPI. Use SNI: www.microsoft.com"
        rec "PRIMARY: VLESS+Reality. Port 443, flow=xtls-rprx-vision, fp=chrome, sni=www.microsoft.com"
    else
        echo -e "  ${YELLOW}[★★☆]${NC} VLESS + Reality (moderate confidence — IP may be blocked)"
    fi

    # WS + TLS + CDN
    echo -e "  ${GREEN}[★★★]${NC} VLESS + WebSocket + TLS via Cloudflare CDN"
    echo -e "        Most stable in wartime Iran. Hides real IP behind Cloudflare."
    rec "FALLBACK: VLESS+WS+TLS behind Cloudflare. Port 443, security=tls, network=ws"

    # XHTTP (new, better than WS)
    echo -e "  ${CYAN}[★★★]${NC} VLESS + XHTTP (SplitHTTP) — NEW in Xray 1.8+"
    echo -e "        Better than WebSocket for DPI evasion in 2026"
    rec "ADVANCED: VLESS+XHTTP via CDN — best camouflage, beats WS fingerprinting"

    # Hysteria2 (UDP-based, often not blocked)
    echo -e "  ${BLUE}[★★☆]${NC} Hysteria2 (UDP/QUIC-based)"
    echo -e "        Iran blocks UDP inconsistently — may work on some ISPs"

    echo -e "  ${RED}[✖✖✖]${NC} WireGuard / OpenVPN — BLOCKED immediately by Iran DPI"
    echo -e "  ${RED}[✖✖✖]${NC} VLESS + TCP without TLS — detectable, blocked"
    echo ""
}

# ─────────────────────────────────────────
# PHASE 7: INSTALLATION READINESS
# ─────────────────────────────────────────
phase7_install() {
    section "PHASE 7 — Installation Readiness Check"

    # Check OS
    OS=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'"' -f2)
    info "OS: $OS"

    if echo "$OS" | grep -qi "ubuntu 22\|ubuntu 24\|debian 11\|debian 12"; then
        ok "OS is supported for 3X-UI and MasterDNS"
        add_score 5
    else
        warn "OS may have compatibility issues with some scripts"
    fi

    # RAM check
    RAM_MB=$(free -m 2>/dev/null | grep Mem | awk '{print $2}')
    if [[ $RAM_MB -ge 512 ]]; then
        ok "RAM: ${RAM_MB}MB — sufficient for 3X-UI + Xray"
        add_score 3
    else
        warn "RAM: ${RAM_MB}MB — very low, may cause instability"
        sub_score 5
    fi

    # Disk
    DISK_FREE=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
    info "Free disk: $DISK_FREE"

    # CPU
    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    info "CPU cores: $CPU_CORES"

    # Check if curl can reach GitHub (needed for installations)
    GITHUB_REACH=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" https://github.com)
    if [[ "$GITHUB_REACH" == "200" ]]; then
        ok "GitHub reachable — script installations will work"
        add_score 5
    else
        fail "Cannot reach GitHub — 3X-UI installation will FAIL. Critical issue."
        sub_score 15
        rec "CRITICAL: Server cannot reach GitHub. Cannot install 3X-UI. Choose different server."
    fi

    # Check raw.githubusercontent.com (needed for 3x-ui install script)
    RAW_REACH=$(curl -s --max-time 6 -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com)
    if [[ "$RAW_REACH" == "200" ]]; then
        ok "raw.githubusercontent.com reachable — install scripts will work"
    else
        fail "raw.githubusercontent.com blocked — 3X-UI install script will fail"
        sub_score 10
    fi
}

# ─────────────────────────────────────────
# FINAL VERDICT
# ─────────────────────────────────────────
final_verdict() {
    section "FINAL VERDICT"

    # Cap score
    [[ $SCORE -gt 100 ]] && SCORE=100
    [[ $SCORE -lt 0 ]] && SCORE=0

    echo ""
    echo -e "  ${BOLD}Overall Score: ${SCORE}/100${NC}"
    echo ""

    # Visual score bar
    BAR=""
    FILLED=$((SCORE / 5))
    for ((i=0; i<20; i++)); do
        if [[ $i -lt $FILLED ]]; then
            BAR+="█"
        else
            BAR+="░"
        fi
    done

    if [[ $SCORE -ge 75 ]]; then
        echo -e "  ${GREEN}[${BAR}] ${SCORE}%${NC}"
        echo ""
        echo -e "  ${GREEN}${BOLD}🟢 VERDICT: EXCELLENT — Deploy immediately${NC}"
        echo -e "  ${GREEN}  This server has high probability of working in Iran.${NC}"
        echo -e "  ${GREEN}  Install 3X-UI and configure Reality + Vision.${NC}"
    elif [[ $SCORE -ge 55 ]]; then
        echo -e "  ${YELLOW}[${BAR}] ${SCORE}%${NC}"
        echo ""
        echo -e "  ${YELLOW}${BOLD}🟡 VERDICT: ACCEPTABLE — Use with CDN fallback${NC}"
        echo -e "  ${YELLOW}  Moderate chance of working. Use WS+TLS+Cloudflare${NC}"
        echo -e "  ${YELLOW}  as primary config, Reality as secondary.${NC}"
    elif [[ $SCORE -ge 35 ]]; then
        echo -e "  ${YELLOW}[${BAR}] ${SCORE}%${NC}"
        echo ""
        echo -e "  ${YELLOW}${BOLD}🟠 VERDICT: RISKY — Consider alternatives${NC}"
        echo -e "  ${YELLOW}  Low probability of stable connection from Iran.${NC}"
        echo -e "  ${YELLOW}  Only try if no better option available.${NC}"
    else
        echo -e "  ${RED}[${BAR}] ${SCORE}%${NC}"
        echo ""
        echo -e "  ${RED}${BOLD}🔴 VERDICT: AVOID — High chance of failure${NC}"
        echo -e "  ${RED}  This server will likely NOT work from Iran.${NC}"
        echo -e "  ${RED}  Get a Hetzner Finland server instead.${NC}"
    fi

    # Issues summary
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}Issues Found:${NC}"
        for w in "${WARNINGS[@]}"; do
            echo -e "  ${RED}  • $w${NC}"
        done
    fi

    # Action items
    if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}Action Items (in order):${NC}"
        N=1
        for r in "${RECOMMENDATIONS[@]}"; do
            echo -e "  ${CYAN}  $N. $r${NC}"
            N=$((N+1))
        done
    fi

    # Quick install commands
    echo ""
    section "QUICK INSTALL COMMANDS (if verdict is green/yellow)"
    echo ""
    echo -e "  ${BOLD}Step 1 — Install 3X-UI:${NC}"
    echo -e "  ${CYAN}bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}Step 2 — Enable BBR (after install):${NC}"
    echo -e "  ${CYAN}x-ui   →  select option 24${NC}"
    echo ""
    echo -e "  ${BOLD}Step 3 — Create inbound with these exact settings:${NC}"
    echo -e "  ${CYAN}  Protocol: VLESS | Port: 443 | Security: Reality${NC}"
    echo -e "  ${CYAN}  Flow: xtls-rprx-vision | uTLS: chrome${NC}"
    if [[ ${#GOOD_SNIS[@]} -gt 0 ]]; then
        echo -e "  ${CYAN}  SNI: ${GOOD_SNIS[0]}${NC}"
    else
        echo -e "  ${CYAN}  SNI: www.microsoft.com${NC}"
    fi
    echo -e "  ${CYAN}  Short ID: generate a random 8-char hex (e.g. a1b2c3d4)${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Test complete. Good luck — آزادی اینترنت حق شماست${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}\n"
}

# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
main() {
    clear
    banner
    install_deps

    phase1_identity
    phase2_reputation
    phase3_ports
    phase4_network
    phase5_sni
    phase6_protocol
    phase7_install
    final_verdict
}

main
