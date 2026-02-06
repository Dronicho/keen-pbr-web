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

# Parse bird.conf and extract VPN interface names and list file includes
migrate_bird4static() {
    if [ ! -f "$BIRD_CONF" ]; then
        return 1
    fi

    log "Found Bird4Static config at $BIRD_CONF"
    log "Starting migration..."

    # Backup bird config
    cp "$BIRD_CONF" "${BIRD_CONF}.bak"
    ok "Backed up bird.conf to ${BIRD_CONF}.bak"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    # Parse interfaces and table mappings from bird.conf
    # We look for: ifname = "INTERFACE"; in filters and kernel table numbers
    local vpn_interfaces=""
    local table_numbers=""
    local list_files=""
    local vpn_count=0

    # Extract interface names from filter blocks (ifname = "nwg0";)
    vpn_interfaces=$(sed -n 's/.*ifname[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null || true)

    # If no ifname found, try protocol direct { interface "xxx"; }
    if [ -z "$vpn_interfaces" ]; then
        vpn_interfaces=$(sed -n 's/.*interface[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null | head -5 || true)
    fi

    # Extract kernel table numbers
    table_numbers=$(sed -n 's/.*kernel[[:space:]]*table[[:space:]]*\([0-9]*\).*/\1/p' "$BIRD_CONF" 2>/dev/null || true)

    # Extract included list files from protocol static sections
    list_files=$(sed -n 's/.*include[[:space:]]*"\([^"]*\)".*/\1/p' "$BIRD_CONF" 2>/dev/null || true)

    if [ -z "$vpn_interfaces" ]; then
        warn "Could not detect VPN interfaces from bird.conf"
        warn "You will need to configure interfaces manually in $CONFIG_FILE"
        vpn_interfaces="nwg0"  # default fallback
    fi

    log "Detected interfaces: $vpn_interfaces"
    [ -n "$table_numbers" ] && log "Detected kernel tables: $table_numbers"
    [ -n "$list_files" ] && log "Detected list files: $list_files"

    # Convert bird list files to keen-pbr format
    # Bird lists contain: route X.X.X.X/Y via "interface";
    # We need plain: X.X.X.X/Y
    local converted_lists=""

    for list_file in $list_files; do
        local src_path
        # Resolve relative paths against bird config directory
        case "$list_file" in
            /*) src_path="$list_file" ;;
            *)  src_path="${BIRD_DIR}/${list_file}" ;;
        esac

        if [ ! -f "$src_path" ]; then
            warn "List file not found: $src_path (skipping)"
            continue
        fi

        # Derive a clean list name from filename
        local list_name
        list_name=$(basename "$list_file" .list | sed 's/^bird4-//')

        local dest_path="${LISTS_DIR}/${list_name}.lst"

        log "Converting $list_file -> ${list_name}.lst"

        # Extract IPs/CIDRs from bird route format
        # Handles: route X.X.X.X/Y via "interface";
        #          route X.X.X.X/Y via 1.2.3.4;
        #          route X.X.X.X/Y reject;
        #          route X.X.X.X/Y blackhole;
        sed -n 's/^[[:space:]]*route[[:space:]][[:space:]]*\([0-9][0-9./]*\)[[:space:]].*/\1/p' "$src_path" > "$dest_path" 2>/dev/null || true

        local count
        count=$(wc -l < "$dest_path" | tr -d ' ')

        if [ "$count" -gt 0 ]; then
            ok "  Converted $count routes to ${list_name}.lst"
            converted_lists="${converted_lists} ${list_name}"
        else
            rm -f "$dest_path"
            warn "  No routes found in $list_file"
        fi
    done

    # Also look for user-*.list files (Bird4Static user lists with plain domains/IPs)
    for user_file in "${BIRD_DIR}"/user-*.list; do
        [ -f "$user_file" ] || continue

        local list_name
        list_name=$(basename "$user_file" .list | sed 's/^user-//')

        local dest_path="${LISTS_DIR}/${list_name}.lst"

        log "Copying user list: $(basename "$user_file") -> ${list_name}.lst"

        # User lists are already in plain format (domains, IPs, CIDRs)
        # Just copy, stripping comments and empty lines
        grep -v '^[[:space:]]*[#;]' "$user_file" | grep -v '^[[:space:]]*$' > "$dest_path" 2>/dev/null || true

        local count
        count=$(wc -l < "$dest_path" | tr -d ' ')

        if [ "$count" -gt 0 ]; then
            ok "  Copied $count entries to ${list_name}.lst"
            converted_lists="${converted_lists} ${list_name}"
        else
            rm -f "$dest_path"
        fi
    done

    # Generate keen-pbr.conf
    generate_config "$vpn_interfaces" "$table_numbers" "$converted_lists"
}

# Generate keen-pbr.conf from discovered data
generate_config() {
    local interfaces="$1"
    local tables="$2"
    local lists="$3"

    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        warn "Existing config backed up to ${CONFIG_FILE}.bak"
    fi

    # Build interface array for TOML
    local iface_array=""
    local first_iface=""
    for iface in $interfaces; do
        [ -z "$first_iface" ] && first_iface="$iface"
        [ -n "$iface_array" ] && iface_array="${iface_array}, "
        iface_array="${iface_array}'${iface}'"
    done

    # Build lists array for TOML
    local lists_array=""
    local list_sections=""
    for list_name in $lists; do
        [ -n "$lists_array" ] && lists_array="${lists_array}, "
        lists_array="${lists_array}'${list_name}'"

        list_sections="${list_sections}
[[list]]
list_name = '${list_name}'
file = '${LISTS_DIR}/${list_name}.lst'
"
    done

    # If no lists were converted, add a placeholder
    if [ -z "$lists_array" ]; then
        lists_array="'default'"
        list_sections="
[[list]]
list_name = 'default'
hosts = [
  'example.com',
]
"
    fi

    # Determine table/fwmark/priority
    # If migrating from bird4static, use 1001 series (keen-pbr convention)
    local fwmark=1001
    local table=1001
    local priority=1001

    cat > "$CONFIG_FILE" << CONFEOF
[general]
lists_output_dir = '${LISTS_DIR}'
use_keenetic_api = true
use_keenetic_dns = true
fallback_dns = '8.8.8.8'

[[ipset]]
ipset_name = 'vpn'
lists = [${lists_array}]
ip_version = 4
flush_before_applying = true

[ipset.routing]
interfaces = [${iface_array}]
kill_switch = false
fwmark = ${fwmark}
table = ${table}
priority = ${priority}
${list_sections}
CONFEOF

    ok "Config generated at $CONFIG_FILE"
}

# Generate a default config when no bird4static is present
generate_default_config() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LISTS_DIR"

    # Get available interfaces from keen-pbr
    local ifaces
    ifaces=$(keen-pbr interfaces 2>/dev/null | awk '{print $1}' | head -5 || echo "nwg0")

    local first_iface
    first_iface=$(echo "$ifaces" | head -1)

    cat > "$CONFIG_FILE" << CONFEOF
[general]
lists_output_dir = '${LISTS_DIR}'
use_keenetic_api = true
use_keenetic_dns = true
fallback_dns = '8.8.8.8'

[[ipset]]
ipset_name = 'vpn'
lists = ['default']
ip_version = 4
flush_before_applying = true

[ipset.routing]
interfaces = ['${first_iface}']
kill_switch = false
fwmark = 1001
table = 1001
priority = 1001

[[list]]
list_name = 'default'
hosts = [
  'example.com',
]
CONFEOF

    ok "Default config generated at $CONFIG_FILE"
    warn "Edit $CONFIG_FILE to configure your routing rules"
    warn "Then use the web UI at http://ROUTER_IP:$PORT"
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
