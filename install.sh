#!/bin/sh
# keen-pbr-web installer for Keenetic routers running Entware
# Usage: curl -fsSL https://raw.githubusercontent.com/OWNER/keen-pbr-web/main/install.sh | sh
#
# What this script does:
#   1. Detects CPU architecture (mipsle / arm64)
#   2. Downloads keen-pbr-web binary from GitHub releases
#   3. Installs init script for Entware
#   4. Optionally migrates from Bird4Static
#   5. Starts the web interface on port 3000

set -e

REPO="Dronicho/keen-pbr-web"
INSTALL_DIR="/opt/sbin"
CONFIG_DIR="/opt/etc/keen-pbr"
CONFIG_FILE="$CONFIG_DIR/keen-pbr.conf"
LISTS_DIR="$CONFIG_DIR/lists.d"
INIT_SCRIPT="/opt/etc/init.d/S99keen-pbr-web"
PORT=3000

# Bird4Static paths
BIRD_CONF="/opt/etc/bird/bird.conf"
BIRD_DIR="/opt/etc/bird"

log() {
    printf "\033[1;33m▸\033[0m %s\n" "$1"
}

ok() {
    printf "\033[1;32m✓\033[0m %s\n" "$1"
}

err() {
    printf "\033[1;31m✗\033[0m %s\n" "$1" >&2
    exit 1
}

warn() {
    printf "\033[1;35m!\033[0m %s\n" "$1"
}

# ── Detect architecture ──────────────────────────────────────────────

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        mips|mipsel|mipsle)
            echo "mipsle"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            err "Unsupported architecture: $arch. Expected mipsle or arm64."
            ;;
    esac
}

# ── Check prerequisites ─────────────────────────────────────────────

check_prereqs() {
    if [ ! -d /opt/etc ]; then
        err "Entware not found (/opt/etc missing). Install Entware first."
    fi

    if ! command -v keen-pbr >/dev/null 2>&1; then
        err "keen-pbr not found. Install keen-pbr first: opkg install keen-pbr"
    fi

    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        err "Neither wget nor curl found. Install one: opkg install wget-ssl"
    fi
}

# ── Download binary ──────────────────────────────────────────────────

download() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    fi
}

download_binary() {
    local arch="$1"
    local suffix="linux-${arch}"

    log "Fetching latest release from GitHub..."

    local latest_url
    latest_url="https://api.github.com/repos/${REPO}/releases/latest"

    local download_url
    if command -v curl >/dev/null 2>&1; then
        download_url=$(curl -fsSL "$latest_url" | grep "browser_download_url.*${suffix}" | head -1 | cut -d'"' -f4)
    else
        download_url=$(wget -qO- "$latest_url" | grep "browser_download_url.*${suffix}" | head -1 | cut -d'"' -f4)
    fi

    if [ -z "$download_url" ]; then
        err "Could not find release for architecture: ${suffix}"
    fi

    log "Downloading $download_url ..."
    download "$download_url" "${INSTALL_DIR}/keen-pbr-web"
    chmod +x "${INSTALL_DIR}/keen-pbr-web"
    ok "Binary installed to ${INSTALL_DIR}/keen-pbr-web"
}

# ── Install init script ─────────────────────────────────────────────

install_init_script() {
    cat > "$INIT_SCRIPT" << 'INITEOF'
#!/bin/sh

ENABLED=yes
PROCS=keen-pbr-web
ARGS="-port 3000"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
INITEOF
    chmod +x "$INIT_SCRIPT"
    ok "Init script installed to $INIT_SCRIPT"
}

# ── Bird4Static migration ───────────────────────────────────────────

# Copy a bird4static user list file to keen-pbr lists dir.
# User lists are plain text: domains, IPs, CIDRs (one per line).
copy_user_list() {
    local src="$1" dest_name="$2"
    local dest="${LISTS_DIR}/${dest_name}.lst"

    # Strip comments and empty lines
    grep -v '^[[:space:]]*[#;]' "$src" | grep -v '^[[:space:]]*$' > "$dest" 2>/dev/null || true

    local count
    count=$(wc -l < "$dest" | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        ok "  Copied $count entries -> ${dest_name}.lst"
        return 0
    else
        rm -f "$dest"
        return 1
    fi
}

# Convert a bird4static generated list (route X/Y via ...) to plain CIDRs.
convert_bird_list() {
    local src="$1" dest_name="$2"
    local dest="${LISTS_DIR}/${dest_name}.lst"

    sed -n 's/^[[:space:]]*route[[:space:]][[:space:]]*\([0-9][0-9./]*\)[[:space:]].*/\1/p' "$src" > "$dest" 2>/dev/null || true

    local count
    count=$(wc -l < "$dest" | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        ok "  Converted $count routes -> ${dest_name}.lst"
        return 0
    else
        rm -f "$dest"
        return 1
    fi
}

# Parse bird.conf and migrate to keen-pbr config with two ipsets: vpn + direct
migrate_bird4static() {
    if [ ! -f "$BIRD_CONF" ]; then
        return 1
    fi

    log "Found Bird4Static config at $BIRD_CONF"
    log "Starting migration..."

    cp "$BIRD_CONF" "${BIRD_CONF}.bak"
    ok "Backed up bird.conf to ${BIRD_CONF}.bak"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    # ── Extract VPN interfaces from bird.conf ──
    local vpn_interfaces
    vpn_interfaces=$(sed -n 's/.*ifname[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null || true)

    if [ -z "$vpn_interfaces" ]; then
        vpn_interfaces=$(sed -n 's/.*interface[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null | head -5 || true)
    fi

    if [ -z "$vpn_interfaces" ]; then
        warn "Could not detect VPN interfaces from bird.conf"
        vpn_interfaces="nwg0"
    fi

    log "Detected VPN interfaces: $vpn_interfaces"

    # ── Collect VPN and direct (ISP) lists ──
    local vpn_lists=""
    local direct_lists=""

    # 1) user-vpn.list → VPN routing
    if [ -f "${BIRD_DIR}/user-vpn.list" ]; then
        log "Migrating user-vpn.list (VPN traffic)"
        if copy_user_list "${BIRD_DIR}/user-vpn.list" "user-vpn"; then
            vpn_lists="${vpn_lists} user-vpn"
        fi
    fi

    # 2) user-isp.list → direct (ISP) routing
    if [ -f "${BIRD_DIR}/user-isp.list" ]; then
        log "Migrating user-isp.list (direct/ISP traffic)"
        if copy_user_list "${BIRD_DIR}/user-isp.list" "user-direct"; then
            direct_lists="${direct_lists} user-direct"
        fi
    fi

    # 3) Any other user-*.list files
    for user_file in "${BIRD_DIR}"/user-*.list; do
        [ -f "$user_file" ] || continue
        local base
        base=$(basename "$user_file")
        case "$base" in
            user-vpn.list|user-isp.list) continue ;;  # already handled
        esac

        local list_name
        list_name=$(echo "$base" | sed 's/^user-//; s/\.list$//')

        log "Migrating $base"
        if copy_user_list "$user_file" "$list_name"; then
            # Treat unknown user lists as VPN by default
            vpn_lists="${vpn_lists} ${list_name}"
        fi
    done

    # 4) Generated bird4-*.list files (compiled routes)
    local list_files
    list_files=$(sed -n 's/.*include[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null || true)

    for list_file in $list_files; do
        local src_path
        case "$list_file" in
            /*) src_path="$list_file" ;;
            *)  src_path="${BIRD_DIR}/${list_file}" ;;
        esac

        [ -f "$src_path" ] || continue

        local list_name
        list_name=$(basename "$list_file" .list | sed 's/^bird4-//')

        log "Converting $list_file"

        if convert_bird_list "$src_path" "$list_name"; then
            # Classify: files with "force" or "isp" → direct, rest → VPN
            case "$list_name" in
                *force*|*isp*)
                    direct_lists="${direct_lists} ${list_name}" ;;
                *)
                    vpn_lists="${vpn_lists} ${list_name}" ;;
            esac
        fi
    done

    # ── Generate keen-pbr.conf with two ipsets ──
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        warn "Existing config backed up to ${CONFIG_FILE}.bak"
    fi

    # Build TOML interface array
    local iface_array=""
    for iface in $vpn_interfaces; do
        [ -n "$iface_array" ] && iface_array="${iface_array}, "
        iface_array="${iface_array}'${iface}'"
    done

    # Build TOML list arrays + [[list]] sections
    local vpn_lists_toml="" direct_lists_toml="" list_sections=""

    # Default empty lists so ipsets always have at least one
    if [ -z "$vpn_lists" ]; then
        vpn_lists="vpn-hosts"
        list_sections="${list_sections}
[[list]]
list_name = 'vpn-hosts'
hosts = [
  'example.com',
]
"
    fi

    for name in $vpn_lists; do
        [ -n "$vpn_lists_toml" ] && vpn_lists_toml="${vpn_lists_toml}, "
        vpn_lists_toml="${vpn_lists_toml}'${name}'"
        # Add [[list]] section if file exists (skip if already added as placeholder)
        if [ -f "${LISTS_DIR}/${name}.lst" ]; then
            list_sections="${list_sections}
[[list]]
list_name = '${name}'
file = '${LISTS_DIR}/${name}.lst'
"
        fi
    done

    if [ -n "$direct_lists" ]; then
        for name in $direct_lists; do
            [ -n "$direct_lists_toml" ] && direct_lists_toml="${direct_lists_toml}, "
            direct_lists_toml="${direct_lists_toml}'${name}'"
            if [ -f "${LISTS_DIR}/${name}.lst" ]; then
                list_sections="${list_sections}
[[list]]
list_name = '${name}'
file = '${LISTS_DIR}/${name}.lst'
"
            fi
        done
    fi

    # Write config
    cat > "$CONFIG_FILE" << CONFEOF
[general]
lists_output_dir = '${LISTS_DIR}'
use_keenetic_api = true
use_keenetic_dns = true
fallback_dns = '8.8.8.8'

# VPN routing: matched traffic goes through VPN interfaces
[[ipset]]
ipset_name = 'vpn'
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

    # Add direct ipset only if we have direct lists
    if [ -n "$direct_lists_toml" ]; then
        cat >> "$CONFIG_FILE" << CONFEOF

# Direct routing: matched traffic bypasses VPN, goes through ISP
[[ipset]]
ipset_name = 'direct'
lists = [${direct_lists_toml}]
ip_version = 4
flush_before_applying = true

[ipset.routing]
interfaces = []
kill_switch = false
fwmark = 1002
table = 1002
priority = 1002
CONFEOF
    fi

    # Append list sections
    printf "%s" "$list_sections" >> "$CONFIG_FILE"

    ok "Config generated at $CONFIG_FILE"
    log "  VPN lists: ${vpn_lists:-none}"
    [ -n "$direct_lists" ] && log "  Direct lists: $direct_lists"
}

# Generate a default config when no bird4static is present
generate_default_config() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    # Get available interfaces from keen-pbr
    local first_iface
    first_iface=$(keen-pbr interfaces 2>/dev/null | awk '{print $1}' | head -1 || echo "nwg0")

    cat > "$CONFIG_FILE" << CONFEOF
[general]
lists_output_dir = '${LISTS_DIR}'
use_keenetic_api = true
use_keenetic_dns = true
fallback_dns = '8.8.8.8'

# VPN routing: matched traffic goes through VPN
[[ipset]]
ipset_name = 'vpn'
lists = ['vpn-hosts']
ip_version = 4
flush_before_applying = true

[ipset.routing]
interfaces = ['${first_iface}']
kill_switch = false
fwmark = 1001
table = 1001
priority = 1001

# Direct routing: matched traffic bypasses VPN
[[ipset]]
ipset_name = 'direct'
lists = ['direct-hosts']
ip_version = 4
flush_before_applying = true

[ipset.routing]
interfaces = []
kill_switch = false
fwmark = 1002
table = 1002
priority = 1002

[[list]]
list_name = 'vpn-hosts'
hosts = [
  'example.com',
]

[[list]]
list_name = 'direct-hosts'
hosts = [
  'example.org',
]
CONFEOF

    ok "Default config generated at $CONFIG_FILE"
    warn "Edit lists via web UI at http://ROUTER_IP:$PORT"
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
    printf "\n\033[1m  keen-pbr-web installer\033[0m\n\n"

    check_prereqs

    local arch
    arch=$(detect_arch)
    ok "Architecture: $arch"

    # Download and install binary
    download_binary "$arch"

    # Install init script
    install_init_script

    # Config generation / migration
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -f "$BIRD_CONF" ]; then
            log "Bird4Static installation detected"
            migrate_bird4static
        else
            log "No existing config found, generating defaults..."
            generate_default_config
        fi
    else
        ok "Existing config found at $CONFIG_FILE (keeping)"
    fi

    # Start the service
    log "Starting keen-pbr-web..."
    "$INIT_SCRIPT" start

    local router_ip
    router_ip=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' || echo "ROUTER_IP")

    printf "\n\033[1;32m  Installation complete!\033[0m\n\n"
    printf "  Web UI: \033[1mhttp://%s:%s\033[0m\n" "$router_ip" "$PORT"
    printf "  Config: %s\n" "$CONFIG_FILE"
    printf "  Binary: %s/keen-pbr-web\n" "$INSTALL_DIR"
    printf "\n"

    if [ -f "${BIRD_CONF}.bak" ]; then
        printf "  \033[1;35mBird4Static migration complete.\033[0m\n"
        printf "  Original bird.conf backed up to %s.bak\n" "$BIRD_CONF"
        printf "  Review your config and run Download + Apply from the web UI.\n\n"
    fi
}

main "$@"
