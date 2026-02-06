#!/bin/sh
# keen-pbr-web installer for Keenetic routers running Entware
# Usage: wget -qO- https://raw.githubusercontent.com/Dronicho/keen-pbr-web/refs/heads/master/install.sh | sh
#

set -e
REPO="Dronicho/keen-pbr-web"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/refs/heads/master"
INSTALL_DIR="/opt/sbin"
CONFIG_DIR="/opt/etc/keen-pbr"
CONFIG_FILE="$CONFIG_DIR/keen-pbr.conf"
LISTS_DIR="$CONFIG_DIR/lists.d"
INIT_SCRIPT="/opt/etc/init.d/S99keen-pbr-web"
PORT=3000

# Bird4Static paths
BIRD_DIR="/opt/root/Bird4Static"
BIRD_LISTS_DIR="${BIRD_DIR}/lists"

log() { printf "\033[1;33m▸\033[0m %s\n" "$1"; }
ok()  { printf "\033[1;32m✓\033[0m %s\n" "$1"; }
err() { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }
warn(){ printf "\033[1;35m!\033[0m %s\n" "$1"; }

# ── Helpers ──────────────────────────────────────────────────────────

detect_arch() {
    case "$(uname -m)" in
        mips|mipsel|mipsle) echo "mipsle" ;;
        aarch64|arm64)      echo "arm64" ;;
        *) err "Unsupported architecture: $(uname -m)" ;;
    esac
}

fetch() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    else
        wget -qO "$dest" "$url"
    fi
}

fetch_stdout() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    else
        wget -qO- "$url"
    fi
}

check_prereqs() {
    [ -d /opt/etc ] || err "Entware not found (/opt/etc missing). Install Entware first."
    command -v keen-pbr >/dev/null 2>&1 || err "keen-pbr not found. Install: opkg install keen-pbr"
    command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || err "wget/curl not found. Install: opkg install wget-ssl"
}

# ── Stop existing instance ───────────────────────────────────────────

stop_existing() {
    if [ -x "$INIT_SCRIPT" ]; then
        log "Stopping existing keen-pbr-web..."
        "$INIT_SCRIPT" stop 2>/dev/null || true
    fi
}

# ── Download binary from latest release ──────────────────────────────

download_binary() {
    local arch="$1"
    local suffix="linux-${arch}"

    log "Fetching latest release..."

    local api_url="https://api.github.com/repos/${REPO}/releases/latest"
    local download_url
    download_url=$(fetch_stdout "$api_url" | grep "browser_download_url.*${suffix}" | head -1 | cut -d'"' -f4)

    [ -z "$download_url" ] && err "No release found for ${suffix}"

    log "Downloading $download_url"
    fetch "$download_url" "${INSTALL_DIR}/keen-pbr-web"
    chmod +x "${INSTALL_DIR}/keen-pbr-web"
    ok "Binary installed: ${INSTALL_DIR}/keen-pbr-web"
}

# ── Download init script from repo ───────────────────────────────────

download_init_script() {
    log "Downloading init script..."
    fetch "${RAW_BASE}/package/S99keen-pbr-web" "$INIT_SCRIPT"
    chmod +x "$INIT_SCRIPT"
    ok "Init script installed: $INIT_SCRIPT"
}

# ── Bird4Static migration ───────────────────────────────────────────

# Copy a user list (plain domains/IPs/CIDRs) stripping comments
copy_user_list() {
    local src="$1" dest_name="$2"
    local dest="${LISTS_DIR}/${dest_name}.lst"

    grep -v '^[[:space:]]*[#;]' "$src" | grep -v '^[[:space:]]*$' > "$dest" 2>/dev/null || true

    local count
    count=$(wc -l < "$dest" | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        ok "  ${dest_name}.lst: $count entries"
        return 0
    else
        rm -f "$dest"
        return 1
    fi
}

migrate_bird4static() {
    [ -d "$BIRD_DIR" ] || return 1

    log "Found Bird4Static at $BIRD_DIR"
    log "Starting migration..."

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    # ── Detect VPN interfaces from bird.conf ──
    local vpn_interfaces=""
    local bird_conf="${BIRD_DIR}/bird.conf"

    if [ -f "$bird_conf" ]; then
        vpn_interfaces=$(sed -n 's/.*ifname[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$bird_conf" 2>/dev/null || true)
        if [ -z "$vpn_interfaces" ]; then
            vpn_interfaces=$(sed -n 's/.*interface[[:space:]]*"\([^"]*\)".*/\1/p' "$bird_conf" 2>/dev/null | head -5 || true)
        fi
    fi

    if [ -z "$vpn_interfaces" ]; then
        warn "Could not detect VPN interfaces from bird.conf"
        vpn_interfaces="nwg0"
    fi
    log "VPN interfaces: $vpn_interfaces"

    # ── Migrate user lists ──
    local vpn_lists=""
    local direct_lists=""

    # user-vpn.list → VPN
    if [ -f "${BIRD_LISTS_DIR}/user-vpn.list" ]; then
        log "Migrating user-vpn.list (VPN traffic)"
        if copy_user_list "${BIRD_LISTS_DIR}/user-vpn.list" "user-vpn"; then
            vpn_lists="${vpn_lists} user-vpn"
        fi
    fi

    # user-isp.list → direct
    if [ -f "${BIRD_LISTS_DIR}/user-isp.list" ]; then
        log "Migrating user-isp.list (direct/ISP traffic)"
        if copy_user_list "${BIRD_LISTS_DIR}/user-isp.list" "user-direct"; then
            direct_lists="${direct_lists} user-direct"
        fi
    fi

    # Any other user-*.list
    for user_file in "${BIRD_LISTS_DIR}"/user-*.list; do
        [ -f "$user_file" ] || continue
        local base
        base=$(basename "$user_file")
        case "$base" in
            user-vpn.list|user-isp.list) continue ;;
        esac

        local list_name
        list_name=$(echo "$base" | sed 's/^user-//; s/\.list$//')

        log "Migrating $base"
        if copy_user_list "$user_file" "$list_name"; then
            vpn_lists="${vpn_lists} ${list_name}"
        fi
    done

    # ── Generate keen-pbr.conf ──
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        warn "Existing config backed up to ${CONFIG_FILE}.bak"
    fi

    # Build TOML arrays
    local iface_array=""
    for iface in $vpn_interfaces; do
        [ -n "$iface_array" ] && iface_array="${iface_array}, "
        iface_array="${iface_array}\"${iface}\""
    done

    local vpn_lists_toml="" direct_lists_toml="" list_sections=""

    for name in $vpn_lists; do
        [ -n "$vpn_lists_toml" ] && vpn_lists_toml="${vpn_lists_toml}, "
        vpn_lists_toml="${vpn_lists_toml}\"${name}\""
        if [ -f "${LISTS_DIR}/${name}.lst" ]; then
            list_sections="${list_sections}
[[list]]
  list_name = \"${name}\"
  file = \"${LISTS_DIR}/${name}.lst\"
"
        fi
    done

    for name in $direct_lists; do
        [ -n "$direct_lists_toml" ] && direct_lists_toml="${direct_lists_toml}, "
        direct_lists_toml="${direct_lists_toml}\"${name}\""
        if [ -f "${LISTS_DIR}/${name}.lst" ]; then
            list_sections="${list_sections}
[[list]]
  list_name = \"${name}\"
  file = \"${LISTS_DIR}/${name}.lst\"
"
        fi
    done

    # Write config — VPN ipset
    cat > "$CONFIG_FILE" << CONFEOF
[general]
  lists_output_dir = "${LISTS_DIR}"
  use_keenetic_api = true
  use_keenetic_dns = true
  fallback_dns = "8.8.8.8"
CONFEOF

    if [ -n "$vpn_lists_toml" ]; then
        cat >> "$CONFIG_FILE" << CONFEOF

[[ipset]]
  ipset_name = "vpn"
  lists = [${vpn_lists_toml}]
  ip_version = 4
  flush_before_applying = true

  [ipset.routing]
    interfaces = [${iface_array}]
    kill_switch = false
    fwmark = 1001
    table = 1001
    priority = 1001
CONFEOF
    fi

    if [ -n "$direct_lists_toml" ]; then
        local internet_iface
        internet_iface=$(detect_internet_iface)
        local direct_iface_toml="[]"
        if [ -n "$internet_iface" ]; then
            direct_iface_toml="[\"${internet_iface}\"]"
        fi

        cat >> "$CONFIG_FILE" << CONFEOF

[[ipset]]
  ipset_name = "direct"
  lists = [${direct_lists_toml}]
  ip_version = 4
  flush_before_applying = true

  [ipset.routing]
    interfaces = ${direct_iface_toml}
    kill_switch = false
    fwmark = 1002
    table = 1002
    priority = 1002
CONFEOF
    fi

    printf "%s" "$list_sections" >> "$CONFIG_FILE"

    ok "Config generated: $CONFIG_FILE"
    [ -n "$vpn_lists" ] && log "  VPN lists:$vpn_lists"
    [ -n "$direct_lists" ] && log "  Direct lists:$direct_lists"
}

# Detect interfaces
detect_vpn_iface() {
    keen-pbr interfaces 2>/dev/null | awk '{print $1}' | grep -E '^(nwg|wg|tun|ovpn)' | head -1 || echo "nwg0"
}

detect_internet_iface() {
    keen-pbr interfaces 2>/dev/null | awk '{print $1}' | grep -vE '^(nwg|wg|tun|ovpn|lo)' | head -1 || echo ""
}

# Generate default config based on keen-pbr reference
generate_default_config() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    local vpn_iface internet_iface
    vpn_iface=$(detect_vpn_iface)
    internet_iface=$(detect_internet_iface)

    log "Detected VPN interface: $vpn_iface"
    [ -n "$internet_iface" ] && log "Detected internet interface: $internet_iface"

    # Build direct interfaces array
    local direct_iface_toml="[]"
    if [ -n "$internet_iface" ]; then
        direct_iface_toml="[\"${internet_iface}\"]"
    fi

    cat > "$CONFIG_FILE" << CONFEOF
[general]
  # Directory for downloaded lists
  lists_output_dir = "${LISTS_DIR}"
  # Use Keenetic RCI API to check network connection availability on the interface
  use_keenetic_api = true
  # Use Keenetic DNS from System profile as upstream in generated dnsmasq config
  use_keenetic_dns = true
  # Fallback DNS server to use if Keenetic RCI call fails (e.g. 8.8.8.8 or 1.1.1.1)
  # Leave empty to disable fallback DNS
  fallback_dns = "8.8.8.8"

# ipset configuration.
# You can add multiple ipsets.
[[ipset]]
  # Name of the ipset.
  ipset_name = "vpn"
  # Add all hosts from the following lists to this ipset.
  lists = [
    "vpn-hosts"
  ]
  # IP version (4 or 6)
  ip_version = 4
  # Clear ipset each time before filling it
  flush_before_applying = true

  [ipset.routing]
    # Interface list to direct traffic for IPs in this ipset to.
    # keen-pbr will use first available interface.
    interfaces = ["${vpn_iface}"]
    # Drop all traffic to the hosts from this ipset if all interfaces are down (prevent traffic leaks).
    kill_switch = false
    # Fwmark to apply to packets matching the list criteria.
    fwmark = 1001
    # iptables routing table number
    table = 1001
    # iptables routing rule priority
    priority = 1001
    # Override DNS server for domains in this ipset. Format: <server>[#port] (e.g. 1.1.1.1#8153 or 8.8.8.8)
    # override_dns = "1.1.1.1"

[[ipset]]
  ipset_name = "direct"
  lists = [
    "direct-hosts"
  ]
  ip_version = 4
  flush_before_applying = true

  [ipset.routing]
    interfaces = ${direct_iface_toml}
    kill_switch = false
    fwmark = 1002
    table = 1002
    priority = 1002

# Lists with domains/IPs/CIDRs.
# You can add multiple lists and use them in ipsets by providing their name.
# You must set "name" and either "url", "file" or "hosts" field for each list.
[[list]]
  list_name = "vpn-hosts"
  hosts = [
    "ifconfig.co",
    "myip2.ru"
  ]

[[list]]
  list_name = "direct-hosts"
  hosts = []

# You can take lists from different sources.
# Take a look at https://github.com/v2fly/domain-list-community repository for lists for different services.
#[[list]]
#  list_name = "epic-games"
#  url = "https://raw.githubusercontent.com/v2fly/domain-list-community/refs/heads/master/data/epicgames"

#[[list]]
#  list_name = "discord-domains"
#  url = "https://raw.githubusercontent.com/GhostRooter0953/discord-voice-ips/refs/heads/master/main_domains/discord-main-domains-list"

#[[list]]
#  list_name = "re-filter-ipsum"
#  url = "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/refs/heads/main/ipsum.lst"

#[[list]]
#  list_name = "re-filter-community"
#  url = "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/refs/heads/main/community.lst"

#[[list]]
#  list_name = "re-filter-domains"
#  url = "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/refs/heads/main/domains_all.lst"
CONFEOF

    ok "Default config generated: $CONFIG_FILE"
    warn "Add hosts via web UI at http://ROUTER_IP:$PORT"
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
    printf "\n\033[1m  keen-pbr-web installer\033[0m\n\n"

    check_prereqs

    local arch
    arch=$(detect_arch)
    ok "Architecture: $arch"

    # Always stop, re-download, restart
    stop_existing
    download_binary "$arch"
    download_init_script

    # Config: migrate or generate only on first install
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -d "$BIRD_DIR" ]; then
            migrate_bird4static
        else
            generate_default_config
        fi
    else
        ok "Config exists: $CONFIG_FILE (keeping)"
    fi

    # Start
    log "Starting keen-pbr-web..."
    "$INIT_SCRIPT" start

    local router_ip
    router_ip=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' || echo "ROUTER_IP")

    printf "\n\033[1;32m  Done!\033[0m\n\n"
    printf "  Web UI: \033[1mhttp://%s:%s\033[0m\n" "$router_ip" "$PORT"
    printf "  Config: %s\n" "$CONFIG_FILE"
    printf "\n"
}

main "$@"
